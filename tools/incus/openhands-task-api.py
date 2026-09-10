#!/usr/bin/env python3
"""Guest orchestrator in front of a self-hosted OpenHands Agent Server.

Hermes / the host bridge talk to this process. This process does *not* run an
agent loop. It creates OpenHands conversations, sends the task, consumes
REST + event-search updates, and maps them into a small UI-facing shape.

  POST /tasks                 start a conversation + send the prompt
  POST /tasks/{id}/messages   follow-up message (run=true)
  POST /tasks/{id}/cancel     pause the conversation
  POST /tasks/{id}/run        resume / run
  GET  /tasks/{id}            status + recent mapped events
  GET  /tasks/{id}/events     mapped event log
  GET  /tasks/{id}/stream     SSE of mapped events (Last-Event-ID reconnect)
  GET  /health
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

BIND_ADDR = os.environ.get("OPENHANDS_TASK_API_BIND", "0.0.0.0")
BIND_PORT = int(os.environ.get("OPENHANDS_TASK_API_PORT", "8090"))
AGENT_SERVER = os.environ.get("OPENHANDS_AGENT_SERVER_URL", "http://127.0.0.1:8000").rstrip("/")
SESSION_KEY = (
    os.environ.get("OH_SESSION_API_KEYS_0")
    or os.environ.get("OPENHANDS_SESSION_API_KEY")
    or os.environ.get("SESSION_API_KEY")
    or ""
)
WORKSPACE_DIR = os.environ.get("WORKSPACE_DIR", "/var/lib/ai-agent/workspace")
DEFAULT_MODEL = os.environ.get("LLM_MODEL") or os.environ.get("DEFAULT_MODEL") or "deepseek/deepseek-chat"
DEFAULT_BASE_URL = os.environ.get("LLM_BASE_URL", "https://api.deepseek.com")
MAX_ITERATIONS = int(os.environ.get("OPENHANDS_MAX_ITERATIONS", "100"))

JOBS: dict[str, dict[str, Any]] = {}
JOBS_LOCK = threading.Lock()
TERMINAL_STATUSES = {"finished", "ok", "failed", "error", "paused", "cancelled"}


def env_llm_key() -> str:
    return os.environ.get("LLM_API_KEY") or os.environ.get("DEEPSEEK_API_KEY") or ""


def json_bytes(payload: Any, code: int = 200) -> tuple[int, bytes]:
    return code, json.dumps(payload, default=str).encode("utf-8")


def oh_headers() -> dict[str, str]:
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if SESSION_KEY:
        headers["X-Session-API-Key"] = SESSION_KEY
        headers["Authorization"] = f"Bearer {SESSION_KEY}"
    return headers


def oh_request(method: str, path: str, payload: Any | None = None, timeout: int = 30) -> tuple[int, Any]:
    url = f"{AGENT_SERVER}{path}"
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=oh_headers(), method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8") or "{}"
            try:
                body: Any = json.loads(raw)
            except json.JSONDecodeError:
                body = {"raw": raw}
            return resp.status, body
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8") if exc.fp else ""
        try:
            parsed = json.loads(raw) if raw else {"error": exc.reason}
        except json.JSONDecodeError:
            parsed = {"error": raw or exc.reason}
        return exc.code, parsed
    except Exception as exc:
        return 502, {"error": str(exc), "upstream": url}


def prepare_workspace(repo: str, workdir: str) -> str:
    Path(WORKSPACE_DIR).mkdir(parents=True, exist_ok=True)
    if repo:
        name = Path(urllib.parse.urlparse(repo).path).name.removesuffix(".git") or "repo"
        dest = str(Path(WORKSPACE_DIR) / name)
        token = os.environ.get("GITHUB_TOKEN", "")
        clone_url = repo
        if token and repo.startswith("https://github.com/"):
            clone_url = repo.replace("https://github.com/", f"https://x-access-token:{token}@github.com/", 1)
        if Path(dest, ".git").is_dir():
            subprocess.run(["git", "-C", dest, "fetch", "--all"], check=False)
            subprocess.run(["git", "-C", dest, "pull", "--ff-only"], check=False)
        else:
            result = subprocess.run(["git", "clone", clone_url, dest], check=False, capture_output=True, text=True)
            if result.returncode != 0:
                raise RuntimeError(result.stderr.strip() or f"git clone failed: {repo}")
        return dest
    if workdir:
        path = Path(workdir)
        path.mkdir(parents=True, exist_ok=True)
        return str(path)
    Path(WORKSPACE_DIR).mkdir(parents=True, exist_ok=True)
    return WORKSPACE_DIR


def conversation_payload(prompt: str, model: str, working_dir: str) -> dict[str, Any]:
    llm: dict[str, Any] = {"model": model, "api_key": env_llm_key()}
    if DEFAULT_BASE_URL:
        llm["base_url"] = DEFAULT_BASE_URL
    return {
        "agent": {
            "kind": "Agent",
            "llm": llm,
            "tools": [
                {"name": "TerminalTool"},
                {"name": "FileEditorTool"},
                {"name": "TaskTrackerTool"},
            ],
            "system_prompt_kwargs": {"cli_mode": True},
        },
        "workspace": {"working_dir": working_dir},
        "initial_message": {"role": "user", "content": [{"type": "text", "text": prompt}]},
        "max_iterations": MAX_ITERATIONS,
        "stuck_detection": True,
        "confirmation_policy": {"kind": "NeverConfirm"},
    }


def extract_text(event: dict[str, Any]) -> str:
    for key in ("message", "summary", "thought", "error", "reason"):
        value = event.get(key)
        if isinstance(value, str) and value.strip():
            return value
    content = event.get("content")
    if isinstance(content, str) and content.strip():
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict) and item.get("text"):
                parts.append(str(item["text"]))
            elif isinstance(item, str):
                parts.append(item)
        if parts:
            return "\n".join(parts)
    llm_message = event.get("llm_message") or event.get("message_content") or {}
    if isinstance(llm_message, dict):
        nested = extract_text(llm_message)
        if nested:
            return nested
    args = event.get("args") or event.get("tool_call") or {}
    if isinstance(args, dict):
        for key in ("command", "path", "file_text", "content", "thought"):
            if args.get(key):
                return str(args[key])
    observation = event.get("observation") or event.get("result") or event.get("output")
    if isinstance(observation, str) and observation.strip():
        return observation[:4000]
    if isinstance(observation, dict):
        for key in ("content", "output", "stdout", "message"):
            if observation.get(key):
                return str(observation[key])[:4000]
    return ""


def normalize_kind(event: dict[str, Any]) -> str:
    kind = str(event.get("kind") or event.get("type") or event.get("action") or "event")
    lowered = kind.lower()
    if "message" in lowered:
        return "message"
    if "action" in lowered or kind in {"run", "edit", "write"}:
        return "action"
    if "observation" in lowered:
        return "observation"
    if "error" in lowered:
        return "error"
    if "state" in lowered or "execution_status" in lowered:
        return "state"
    if "pause" in lowered:
        return "pause"
    if "system" in lowered:
        return "system"
    return kind


def extract_status(event: dict[str, Any]) -> str | None:
    if event.get("key") in {"execution_status", "full_state"}:
        value = event.get("value")
        if isinstance(value, str):
            return value
        if isinstance(value, dict) and value.get("execution_status"):
            return str(value["execution_status"])
    if event.get("execution_status"):
        return str(event["execution_status"])
    return None


def map_event(event: dict[str, Any]) -> dict[str, Any]:
    args = event.get("args") if isinstance(event.get("args"), dict) else {}
    return {
        "id": event.get("id") or str(uuid.uuid4()),
        "kind": normalize_kind(event),
        "source": event.get("source") or "environment",
        "text": extract_text(event),
        "status": extract_status(event),
        "timestamp": event.get("timestamp"),
        "tool": event.get("tool_name") or args.get("name"),
        "raw_kind": event.get("kind") or event.get("type"),
    }


def map_status(oh_status: str | None, fallback: str) -> str:
    if not oh_status:
        return fallback
    value = oh_status.lower()
    mapping = {
        "idle": "idle",
        "running": "running",
        "paused": "paused",
        "waiting_for_confirmation": "waiting",
        "finished": "ok",
        "error": "failed",
        "stuck": "failed",
    }
    return mapping.get(value, value)


def upsert_job(job_id: str, **fields: Any) -> dict[str, Any]:
    with JOBS_LOCK:
        job = JOBS.setdefault(job_id, {"events": [], "seen_ids": set(), "seq": 0})
        job.update(fields)
        return dict(job)


def append_mapped(job_id: str, mapped: dict[str, Any]) -> dict[str, Any] | None:
    event_id = str(mapped.get("id") or "")
    with JOBS_LOCK:
        job = JOBS.setdefault(job_id, {"events": [], "seen_ids": set(), "seq": 0})
        seen: set[str] = job["seen_ids"]
        if event_id and event_id in seen:
            return None
        if event_id:
            seen.add(event_id)
        job["seq"] = int(job.get("seq") or 0) + 1
        mapped = dict(mapped)
        mapped["seq"] = job["seq"]
        job["events"].append(mapped)
        if mapped.get("status"):
            job["oh_status"] = mapped["status"]
            job["status"] = map_status(mapped["status"], job.get("status") or "running")
        if len(job["events"]) > 500:
            job["events"] = job["events"][-400:]
        return mapped


def conversation_status(conversation_id: str) -> tuple[int, Any]:
    return oh_request("GET", f"/api/conversations/{conversation_id}")


def search_events(conversation_id: str, limit: int = 100) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    page_id = None
    for _ in range(10):
        query = {"limit": str(limit), "sort_order": "TIMESTAMP"}
        if page_id:
            query["page_id"] = page_id
        encoded = urllib.parse.urlencode(query)
        code, body = oh_request("GET", f"/api/conversations/{conversation_id}/events/search?{encoded}")
        if code >= 400:
            break
        batch = body.get("items") if isinstance(body, dict) else body
        if not isinstance(batch, list):
            break
        items.extend(item for item in batch if isinstance(item, dict))
        page_id = body.get("next_page_id") if isinstance(body, dict) else None
        if not page_id or len(batch) < limit:
            break
    return items


def pump_events(job_id: str, conversation_id: str, stop: threading.Event) -> None:
    idle_rounds = 0
    while not stop.is_set():
        try:
            code, info = conversation_status(conversation_id)
            if code == 200 and isinstance(info, dict):
                oh_status = str(info.get("execution_status") or "")
                upsert_job(job_id, oh_status=oh_status, status=map_status(oh_status, "running"), conversation=info)
                idle_rounds = idle_rounds + 1 if oh_status.lower() in {"finished", "error", "paused"} else 0
            for event in search_events(conversation_id):
                append_mapped(job_id, map_event(event))
            if idle_rounds >= 2:
                break
        except Exception as exc:
            append_mapped(
                job_id,
                {
                    "id": f"orchestrator-{time.time_ns()}",
                    "kind": "error",
                    "source": "environment",
                    "text": f"event pump error: {exc}",
                    "status": None,
                    "timestamp": None,
                    "raw_kind": "orchestrator_error",
                },
            )
        stop.wait(1.0)
    code, info = conversation_status(conversation_id)
    if code == 200 and isinstance(info, dict):
        oh_status = str(info.get("execution_status") or "finished")
        upsert_job(job_id, oh_status=oh_status, status=map_status(oh_status, "ok"), conversation=info)


def start_conversation(repo: str, prompt: str, model: str | None, workdir: str = "") -> dict[str, Any]:
    job_id = str(uuid.uuid4())
    model = model or DEFAULT_MODEL
    upsert_job(job_id, status="queued", repo=repo, model=model, prompt=prompt, conversation_id=job_id, error=None)

    def worker() -> None:
        try:
            working_dir = prepare_workspace(repo, workdir)
            upsert_job(job_id, status="starting", working_dir=working_dir)
            payload = conversation_payload(prompt, model, working_dir)
            payload["conversation_id"] = job_id
            code, body = oh_request("POST", "/api/conversations", payload, timeout=60)
            if code >= 400:
                upsert_job(job_id, status="failed", error=body)
                return
            conversation_id = str(body.get("id") or job_id) if isinstance(body, dict) else job_id
            upsert_job(
                job_id,
                status="running",
                conversation_id=conversation_id,
                oh_status=str(body.get("execution_status") or "running") if isinstance(body, dict) else "running",
            )
            if conversation_id != job_id:
                with JOBS_LOCK:
                    JOBS[conversation_id] = JOBS[job_id]
            run_code, run_body = oh_request("POST", f"/api/conversations/{conversation_id}/run")
            if run_code >= 400 and run_code != 409:
                append_mapped(
                    job_id,
                    {
                        "id": f"run-{conversation_id}",
                        "kind": "error",
                        "source": "environment",
                        "text": f"POST /run failed: {run_body}",
                        "status": None,
                        "timestamp": None,
                        "raw_kind": "run_failed",
                    },
                )
            stop = threading.Event()
            with JOBS_LOCK:
                JOBS[job_id]["stop"] = stop
            pump_events(job_id, conversation_id, stop)
        except Exception as exc:
            upsert_job(job_id, status="failed", error=str(exc))

    threading.Thread(target=worker, name=f"oh-task-{job_id[:8]}", daemon=True).start()
    return {"job_id": job_id, "conversation_id": job_id, "status": "queued"}


def send_message(job_id: str, text: str, run: bool = True) -> tuple[int, Any]:
    job = get_job(job_id)
    if job is None:
        return 404, {"error": "not_found"}
    conversation_id = job.get("conversation_id") or job_id
    payload = {"role": "user", "content": [{"type": "text", "text": text}], "run": run}
    code, body = oh_request("POST", f"/api/conversations/{conversation_id}/events", payload)
    if code < 400:
        upsert_job(job_id, status="running")
        if run:
            oh_request("POST", f"/api/conversations/{conversation_id}/run")
        stop = threading.Event()
        upsert_job(job_id, stop=stop)
        threading.Thread(target=pump_events, args=(job_id, conversation_id, stop), daemon=True).start()
    return code, body


def cancel_job(job_id: str) -> tuple[int, Any]:
    job = get_job(job_id)
    if job is None:
        return 404, {"error": "not_found"}
    conversation_id = job.get("conversation_id") or job_id
    code, body = oh_request("POST", f"/api/conversations/{conversation_id}/pause")
    stop = job.get("stop")
    if isinstance(stop, threading.Event):
        stop.set()
    if code < 400:
        upsert_job(job_id, status="cancelled", oh_status="paused")
    return code, body


def resume_job(job_id: str) -> tuple[int, Any]:
    job = get_job(job_id)
    if job is None:
        return 404, {"error": "not_found"}
    conversation_id = job.get("conversation_id") or job_id
    code, body = oh_request("POST", f"/api/conversations/{conversation_id}/run")
    if code < 400:
        upsert_job(job_id, status="running")
        stop = threading.Event()
        upsert_job(job_id, stop=stop)
        threading.Thread(target=pump_events, args=(job_id, conversation_id, stop), daemon=True).start()
    return code, body


def get_job(job_id: str) -> dict[str, Any] | None:
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if job is not None:
            return job
    code, body = conversation_status(job_id)
    if code == 200 and isinstance(body, dict):
        hydrated = {
            "status": map_status(str(body.get("execution_status") or ""), "idle"),
            "oh_status": body.get("execution_status"),
            "conversation_id": body.get("id") or job_id,
            "conversation": body,
            "events": [],
            "seen_ids": set(),
            "seq": 0,
            "reconnected": True,
        }
        with JOBS_LOCK:
            JOBS[job_id] = hydrated
        for event in search_events(job_id):
            append_mapped(job_id, map_event(event))
        with JOBS_LOCK:
            return JOBS.get(job_id)
    return None


def public_job(job_id: str, job: dict[str, Any], include_events: bool = True) -> dict[str, Any]:
    events = [event for event in job.get("events", []) if isinstance(event, dict)] if include_events else []
    return {
        "job_id": job_id,
        "conversation_id": job.get("conversation_id") or job_id,
        "status": job.get("status"),
        "oh_status": job.get("oh_status"),
        "repo": job.get("repo"),
        "model": job.get("model"),
        "working_dir": job.get("working_dir"),
        "error": job.get("error"),
        "events": events[-100:],
    }


def health() -> dict[str, Any]:
    code, body = oh_request("GET", "/health", timeout=5)
    ready_code, ready_body = oh_request("GET", "/ready", timeout=5)
    return {
        "ok": code < 400,
        "service": "openhands-task-api",
        "agent_server": AGENT_SERVER,
        "agent_server_status": code,
        "agent_server_health": body,
        "agent_server_ready": ready_body if ready_code < 500 else {"status": ready_code},
        "role": "orchestrator",
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: Any) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _send(self, code: int, body: bytes, content_type: str = "application/json") -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode("utf-8") or "{}")

    def do_GET(self) -> None:
        path = (urlparse(self.path).path.rstrip("/") or "/")
        if path in ("/health", "/"):
            self._send(*json_bytes(health()))
            return
        if path.startswith("/tasks/"):
            parts = path.split("/")
            job_id = parts[2] if len(parts) > 2 else ""
            extra = parts[3] if len(parts) > 3 else ""
            job = get_job(job_id)
            if job is None:
                self._send(*json_bytes({"error": "not_found"}, 404))
                return
            if extra == "events":
                self._send(*json_bytes(public_job(job_id, job, include_events=True)))
                return
            if extra == "stream":
                self._stream(job_id, job)
                return
            self._send(*json_bytes(public_job(job_id, job)))
            return
        self._send(*json_bytes({"error": "not_found"}, 404))

    def _stream(self, job_id: str, job: dict[str, Any]) -> None:
        last_seq = 0
        last_event_id = self.headers.get("Last-Event-ID", "")
        query = parse_qs(urlparse(self.path).query)
        if last_event_id.isdigit():
            last_seq = int(last_event_id)
        elif query.get("after"):
            try:
                last_seq = int(query["after"][0])
            except ValueError:
                last_seq = 0
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        conversation_id = job.get("conversation_id") or job_id
        stop = job.get("stop")
        if not isinstance(stop, threading.Event):
            stop = threading.Event()
            upsert_job(job_id, stop=stop)
            threading.Thread(target=pump_events, args=(job_id, conversation_id, stop), daemon=True).start()
        try:
            while True:
                snapshot = get_job(job_id) or {}
                for event in snapshot.get("events", []):
                    seq = int(event.get("seq") or 0)
                    if seq <= last_seq:
                        continue
                    last_seq = seq
                    payload = json.dumps(event, default=str)
                    self.wfile.write(f"id: {seq}\nevent: oh_event\ndata: {payload}\n\n".encode("utf-8"))
                    self.wfile.flush()
                status = str(snapshot.get("status") or "")
                if status in TERMINAL_STATUSES and last_seq >= int(snapshot.get("seq") or 0):
                    done = json.dumps({"job_id": job_id, "status": status, "oh_status": snapshot.get("oh_status")})
                    self.wfile.write(f"event: done\ndata: {done}\n\n".encode("utf-8"))
                    self.wfile.flush()
                    break
                time.sleep(0.5)
        except BrokenPipeError:
            return

    def do_POST(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"
        try:
            payload = self._read_json()
        except json.JSONDecodeError:
            self._send(*json_bytes({"error": "invalid_json"}, 400))
            return
        if path in ("/tasks", "/api/conversations", "/trigger"):
            args = payload.get("arguments") or payload
            repo = str(args.get("repo") or args.get("repository") or "")
            prompt = str(args.get("prompt") or args.get("initial_user_msg") or args.get("task") or args.get("message") or "")
            model = args.get("model")
            model = str(model) if model else None
            workdir = str(args.get("workdir") or args.get("working_dir") or "")
            if not prompt:
                self._send(*json_bytes({"error": "prompt is required"}, 400))
                return
            self._send(*json_bytes(start_conversation(repo, prompt, model, workdir), 202))
            return
        if path.startswith("/tasks/"):
            parts = path.split("/")
            job_id = parts[2] if len(parts) > 2 else ""
            action = parts[3] if len(parts) > 3 else ""
            if action in {"messages", "message"}:
                text = str(payload.get("prompt") or payload.get("message") or payload.get("text") or "")
                if not text:
                    self._send(*json_bytes({"error": "message is required"}, 400))
                    return
                code, body = send_message(job_id, text, bool(payload.get("run", True)))
                self._send(*json_bytes(body if isinstance(body, dict) else {"result": body}, code))
                return
            if action in {"cancel", "pause"}:
                code, body = cancel_job(job_id)
                self._send(*json_bytes(body if isinstance(body, dict) else {"result": body}, code))
                return
            if action in {"run", "resume"}:
                code, body = resume_job(job_id)
                self._send(*json_bytes(body if isinstance(body, dict) else {"result": body}, code))
                return
        self._send(*json_bytes({"error": "not_found"}, 404))


def main() -> int:
    Path(WORKSPACE_DIR).mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((BIND_ADDR, BIND_PORT), Handler)
    print(f"openhands-task-api orchestrator {BIND_ADDR}:{BIND_PORT} -> {AGENT_SERVER}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

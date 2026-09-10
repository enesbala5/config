#!/usr/bin/env python3
"""Host-side HTTP bridge for Hermes -> byok-agent.

Binds only to the Incus bridge address. Fire-and-forget: returns a job_id
immediately and shells out to tools/incus/run-agent-task.sh in the background.

Auth: Authorization: Bearer $BRIDGE_TOKEN
"""

from __future__ import annotations

import json
import os
import secrets
import subprocess
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

BIND_ADDR = os.environ.get("BRIDGE_BIND_ADDR", "10.0.100.1")
BIND_PORT = int(os.environ.get("BRIDGE_PORT", "8420"))
BRIDGE_TOKEN = os.environ.get("BRIDGE_TOKEN", "")
RUN_SCRIPT = os.environ.get(
    "RUN_AGENT_TASK_SCRIPT",
    str(Path(__file__).resolve().parent.parent / "run-agent-task.sh"),
)

JOBS: dict[str, dict] = {}
JOBS_LOCK = threading.Lock()


def json_bytes(payload: dict, code: int = 200) -> tuple[int, bytes]:
    return code, json.dumps(payload).encode("utf-8")


def authorized(handler: BaseHTTPRequestHandler) -> bool:
    if not BRIDGE_TOKEN:
        return False
    header = handler.headers.get("Authorization", "")
    if header.startswith("Bearer "):
        got = header[len("Bearer ") :]
    else:
        got = handler.headers.get("X-Bridge-Token", "")
    return secrets.compare_digest(got, BRIDGE_TOKEN)


def start_job(repo: str, prompt: str, model: str | None) -> str:
    job_id = uuid.uuid4().hex[:12]
    with JOBS_LOCK:
        JOBS[job_id] = {"status": "queued", "repo": repo, "model": model}

    def worker() -> None:
        cmd = [RUN_SCRIPT, "--prompt", prompt]
        if repo:
            cmd.extend(["--repo", repo])
        if model:
            cmd.extend(["--model", model])
        with JOBS_LOCK:
            JOBS[job_id]["status"] = "running"
        try:
            result = subprocess.run(cmd, check=False)
            with JOBS_LOCK:
                JOBS[job_id]["status"] = "ok" if result.returncode == 0 else "failed"
                JOBS[job_id]["exit_code"] = result.returncode
        except Exception as exc:  # noqa: BLE001
            with JOBS_LOCK:
                JOBS[job_id]["status"] = "failed"
                JOBS[job_id]["error"] = str(exc)

    threading.Thread(target=worker, name=f"coding-task-{job_id}", daemon=True).start()
    return job_id


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: object) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _send(self, code: int, body: bytes, content_type: str = "application/json") -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path in ("/health", "/"):
            self._send(*json_bytes({"ok": True, "service": "coding-task-bridge"}))
            return
        if path.startswith("/jobs/"):
            if not authorized(self):
                self._send(*json_bytes({"error": "unauthorized"}, 401))
                return
            job_id = path.rsplit("/", 1)[-1]
            with JOBS_LOCK:
                job = JOBS.get(job_id)
            if job is None:
                self._send(*json_bytes({"error": "not_found"}, 404))
                return
            self._send(*json_bytes({"job_id": job_id, **job}))
            return
        self._send(*json_bytes({"error": "not_found"}, 404))

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if not authorized(self):
            self._send(*json_bytes({"error": "unauthorized"}, 401))
            return
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._send(*json_bytes({"error": "invalid_json"}, 400))
            return

        if path in ("/mcp", "/tools/trigger_coding_task", "/trigger"):
            args = payload.get("arguments") or payload.get("params", {}).get("arguments") or payload
            repo = str(args.get("repo") or "")
            prompt = str(args.get("prompt") or "")
            model = args.get("model")
            model = str(model) if model else None
            if not prompt:
                self._send(*json_bytes({"error": "prompt is required"}, 400))
                return
            job_id = start_job(repo, prompt, model)
            self._send(*json_bytes({"job_id": job_id, "status": "queued"}))
            return

        self._send(*json_bytes({"error": "not_found"}, 404))


def main() -> int:
    if not BRIDGE_TOKEN:
        print("Error: BRIDGE_TOKEN is required", file=sys.stderr)
        return 1
    if not Path(RUN_SCRIPT).is_file():
        print(f"Error: run-agent-task script not found: {RUN_SCRIPT}", file=sys.stderr)
        return 1
    server = ThreadingHTTPServer((BIND_ADDR, BIND_PORT), Handler)
    print(f"coding-task-bridge listening on {BIND_ADDR}:{BIND_PORT}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

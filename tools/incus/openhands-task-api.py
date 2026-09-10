#!/usr/bin/env python3
"""Guest REST front-door for OpenHands on byok-agent.

Hermes POSTs here over incusbr0 instead of going through Incus exec.

  POST /tasks   { \"prompt\": \"...\", \"repo\": \"...\", \"model\": \"...\" }
  GET  /health
  GET  /tasks/{id}
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

BIND_ADDR = os.environ.get("OPENHANDS_TASK_API_BIND", "0.0.0.0")
BIND_PORT = int(os.environ.get("OPENHANDS_TASK_API_PORT", "8090"))
RUNNER = os.environ.get("OPENHANDS_TASK_RUNNER", "/usr/local/bin/guest-run-agent-task.sh")

JOBS = {}
JOBS_LOCK = threading.Lock()


def json_bytes(payload, code=200):
    return code, json.dumps(payload).encode("utf-8")


def start_job(repo, prompt, model):
    job_id = uuid.uuid4().hex[:12]
    with JOBS_LOCK:
        JOBS[job_id] = {"status": "queued", "repo": repo, "model": model}

    def worker():
        cmd = [RUNNER, "--prompt", prompt]
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
        except Exception as exc:
            with JOBS_LOCK:
                JOBS[job_id]["status"] = "failed"
                JOBS[job_id]["error"] = str(exc)

    threading.Thread(target=worker, name=f"oh-task-{job_id}", daemon=True).start()
    return job_id


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _send(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path in ("/health", "/"):
            self._send(*json_bytes({"ok": True, "service": "openhands-task-api"}))
            return
        if path.startswith("/tasks/"):
            job_id = path.rsplit("/", 1)[-1]
            with JOBS_LOCK:
                job = JOBS.get(job_id)
            if job is None:
                self._send(*json_bytes({"error": "not_found"}, 404))
                return
            self._send(*json_bytes({"job_id": job_id, **job}))
            return
        self._send(*json_bytes({"error": "not_found"}, 404))

    def do_POST(self):
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._send(*json_bytes({"error": "invalid_json"}, 400))
            return
        if path in ("/tasks", "/api/conversations", "/trigger"):
            args = payload.get("arguments") or payload
            repo = str(args.get("repo") or args.get("repository") or "")
            prompt = str(args.get("prompt") or args.get("initial_user_msg") or args.get("task") or "")
            model = args.get("model")
            model = str(model) if model else None
            if not prompt:
                self._send(*json_bytes({"error": "prompt is required"}, 400))
                return
            job_id = start_job(repo, prompt, model)
            self._send(*json_bytes({"job_id": job_id, "status": "queued", "conversation_id": job_id}))
            return
        self._send(*json_bytes({"error": "not_found"}, 404))


def main():
    if not Path(RUNNER).is_file():
        print(f"Error: runner not found: {RUNNER}", file=sys.stderr)
        return 1
    server = ThreadingHTTPServer((BIND_ADDR, BIND_PORT), Handler)
    print(f"openhands-task-api listening on {BIND_ADDR}:{BIND_PORT}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

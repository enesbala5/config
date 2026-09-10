#!/usr/bin/env python3
"""Host REST + SSE proxy: Hermes UI -> OpenHands orchestrator on byok-agent.

Our application is the custom frontend/orchestrator. OpenHands Agent Server is
the agent runtime. This bridge is the host-side hop from Hermes onto the
guest orchestrator, which in turn talks to the Agent Server API.
"""

from __future__ import annotations

import json
import os
import secrets
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

BIND_ADDR = os.environ.get("BRIDGE_BIND_ADDR", "10.0.100.1")
BIND_PORT = int(os.environ.get("BRIDGE_PORT", "8420"))
BRIDGE_TOKEN = os.environ.get("BRIDGE_TOKEN", "")
OPENHANDS_URL = os.environ.get("OPENHANDS_URL", "http://byok-agent.incus:8090").rstrip("/")
SESSION_KEY = os.environ.get("OPENHANDS_SESSION_API_KEY", "")


def json_bytes(payload, code=200):
    return code, json.dumps(payload, default=str).encode("utf-8")


def authorized(handler):
    if not BRIDGE_TOKEN:
        return False
    header = handler.headers.get("Authorization", "")
    got = header[len("Bearer "):] if header.startswith("Bearer ") else handler.headers.get("X-Bridge-Token", "")
    return secrets.compare_digest(got, BRIDGE_TOKEN)


def upstream_headers(extra=None):
    headers = {"Accept": "*/*"}
    headers.update(extra or {})
    if SESSION_KEY:
        headers["X-Session-API-Key"] = SESSION_KEY
        headers.setdefault("Authorization", f"Bearer {SESSION_KEY}")
    return headers


def forward(method, path, payload=None, timeout=30):
    url = f"{OPENHANDS_URL}{path}"
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = upstream_headers({"Content-Type": "application/json"})
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8") or "{}"
            try:
                parsed = json.loads(body)
            except json.JSONDecodeError:
                parsed = {"raw": body}
            return resp.status, parsed
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8") if exc.fp else ""
        try:
            parsed = json.loads(raw) if raw else {"error": exc.reason}
        except json.JSONDecodeError:
            parsed = {"error": raw or exc.reason}
        return exc.code, parsed
    except Exception as exc:
        return 502, {"error": str(exc), "upstream": url}


def extract_task_args(payload):
    args = payload.get("arguments") or payload.get("params", {}).get("arguments") or payload
    repo = str(args.get("repo") or args.get("repository") or "")
    prompt = str(args.get("prompt") or args.get("initial_user_msg") or args.get("task") or args.get("message") or "")
    model = args.get("model")
    model = str(model) if model else None
    workdir = str(args.get("workdir") or args.get("working_dir") or "")
    return {"prompt": prompt, "repo": repo, "model": model, "workdir": workdir}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _send(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path in ("/health", "/"):
            up_code, up_body = forward("GET", "/health", timeout=5)
            self._send(*json_bytes({
                "ok": True,
                "role": "openhands-orchestrator-bridge",
                "upstream": up_body,
                "upstream_status": up_code,
            }))
            return
        if path.startswith("/jobs/") or path.startswith("/tasks/") or path.startswith("/conversations/"):
            if not authorized(self):
                self._send(*json_bytes({"error": "unauthorized"}, 401))
                return
            if path.endswith("/stream"):
                self._proxy_stream(path.replace("/jobs/", "/tasks/", 1).replace("/conversations/", "/tasks/", 1))
                return
            mapped = path
            if path.startswith("/jobs/"):
                mapped = "/tasks/" + path.split("/", 2)[-1]
            elif path.startswith("/conversations/"):
                mapped = "/tasks/" + path.split("/", 2)[-1]
            code, body = forward("GET", mapped)
            self._send(*json_bytes(body, code))
            return
        self._send(*json_bytes({"error": "not_found"}, 404))

    def _proxy_stream(self, path):
        url = f"{OPENHANDS_URL}{path}"
        headers = upstream_headers()
        if self.headers.get("Last-Event-ID"):
            headers["Last-Event-ID"] = self.headers.get("Last-Event-ID")
        req = urllib.request.Request(url, headers=headers, method="GET")
        try:
            resp = urllib.request.urlopen(req, timeout=600)
        except urllib.error.HTTPError as exc:
            raw = exc.read() if exc.fp else b""
            self._send(*json_bytes({"error": raw.decode("utf-8", "replace") or exc.reason}, exc.code))
            return
        except Exception as exc:
            self._send(*json_bytes({"error": str(exc), "upstream": url}, 502))
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        try:
            while True:
                chunk = resp.read(256)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
        except BrokenPipeError:
            return
        finally:
            resp.close()

    def do_POST(self):
        if not authorized(self):
            self._send(*json_bytes({"error": "unauthorized"}, 401))
            return
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._send(*json_bytes({"error": "invalid_json"}, 400))
            return
        if path in ("/mcp", "/tools/trigger_coding_task", "/trigger", "/tasks", "/conversations"):
            args = extract_task_args(payload)
            if not args["prompt"]:
                self._send(*json_bytes({"error": "prompt is required"}, 400))
                return
            code, body = forward("POST", "/tasks", args, timeout=60)
            self._send(*json_bytes(body, code))
            return
        if path.startswith("/tasks/") or path.startswith("/jobs/") or path.startswith("/conversations/"):
            mapped = path.replace("/jobs/", "/tasks/", 1).replace("/conversations/", "/tasks/", 1)
            code, body = forward("POST", mapped, payload, timeout=60)
            self._send(*json_bytes(body, code))
            return
        self._send(*json_bytes({"error": "not_found"}, 404))


def main():
    if not BRIDGE_TOKEN:
        print("Error: BRIDGE_TOKEN is required", file=sys.stderr)
        return 1
    server = ThreadingHTTPServer((BIND_ADDR, BIND_PORT), Handler)
    print(f"coding-task-bridge {BIND_ADDR}:{BIND_PORT} -> {OPENHANDS_URL}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

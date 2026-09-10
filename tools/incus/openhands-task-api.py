#!/usr/bin/env python3
"""Guest orchestrator in front of a self-hosted OpenHands Agent Server.

Hermes / the host bridge talk to this process. This process does *not* run an
agent loop. It creates OpenHands conversations, sends the task, consumes
REST + WebSocket/event-search updates, and maps them into a small UI-facing
shape.

  POST /tasks              start a conversation + send the prompt
  POST /tasks/{id}/messages follow-up message (run=true)
  POST /tasks/{id}/cancel   pause the conversation
  POST /tasks/{id}/run      resume / run
  GET  /tasks/{id}          status + recent mapped events
  GET  /tasks/{id}/events   mapped event log
  GET  /tasks/{id}/stream   SSE of mapped events (reconnect via Last-Event-ID)
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
SESSION_KEY = os.environ.get("OH_SESSION_API_KEYS_0") or os.environ.get("OPENHANDS_SESSION_API_KEY") or os.environ.get("SESSION_API_KEY") or ""
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
    llm: dict[str, Any] = {
        "model": model,
        "api_key": env_llm_key(),
    }
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
        "initial_message": {
            "role": "user",
            "content": [{"type": "text", "text": prompt}],
        },
        "max_iterations": MAX_ITERATIONS,
        "stuck_detection": True,
        "confirmation_policy": {"kind": "NeverConfirm"},
    }

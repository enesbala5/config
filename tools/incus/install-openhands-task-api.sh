#!/usr/bin/env bash
# Push the OpenHands REST task API onto a running byok-agent VM and start it.
set -euo pipefail

VM_NAME="${VM_NAME:-byok-agent}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/openhands-task-api.py"

if [[ ! -f "$SRC" ]]; then
  echo "Error: $SRC missing" >&2
  exit 1
fi

incus file push "$SRC" "${VM_NAME}/usr/local/bin/openhands-task-api.py" \
  -p --mode 0755 --uid 0 --gid 0

incus exec "$VM_NAME" -- bash -s <<'EOF'
cat >/etc/systemd/system/openhands-task-api.service <<'UNIT'
[Unit]
Description=OpenHands REST task API for Hermes
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=-/etc/agent-env
Environment=HOME=/root
Environment=PATH=/usr/local/bin:/root/.local/bin:/usr/bin
ExecStart=/usr/bin/python3 /usr/local/bin/openhands-task-api.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now openhands-task-api.service
systemctl --no-pager --full status openhands-task-api.service || true
EOF

echo "==> REST front-door on ${VM_NAME}:8090  (POST /tasks)"

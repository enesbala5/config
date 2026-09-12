#!/usr/bin/env bash
# Host lifecycle for the persistent Hermes Agent Incus VM (incus CLI).
set -euo pipefail

VM_NAME="${VM_NAME:-hermes-agent}"
PROFILE="${PROFILE:-hermes-agent}"
IMAGE="${IMAGE:-images:ubuntu/24.04/cloud}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/hermes-agent-secrets}"
USER_DATA_FILE="${USER_DATA_FILE:-/etc/incus-profiles/${PROFILE}/user-data}"
# Single source of truth for the OpenHands delegation skill; also embedded in
# the guest by the incus-hermes-agent module's cloud-init.
SKILL_FILE="${SKILL_FILE:-$(dirname "$0")/../hermes-skills/openhands/SKILL.md}"
PROFILE_CPU="${PROFILE_CPU:-2}"
PROFILE_MEMORY="${PROFILE_MEMORY:-4GiB}"
# Keep in sync with hosts/home-server/default.nix (guestIps) and the
# incus-hermes-agent module's network.nic.
NIC="${NIC:-eth0}"
STATIC_IP="${STATIC_IP:-10.0.100.174}"

usage() {
  cat >&2 <<'EOF'
Usage:
  hermes-vm-manage.sh start|stop|status|logs|push-secrets|launch
EOF
}

STATIC_IP_CHANGED=0

# Pin the guest IP. Sets STATIC_IP_CHANGED=1 when the address changed, so a
# running guest can be rebooted to pick up its new DHCP reservation.
ensure_static_ip() {
  STATIC_IP_CHANGED=0
  [[ -n "$STATIC_IP" ]] || return 0
  local current
  current="$(incus config device get "$VM_NAME" "$NIC" ipv4.address 2>/dev/null || true)"
  if [[ "$current" != "$STATIC_IP" ]]; then
    echo "==> Pinning ${VM_NAME} ${NIC} ipv4.address=${STATIC_IP}"
    # NIC is inherited from the default profile until overridden locally.
    if ! incus config device set "$VM_NAME" "$NIC" ipv4.address="$STATIC_IP" 2>/dev/null; then
      incus config device override "$VM_NAME" "$NIC" ipv4.address="$STATIC_IP"
    fi
    STATIC_IP_CHANGED=1
  fi
  # An already-running guest can keep its old dynamic lease until it reboots.
  if [[ "$(incus list "$VM_NAME" --format csv -c s 2>/dev/null || true)" == "RUNNING" ]]; then
    local runtime_ip
    runtime_ip="$(incus list "$VM_NAME" --format csv -c 4 2>/dev/null | cut -d' ' -f1 || true)"
    if [[ -n "$runtime_ip" && "$runtime_ip" != "$STATIC_IP" ]]; then
      STATIC_IP_CHANGED=1
    fi
  fi
}

ensure_profile() {
  if ! incus profile show "$PROFILE" >/dev/null 2>&1; then
    echo "==> Incus profile ${PROFILE} missing; creating it..."
    incus profile create "$PROFILE"
  fi

  incus profile set "$PROFILE" limits.cpu "$PROFILE_CPU"
  incus profile set "$PROFILE" limits.memory "$PROFILE_MEMORY"
  if [[ -f "$USER_DATA_FILE" ]]; then
    # Always refresh: an empty profile from an earlier partial setup would
    # otherwise leave new VMs with cloud-init user-data: {}.
    incus profile set "$PROFILE" cloud-init.user-data - < "$USER_DATA_FILE"
    incus profile set "$PROFILE" user.user-data - < "$USER_DATA_FILE"
  else
    echo "Warning: ${USER_DATA_FILE} not found; launched VM will not get cloud-init seeding until the host oneshot runs." >&2
  fi
}

wait_for_agent() {
  local i
  echo "==> Waiting for Incus agent on ${VM_NAME}..."
  for i in $(seq 1 90); do
    if incus exec "$VM_NAME" -- true >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Error: timed out waiting for Incus agent on ${VM_NAME}" >&2
  return 1
}

ensure_hermes_bin() {
  echo "==> Ensuring /usr/local/bin/hermes is executable..."
  incus exec "$VM_NAME" -- bash -lc '
    if [[ -x /usr/local/bin/hermes ]]; then
      exit 0
    fi
    if [[ -x /usr/local/lib/hermes-agent/venv/bin/hermes ]]; then
      ln -sfn /usr/local/lib/hermes-agent/venv/bin/hermes /usr/local/bin/hermes
    else
      echo "hermes binary not found under /usr/local/lib/hermes-agent/venv/bin" >&2
      exit 1
    fi
  '
}

# Keep in sync with nix/nixos/hosts/home-server/modules/incus-hermes-agent/default.nix
ensure_hermes_env() {
  echo "==> Installing guest env loader (source /etc/hermes-env)..."
  incus exec "$VM_NAME" -- tee /etc/profile.d/hermes-env.sh >/dev/null <<'EOF'
# Export /etc/hermes-env for Hermes CLI and login shells (incus exec bash -l).
if [ -f /etc/hermes-env ]; then
  set -a
  . /etc/hermes-env
  set +a
fi
EOF
  incus exec "$VM_NAME" -- chmod 0644 /etc/profile.d/hermes-env.sh
  incus exec "$VM_NAME" -- tee /etc/systemd/system/hermes-agent.service >/dev/null <<'EOF'
[Unit]
Description=Hermes Agent messaging gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=HOME=/root
WorkingDirectory=/root
ExecStart=/bin/bash -lc 'set -a && source /etc/hermes-env && set +a; export PATH=/usr/local/bin:/root/.local/bin:$PATH; exec hermes gateway'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  incus exec "$VM_NAME" -- tee /etc/systemd/system/hermes-dashboard.service >/dev/null <<'EOF'
[Unit]
Description=Hermes Agent web dashboard
After=network-online.target hermes-agent.service
Wants=network-online.target

[Service]
Type=simple
Environment=HOME=/root
Environment=HERMES_DASHBOARD_PUBLIC_URL=https://hermes.enesbala.com
WorkingDirectory=/root
ExecStart=/bin/bash -lc 'set -a && source /etc/hermes-env && set +a; export PATH=/usr/local/bin:/root/.local/bin:$PATH; exec hermes dashboard --host 0.0.0.0 --port 9119 --no-open'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  incus exec "$VM_NAME" -- tee /etc/systemd/system/hermes-serve.service >/dev/null <<'EOF'
[Unit]
Description=Hermes Agent backend server (Desktop/remote clients)
After=network-online.target hermes-agent.service hermes-dashboard.service
Wants=network-online.target

[Service]
Type=simple
Environment=HOME=/root
WorkingDirectory=/root
ExecStart=/bin/bash -lc 'set -a && source /etc/hermes-env && set +a; export PATH=/usr/local/bin:/root/.local/bin:$PATH; exec hermes serve --host 0.0.0.0 --port 8642'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  incus exec "$VM_NAME" -- systemctl daemon-reload
}

# Keep in sync with nix/nixos/hosts/home-server/modules/incus-hermes-agent/default.nix
# (tools/hermes-skills/openhands/SKILL.md is the single source of truth).
ensure_hermes_skill() {
  if [[ ! -f "$SKILL_FILE" ]]; then
    echo "Warning: skill file ${SKILL_FILE} not found; skipping OpenHands delegation skill." >&2
    return 0
  fi
  echo "==> Installing OpenHands delegation skill into guest..."
  incus exec "$VM_NAME" -- mkdir -p /root/.hermes/skills/openhands
  incus file push "$SKILL_FILE" "${VM_NAME}/root/.hermes/skills/openhands/SKILL.md" \
    -p --mode 0644 --uid 0 --gid 0
}

# Refresh the OpenHands REST client from the repo. It is also embedded in the
# profile's cloud-init, but that only runs on first boot, so a persistent VM
# would otherwise keep a stale copy after the script changes.
ensure_oh_start() {
  local src
  src="$(dirname "$0")/oh-start.sh"
  if [[ ! -f "$src" ]]; then
    echo "Warning: ${src} not found; keeping guest oh-start.sh." >&2
    return 0
  fi
  echo "==> Refreshing guest oh-start.sh..."
  incus file push "$src" "${VM_NAME}/usr/local/bin/oh-start.sh" \
    -p --mode 0755 --uid 0 --gid 0
}

push_secrets() {
  if [[ ! -e "$SECRETS_PATH" ]]; then
    echo "Error: secret file $SECRETS_PATH not found. Encrypt with manage-secret and apply agenix first." >&2
    exit 1
  fi
  echo "==> Pushing secrets to guest /etc/hermes-env (mode 0600)..."
  # agenix decrypts as root:0400; incus file push must not open the path as the caller.
  if [[ -r "$SECRETS_PATH" ]]; then
    incus file push "$SECRETS_PATH" "${VM_NAME}/etc/hermes-env" \
      -p --mode 0600 --uid 0 --gid 0
  else
    sudo cat "$SECRETS_PATH" | incus file push - "${VM_NAME}/etc/hermes-env" \
      -p --mode 0600 --uid 0 --gid 0
  fi
}

cmd_launch() {
  ensure_profile
  if incus info "$VM_NAME" >/dev/null 2>&1; then
    echo "==> ${VM_NAME} already exists"
    return 0
  fi
  # Create without starting so the pinned IP is reserved before the guest's
  # first DHCP request. `incus launch` would boot it with a dynamic lease.
  incus init "$IMAGE" "$VM_NAME" --profile default --profile "$PROFILE" --vm
  ensure_static_ip
  incus start "$VM_NAME"
}

cmd_start() {
  if ! incus info "$VM_NAME" >/dev/null 2>&1; then
    cmd_launch
  else
    ensure_static_ip
    status="$(incus list "$VM_NAME" --format csv -c s 2>/dev/null || true)"
    if [[ "$status" != "RUNNING" ]]; then
      incus start "$VM_NAME" || true
    elif [[ "$STATIC_IP_CHANGED" == "1" ]]; then
      # A running guest keeps its old lease until it reboots/renews.
      incus restart "$VM_NAME" || true
    fi
  fi
  wait_for_agent
  if ! incus exec "$VM_NAME" -- /usr/bin/cloud-init status --wait; then
    incus exec "$VM_NAME" -- /usr/bin/cloud-init status --long || true
    incus exec "$VM_NAME" -- tail -n 120 /var/log/cloud-init-output.log || true
    exit 1
  fi
  push_secrets
  if ! incus exec "$VM_NAME" -- test -f /etc/systemd/system/hermes-agent.service; then
    echo "Error: hermes-agent.service missing in guest. VM likely first-booted without profile user-data." >&2
    echo "Recreate: incus stop ${VM_NAME} && incus delete ${VM_NAME} && $0 start" >&2
    exit 1
  fi
  ensure_hermes_bin
  ensure_hermes_env
  ensure_oh_start
  ensure_hermes_skill
  incus exec "$VM_NAME" -- systemctl enable --now hermes-agent hermes-dashboard hermes-serve
  incus exec "$VM_NAME" -- systemctl restart hermes-agent hermes-dashboard hermes-serve
}

cmd_stop() {
  incus exec "$VM_NAME" -- systemctl stop hermes-agent hermes-dashboard hermes-serve || true
  incus stop "$VM_NAME" || true
}

ACTION="${1:-}"
case "$ACTION" in
  launch) cmd_launch ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) incus list "$VM_NAME"; incus exec "$VM_NAME" -- systemctl status hermes-agent hermes-dashboard hermes-serve --no-pager || true ;;
  logs) incus exec "$VM_NAME" -- journalctl -u hermes-agent -u hermes-dashboard -u hermes-serve -n 80 --no-pager ;;
  push-secrets) push_secrets ;;
  -h|--help|"") usage; exit 0 ;;
  *) echo "Unknown argument: $ACTION" >&2; usage; exit 1 ;;
esac

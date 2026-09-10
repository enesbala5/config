#!/usr/bin/env bash
# Install uv on the running byok-agent VM and put it on PATH.
# `openhands web` launches `uv run openhands` via /bin/sh, so uv must
# exist as /usr/local/bin/uv (login PATH is not used).
set -euo pipefail

VM_NAME="${VM_NAME:-byok-agent}"

if ! incus info "$VM_NAME" >/dev/null 2>&1; then
  echo "Error: VM ${VM_NAME} does not exist" >&2
  exit 1
fi

incus exec "$VM_NAME" -- bash -s <<'EOF'
set -euo pipefail
export PATH="/usr/local/bin:/root/.local/bin:${PATH}"

if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

UV_BIN=""
for candidate in /root/.local/bin/uv /root/.cargo/bin/uv /usr/local/bin/uv; do
  if [[ -x "$candidate" ]]; then
    UV_BIN="$candidate"
    break
  fi
done

if [[ -z "$UV_BIN" ]]; then
  echo "Error: uv installed but binary not found" >&2
  find /root -name uv -type f 2>/dev/null || true
  exit 1
fi

ln -sfn "$UV_BIN" /usr/local/bin/uv
if [[ -x "$(dirname "$UV_BIN")/uvx" ]]; then
  ln -sfn "$(dirname "$UV_BIN")/uvx" /usr/local/bin/uvx
fi

cat >/etc/profile.d/uv.sh <<'P'
export PATH="/usr/local/bin:/root/.local/bin:${PATH:-/usr/bin}"
P
chmod 644 /etc/profile.d/uv.sh

if grep -q '^PATH=' /etc/environment 2>/dev/null; then
  sed -i 's|^PATH="|PATH="/usr/local/bin:/root/.local/bin:|' /etc/environment
else
  echo 'PATH="/usr/local/bin:/root/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"' >> /etc/environment
fi

echo "==> uv at $(command -v uv || echo /usr/local/bin/uv)"
/usr/local/bin/uv --version
EOF

echo "==> Done. Retry: incus exec ${VM_NAME} -- openhands web --host 0.0.0.0 --port 12000"

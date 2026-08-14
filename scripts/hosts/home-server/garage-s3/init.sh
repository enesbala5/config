#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${GARAGE_S3_ENV_FILE:-/run/agenix/garage-s3-env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: missing S3 credentials file at $ENV_FILE"
  echo "Create nix/secrets/garage-s3-env.age and run nixos-rebuild switch first."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

: "${GARAGE_ACCESS_KEY_ID:?GARAGE_ACCESS_KEY_ID not set in $ENV_FILE}"
: "${GARAGE_SECRET_ACCESS_KEY:?GARAGE_SECRET_ACCESS_KEY not set in $ENV_FILE}"

echo "==> Fetching local Garage Node ID..."
NODE_ID=$(sudo garage status | grep -E '^[a-f0-9]{16}' | awk '{print $1}' | head -n 1)

if [ -z "$NODE_ID" ]; then
  echo "Error: Garage service is not running or node ID not found."
  exit 1
fi

echo "Found Node ID: $NODE_ID"

echo "==> Assigning capacity (1000G to 'local' zone)..."
sudo garage layout assign "$NODE_ID" --capacity 1000G --zone local

echo "==> Applying layout (if staged)..."
APPLY_VERSION=$(sudo garage layout show | sed -n 's/.*garage layout apply --version \([0-9][0-9]*\).*/\1/p' | head -n 1)

if [ -n "$APPLY_VERSION" ]; then
  sudo garage layout apply --version "$APPLY_VERSION"
else
  echo "No staged layout changes to apply."
fi

echo "==> Importing fixed S3 access key (main-app-key)..."

if sudo garage key info main-app-key >/dev/null 2>&1; then
  echo "Key main-app-key already exists; skipping import."

elif sudo garage key info "$GARAGE_ACCESS_KEY_ID" >/dev/null 2>&1; then
  echo "Key $GARAGE_ACCESS_KEY_ID already exists; skipping import."

else
  sudo garage key import --yes \
    "$GARAGE_ACCESS_KEY_ID" \
    "$GARAGE_SECRET_ACCESS_KEY" \
    -n main-app-key
fi

echo "==> Initialization complete."

echo "    S3 endpoint: http://127.0.0.1:3900"
echo "    Credentials: $ENV_FILE (same values your apps should use)"

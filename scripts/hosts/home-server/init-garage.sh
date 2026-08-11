#!/usr/bin/env bash
set -euo pipefail

echo "==> Fetching local Garage Node ID..."
NODE_ID=$(sudo garage status | grep -E '^[a-f0-9]{16}' | awk '{print $1}' | head -n 1)

if [ -z "$NODE_ID" ]; then
  echo "Error: Garage service is not running or node ID not found."
  exit 1
fi

echo "Found Node ID: $NODE_ID"

echo "==> Assigning capacity (4000G to 'local' zone)..."
sudo garage layout assign "$NODE_ID" --capacity 4000G --zone local

echo "==> Applying layout..."
sudo garage layout apply --version 1

echo "==> Creating default S3 access key..."
sudo garage key create main-app-key || true

echo "==> Initialization complete. Use 'sudo garage key info main-app-key' to retrieve S3 credentials."

#!/bin/sh
# Open herdr-bar on one filter. scope is agent (@) or pane (%).
# Herdr's open action always reads one config.json, so this writes a copy
# with the scope set and runs the installed binary in that directory.
set -eu

scope=${1:-}
case "$scope" in
  agent | pane) ;;
  *)
    echo "usage: open.sh agent|pane" >&2
    exit 2
    ;;
esac

home=${HOME:?}
registry="$home/.config/herdr/plugins.json"
config_src="$home/.config/herdr/plugins/config/herdr-bar/config.json"
state_dir="${XDG_STATE_HOME:-$home/.local/state}/herdr/plugins/herdr-bar"
scope_dir="$state_dir/scopes/$scope"

node - "$scope" "$registry" "$config_src" "$scope_dir" <<'EOF'
const fs = require("fs");
const path = require("path");

const [scope, registry, configSrc, scopeDir] = process.argv.slice(2);
const raw = JSON.parse(fs.readFileSync(registry, "utf8"));
const plugins = Array.isArray(raw) ? raw : raw.plugins || [];
const plugin = plugins.find((item) => item.plugin_id === "herdr-bar" && item.enabled);
if (!plugin || !plugin.plugin_root) {
  console.error("herdr-bar is not installed");
  process.exit(1);
}
const bin = path.join(plugin.plugin_root, "bin", "herdr-bar");
if (!fs.existsSync(bin)) {
  console.error("herdr-bar binary missing: " + bin);
  process.exit(1);
}
let config = {};
try {
  config = JSON.parse(fs.readFileSync(configSrc, "utf8"));
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
config.scope = scope;
fs.mkdirSync(scopeDir, { recursive: true });
fs.writeFileSync(path.join(scopeDir, "config.json"), JSON.stringify(config) + "\n");
fs.writeFileSync(path.join(scopeDir, "bin"), bin);
EOF

export HERDR_PLUGIN_CONFIG_DIR="$scope_dir"
export HERDR_PLUGIN_STATE_DIR="$state_dir"
exec "$(cat "$scope_dir/bin")"

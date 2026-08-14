#!/usr/bin/env bash
# EasyEffects must not be the default sink. It follows the hardware default and
# pulls streams onto its virtual device when these keys are on.

file="${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects/db/easyeffectsrc"
mkdir -p "$(dirname "$file")"
touch "$file"

set_ini_key() {
  local section=$1 key=$2 value=$3
  local tmp
  tmp=$(mktemp)
  awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN { insec = 0; done = 0 }
    /^\[/ {
      if (insec && !done) {
        print key "=" value
        done = 1
      }
      insec = ($0 == "[" section "]")
    }
    insec && index($0, key "=") == 1 {
      print key "=" value
      done = 1
      next
    }
    { print }
    END {
      if (!done) {
        if (!insec) {
          if (NR > 0) print ""
          print "[" section "]"
        }
        print key "=" value
      }
    }
  ' "$file" >"$tmp" && mv "$tmp" "$file"
}

set_ini_key "EffectsPipelines" "processAllOutputs" "true"
set_ini_key "StreamOutputs" "useDefaultOutputDevice" "true"

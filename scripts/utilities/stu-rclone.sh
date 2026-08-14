#!/usr/bin/env bash
set -euo pipefail

RCLONE_CONFIG="${RCLONE_CONFIG:-/run/agenix/rclone-conf}"

usage() {
  cat <<EOF
Usage: stu-rclone [REMOTE] [BUCKET] [stu flags...]

Launch stu with AWS credentials and endpoint taken from an rclone S3 remote.

REMOTE is an rclone section name (garage, r2, backblaze-b2, ...).
If omitted and fzf is available, pick from S3 remotes interactively.

R2 tokens typically cannot ListBuckets (403). Pass the bucket name.

Examples:
  stu-rclone
  stu-rclone garage
  stu-rclone r2 my-bucket
  stu-rclone r2 --bucket my-bucket
  stu-rclone backblaze-b2 --debug

Environment:
  RCLONE_CONFIG  rclone config path (default: /run/agenix/rclone-conf)
EOF
}

rclone_get() {
  local remote="$1" key="$2"
  awk -v section="$remote" -v want="$key" '
    BEGIN { want = tolower(want) }
    /^\[/ {
      current = $0
      gsub(/^\[|\]$/, "", current)
      next
    }
    current == section && $0 ~ /=/ {
      key = $0
      sub(/[ \t]*=.*/, "", key)
      gsub(/^[ \t]+|[ \t]+$/, "", key)
      if (tolower(key) == want) {
        val = substr($0, index($0, "=") + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", val)
        print val
        exit
      }
    }
  ' "$RCLONE_CONFIG"
}

list_s3_remotes() {
  awk '
    /^\[/ {
      if (name != "" && type == "s3") print name
      name = $0
      gsub(/^\[|\]$/, "", name)
      type = ""
      next
    }
    {
      line = $0
      sub(/[ \t]*=.*/, "", line)
      gsub(/^[ \t]+|[ \t]+$/, "", line)
      if (tolower(line) == "type") {
        type = substr($0, index($0, "=") + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", type)
      }
    }
    END { if (name != "" && type == "s3") print name }
  ' "$RCLONE_CONFIG"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -f "$RCLONE_CONFIG" ]]; then
  echo "Error: rclone config not found at $RCLONE_CONFIG" >&2
  exit 1
fi

REMOTE="${1:-}"
if [[ -n "$REMOTE" && "$REMOTE" != -* ]]; then
  shift
else
  REMOTE=""
fi

if [[ -z "$REMOTE" ]]; then
  mapfile -t remotes < <(list_s3_remotes)
  if [[ ${#remotes[@]} -eq 0 ]]; then
    echo "Error: no S3 remotes found in $RCLONE_CONFIG" >&2
    exit 1
  fi
  if [[ -t 0 ]] && command -v fzf >/dev/null 2>&1; then
    REMOTE="$(printf '%s\n' "${remotes[@]}" | fzf --prompt='rclone remote> ')"
  elif [[ ${#remotes[@]} -eq 1 ]]; then
    REMOTE="${remotes[0]}"
  else
    echo "S3 remotes:" >&2
    printf '  %s\n' "${remotes[@]}" >&2
    echo "Usage: stu-rclone <remote> [bucket] [stu flags...]" >&2
    exit 1
  fi
fi

if [[ -z "$REMOTE" ]]; then
  echo "Error: no remote selected" >&2
  exit 1
fi

TYPE="$(rclone_get "$REMOTE" type)"
if [[ -z "$TYPE" ]]; then
  echo "Error: rclone remote '$REMOTE' not found in $RCLONE_CONFIG" >&2
  exit 1
fi
if [[ "$TYPE" != "s3" ]]; then
  echo "Error: rclone remote '$REMOTE' is type '$TYPE', not s3" >&2
  exit 1
fi

ACCESS_KEY="$(rclone_get "$REMOTE" access_key_id)"
SECRET_KEY="$(rclone_get "$REMOTE" secret_access_key)"
ENDPOINT="$(rclone_get "$REMOTE" endpoint)"
REGION="$(rclone_get "$REMOTE" region)"
PROVIDER="$(rclone_get "$REMOTE" provider)"
FORCE_PATH_STYLE="$(rclone_get "$REMOTE" force_path_style)"

if [[ -z "$ACCESS_KEY" || -z "$SECRET_KEY" ]]; then
  echo "Error: remote '$REMOTE' is missing access_key_id or secret_access_key" >&2
  exit 1
fi

if [[ -n "$ENDPOINT" && "$ENDPOINT" != *"://"* ]]; then
  ENDPOINT="https://${ENDPOINT}"
fi

is_r2=false
if [[ "${PROVIDER,,}" == "cloudflare" || "${ENDPOINT,,}" == *"r2.cloudflarestorage.com"* ]]; then
  is_r2=true
fi

if [[ -z "$REGION" ]]; then
  if [[ "$is_r2" == true ]]; then
    REGION="auto"
  elif [[ "$ENDPOINT" =~ s3\.([a-z0-9-]+)\.backblazeb2\.com ]]; then
    REGION="${BASH_REMATCH[1]}"
  fi
fi

BUCKET=""
if [[ -n "${1:-}" && "$1" != -* ]]; then
  BUCKET="$1"
  shift
fi

has_bucket_flag=false
for arg in "$@"; do
  case "$arg" in
    -b|--bucket|--bucket=*) has_bucket_flag=true ;;
  esac
done

if [[ "$has_bucket_flag" == false && -z "$BUCKET" && "$is_r2" == true ]]; then
  if [[ -t 0 ]]; then
    echo "Remote '${REMOTE}' cannot list buckets. Provide the bucket name manually." >&2
    printf 'bucket> ' >&2
    read -r BUCKET
  fi
  if [[ -z "$BUCKET" ]]; then
    echo "Error: no bucket provided. Example: stu-rclone ${REMOTE} <bucket>" >&2
    exit 1
  fi
fi

if [[ -n "$BUCKET" && "$has_bucket_flag" == false ]]; then
  set -- --bucket "$BUCKET" "$@"
fi

export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
if [[ -n "$REGION" ]]; then
  export AWS_REGION="$REGION"
  export AWS_DEFAULT_REGION="$REGION"
fi

stu_args=()
if [[ -n "$ENDPOINT" ]]; then
  stu_args+=(--endpoint-url "$ENDPOINT")
fi
if [[ -n "$REGION" ]]; then
  stu_args+=(--region "$REGION")
fi
if [[ "${FORCE_PATH_STYLE,,}" == "false" ]]; then
  stu_args+=(--path-style never)
elif [[ "${FORCE_PATH_STYLE,,}" == "true" || "${PROVIDER,,}" != "aws" ]]; then
  stu_args+=(--path-style always)
fi

exec stu "${stu_args[@]}" "$@"

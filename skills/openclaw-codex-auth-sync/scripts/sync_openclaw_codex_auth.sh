#!/usr/bin/env bash
set -euo pipefail

codex_auth="${HOME}/.codex/auth.json"
openclaw_home="${HOME}/.openclaw"
target_model="openai-codex/gpt-5.3-codex"
restart_gateway=1
sync_sessions=0
dry_run=0

usage() {
  cat <<'EOF'
Usage:
  sync_openclaw_codex_auth.sh [options]

Options:
  --codex-auth PATH      Path to codex auth.json (default: ~/.codex/auth.json)
  --openclaw-home PATH   OpenClaw home directory (default: ~/.openclaw)
  --model MODEL          Target default model (default: openai-codex/gpt-5.3-codex)
  --no-restart           Do not restart OpenClaw gateway
  --sync-sessions        Also rewrite cached session model fields
  --dry-run              Show intended updates only
  -h, --help             Show this help
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex-auth)
      codex_auth="${2:?missing value for --codex-auth}"
      shift 2
      ;;
    --openclaw-home)
      openclaw_home="${2:?missing value for --openclaw-home}"
      shift 2
      ;;
    --model)
      target_model="${2:?missing value for --model}"
      shift 2
      ;;
    --no-restart)
      restart_gateway=0
      shift
      ;;
    --sync-sessions)
      sync_sessions=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd jq
require_cmd python3

if [[ ! -f "$codex_auth" ]]; then
  echo "error: codex auth file not found: $codex_auth" >&2
  exit 1
fi

id_token="$(jq -er '.tokens.id_token' "$codex_auth")"
access_token="$(jq -er '.tokens.access_token' "$codex_auth")"
refresh_token="$(jq -er '.tokens.refresh_token' "$codex_auth")"
account_id="$(jq -er '.tokens.account_id' "$codex_auth")"

if [[ -z "$id_token" || -z "$access_token" || -z "$refresh_token" || -z "$account_id" ]]; then
  echo "error: missing token fields in $codex_auth" >&2
  exit 1
fi

claims_json="$(
  python3 - "$id_token" <<'PY'
import base64
import json
import sys

token = sys.argv[1]
parts = token.split(".")
if len(parts) < 2:
    raise SystemExit("id_token is not a JWT")

payload = parts[1] + "=" * (-len(parts[1]) % 4)
claims = json.loads(base64.urlsafe_b64decode(payload.encode()).decode())
print(json.dumps({"email": claims.get("email", ""), "exp": claims.get("exp")}))
PY
)"

email="$(printf '%s' "$claims_json" | jq -er '.email')"
exp_s="$(printf '%s' "$claims_json" | jq -er '.exp')"

if [[ -z "$email" ]]; then
  echo "error: token payload does not include email" >&2
  exit 1
fi

if ! [[ "$exp_s" =~ ^[0-9]+$ ]]; then
  echo "error: token payload exp is invalid: $exp_s" >&2
  exit 1
fi

expires_ms=$((exp_s * 1000))

echo "codex_auth=$codex_auth"
echo "openclaw_home=$openclaw_home"
echo "target_model=$target_model"
echo "oauth_email=$email"

profile_count=0
shopt -s nullglob
for profile_file in "$openclaw_home"/agents/*/agent/auth-profiles.json; do
  profile_count=$((profile_count + 1))
  if (( dry_run )); then
    echo "[dry-run] update profile: $profile_file"
    continue
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/openclaw-auth.XXXXXX")"
  jq \
    --arg access "$access_token" \
    --arg refresh "$refresh_token" \
    --arg account "$account_id" \
    --arg email "$email" \
    --argjson expires "$expires_ms" \
    '
      .profiles = (.profiles // {})
      | .profiles["openai-codex:default"] = (
          (.profiles["openai-codex:default"] // {})
          + {
              provider: "openai-codex",
              type: "oauth",
              access: $access,
              refresh: $refresh,
              accountId: $account,
              email: $email,
              expires: $expires
            }
        )
    ' "$profile_file" > "$tmp_file"
  mv "$tmp_file" "$profile_file"
done
shopt -u nullglob

if (( profile_count == 0 )); then
  echo "error: no auth-profiles.json found under $openclaw_home/agents/*/agent/" >&2
  exit 1
fi

openclaw_cfg="$openclaw_home/openclaw.json"
if [[ -f "$openclaw_cfg" ]]; then
  if (( dry_run )); then
    echo "[dry-run] update config: $openclaw_cfg"
  else
    tmp_file="$(mktemp "${TMPDIR:-/tmp}/openclaw-config.XXXXXX")"
    jq \
      --arg model "$target_model" \
      '
        .auth = (.auth // {})
        | .auth.profiles = (.auth.profiles // {})
        | .auth.profiles["openai-codex:default"] = (
            (.auth.profiles["openai-codex:default"] // {})
            + {provider: "openai-codex", mode: "oauth"}
          )
        | .models = (.models // {})
        | .models.default = $model
        | if (.agents.list? and (.agents.list | type == "array")) then
            .agents.list = (.agents.list | map((. // {}) + {model: $model}))
          else
            .
          end
      ' "$openclaw_cfg" > "$tmp_file"
    mv "$tmp_file" "$openclaw_cfg"
  fi
else
  echo "warning: config file not found, skipped model/auth mapping update: $openclaw_cfg" >&2
fi

if (( sync_sessions )); then
  shopt -s nullglob
  for sessions_file in "$openclaw_home"/agents/*/sessions/sessions.json; do
    if (( dry_run )); then
      echo "[dry-run] update sessions: $sessions_file"
      continue
    fi

    tmp_file="$(mktemp "${TMPDIR:-/tmp}/openclaw-sessions.XXXXXX")"
    jq \
      --arg model "$target_model" \
      '
        if (type == "array") then
          map(if (type == "object" and has("model")) then .model = ($model | split("/") | last) else . end)
        elif (type == "object" and (.sessions? | type == "array")) then
          .sessions |= map(if (type == "object" and has("model")) then .model = ($model | split("/") | last) else . end)
        else
          .
        end
      ' "$sessions_file" > "$tmp_file"
    mv "$tmp_file" "$sessions_file"
  done
  shopt -u nullglob
fi

if (( restart_gateway )); then
  if command -v openclaw >/dev/null 2>&1; then
    if (( dry_run )); then
      echo "[dry-run] restart gateway: openclaw gateway restart"
    else
      openclaw gateway restart
    fi
  else
    echo "warning: openclaw command not found, skipped gateway restart" >&2
  fi
fi

if command -v openclaw >/dev/null 2>&1; then
  if (( dry_run )); then
    echo "[dry-run] verify with: openclaw models status --json"
  else
    openclaw models status --json | jq '
      {
        defaultModel,
        resolvedDefault,
        openaiCodexOAuth: (
          (.auth.oauth.profiles // [])
          | map(select(.profileId == "openai-codex:default"))
          | .[0]
        )
      }
    '
  fi
fi

echo "done: OpenClaw auth/model sync completed."

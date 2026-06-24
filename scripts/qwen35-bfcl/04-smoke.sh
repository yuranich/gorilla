#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

preset="${1:-08b:think}"
load_preset "${preset}"

wait_seconds="${QVAC_WAIT_SECONDS:-600}"
deadline=$((SECONDS + wait_seconds))

printf 'Waiting for %s at %s\n' "${MODEL_ALIAS}" "${QVAC_BASE_URL}"
until curl -fsS "${QVAC_BASE_URL}/models/${MODEL_ALIAS}" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    die "timed out waiting for ${MODEL_ALIAS}"
  fi
  sleep 2
done

chat_payload="$(mktemp)"
tool_payload="$(mktemp)"
trap 'rm -f "${chat_payload}" "${tool_payload}"' EXIT

cat >"${chat_payload}" <<EOF
{
  "model": "${MODEL_ALIAS}",
  "messages": [{"role": "user", "content": "Reply with exactly: qvac-smoke-ok"}]
}
EOF

printf '\nChat smoke:\n'
curl -fsS "${QVAC_BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  --data-binary "@${chat_payload}" | jq -r '.choices[0].message.content // .'

cat >"${tool_payload}" <<EOF
{
  "model": "${MODEL_ALIAS}",
  "messages": [{"role": "user", "content": "What is the weather in Tokyo? Use the tool."}],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get current weather for a city",
        "parameters": {
          "type": "object",
          "properties": {
            "city": {"type": "string"}
          },
          "required": ["city"]
        }
      }
    }
  ]
}
EOF

printf '\nTool-call smoke:\n'
curl -fsS "${QVAC_BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  --data-binary "@${tool_payload}" | jq '.choices[0].message'

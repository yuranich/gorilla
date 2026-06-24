#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

preset="${1:-08b:think}"
load_preset "${preset}"
ensure_dirs

if ! command -v qvac >/dev/null 2>&1; then
  die "qvac command not found. Run 01-install-user-deps.sh first."
fi

"${SCRIPT_DIR}/02-register-bfcl-models.sh" "${PRESET}" >/dev/null

if curl -fsS "${QVAC_BASE_URL}/models" >/dev/null 2>&1; then
  if curl -fsS "${QVAC_BASE_URL}/models/${MODEL_ALIAS}" >/dev/null 2>&1; then
    printf 'QVAC is already serving %s at %s\n' "${MODEL_ALIAS}" "${QVAC_BASE_URL}"
    exit 0
  fi
  printf 'A QVAC/OpenAI server is already responding at %s.\n' "${QVAC_BASE_URL}" >&2
  printf 'Stop it before serving preset %s, or change QVAC_PORT.\n' "${PRESET}" >&2
  exit 1
fi

print_preset
printf 'Starting QVAC OpenAI server at %s\n' "${QVAC_BASE_URL}"
printf 'Config: %s\n' "${QVAC_CONFIG_PATH}"
printf 'The first run may download %s.\n' "${HF_REPO}"

exec qvac serve openai \
  --config "${QVAC_CONFIG_PATH}" \
  --host "${QVAC_HOST}" \
  --port "${QVAC_PORT}" \
  --model "${MODEL_ALIAS}" \
  --verbose

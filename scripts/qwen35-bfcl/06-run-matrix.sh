#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

categories="${1:-${BFCL_TEST_CATEGORIES}}"
shift || true

if (( $# > 0 )); then
  presets=("$@")
else
  presets=("${ALL_PRESETS[@]}")
fi

if ! command -v qvac >/dev/null 2>&1; then
  die "qvac command not found. Run 01-install-user-deps.sh first."
fi

current_pid=""
cleanup() {
  if [[ -n "${current_pid}" ]] && kill -0 "${current_pid}" >/dev/null 2>&1; then
    kill "${current_pid}" >/dev/null 2>&1 || true
    wait "${current_pid}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

wait_for_model() {
  local alias="$1"
  local deadline=$((SECONDS + ${QVAC_WAIT_SECONDS:-900}))
  until curl -fsS "${QVAC_BASE_URL}/models/${alias}" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      die "timed out waiting for ${alias}; see ${QVAC_SERVER_LOG}"
    fi
    sleep 3
  done
}

for preset in "${presets[@]}"; do
  load_preset "${preset}"
  ensure_dirs
  "${SCRIPT_DIR}/02-register-bfcl-models.sh" "${PRESET}" >/dev/null

  printf '\n=== %s ===\n' "${PRESET}"
  print_preset
  printf 'log=%s\n' "${QVAC_SERVER_LOG}"

  qvac serve openai \
    --config "${QVAC_CONFIG_PATH}" \
    --host "${QVAC_HOST}" \
    --port "${QVAC_PORT}" \
    --model "${MODEL_ALIAS}" \
    --verbose >"${QVAC_SERVER_LOG}" 2>&1 &
  current_pid="$!"

  wait_for_model "${MODEL_ALIAS}"
  "${SCRIPT_DIR}/04-smoke.sh" "${PRESET}"
  "${SCRIPT_DIR}/05-run-benchmark.sh" "${PRESET}" "${categories}"

  cleanup
  current_pid=""
  sleep 2
done

"${SCRIPT_DIR}/07-summarize.sh"

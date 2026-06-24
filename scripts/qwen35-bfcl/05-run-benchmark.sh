#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

preset="${1:-08b:think}"
categories="${2:-${BFCL_TEST_CATEGORIES}}"
load_preset "${preset}"
activate_bfcl_venv

if ! curl -fsS "${QVAC_BASE_URL}/models/${MODEL_ALIAS}" >/dev/null 2>&1; then
  die "${MODEL_ALIAS} is not loaded at ${QVAC_BASE_URL}. Run 03-serve-model.sh ${PRESET} first."
fi

runner_args=(
  "${SCRIPT_DIR}/lib/bfcl_qvac_runner.py"
  "generate-evaluate"
  "--model-alias" "${MODEL_ALIAS}"
  "--display-name" "${MODEL_ALIAS}"
  "--categories" "${categories}"
  "--num-threads" "${BFCL_NUM_THREADS}"
  "--base-url" "${QVAC_BASE_URL}"
  "--api-key" "${OPENAI_API_KEY:-EMPTY}"
  "--result-dir" "${BFCL_RESULT_DIR}"
  "--score-dir" "${BFCL_SCORE_DIR}"
)

if [[ "${BFCL_ALLOW_OVERWRITE}" == "1" ]]; then
  runner_args+=("--allow-overwrite")
fi
if [[ "${BFCL_PARTIAL_EVAL}" == "1" ]]; then
  runner_args+=("--partial-eval")
fi
if [[ "${BFCL_INCLUDE_INPUT_LOG}" == "1" ]]; then
  runner_args+=("--include-input-log")
fi
if [[ "${BFCL_EXCLUDE_STATE_LOG}" == "1" ]]; then
  runner_args+=("--exclude-state-log")
fi
if [[ "${BFCL_RUN_IDS}" == "1" ]]; then
  runner_args+=("--run-ids")
fi

print_preset
printf 'categories=%s\n' "${categories}"
printf 'result_dir=%s\n' "${BFCL_RESULT_DIR}"
printf 'score_dir=%s\n' "${BFCL_SCORE_DIR}"
python "${runner_args[@]}"

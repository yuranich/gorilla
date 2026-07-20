#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BFCL_DIR="${BFCL_DIR:-${REPO_ROOT}/berkeley-function-call-leaderboard}"
VENV_DIR="${VENV_DIR:-${BFCL_DIR}/.venv-qvac-bfcl}"
RUN_DIR="${RUN_DIR:-${SCRIPT_DIR}/.run}"
CONFIG_DIR="${CONFIG_DIR:-${RUN_DIR}/configs}"
LOG_DIR="${LOG_DIR:-${RUN_DIR}/logs}"

if [[ -n "${HOME:-}" && -d "${HOME}/.local/bin" ]]; then
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
fi

QVAC_HOST="${QVAC_HOST:-127.0.0.1}"
QVAC_PORT="${QVAC_PORT:-11434}"
QVAC_BASE_URL="${QVAC_BASE_URL:-http://${QVAC_HOST}:${QVAC_PORT}/v1}"
QVAC_CONTEXT_SIZE="${QVAC_CONTEXT_SIZE:-32768}"
QVAC_PRELOAD="${QVAC_PRELOAD:-true}"
QVAC_MODEL_FIELD="${QVAC_MODEL_FIELD:-src}"

BFCL_RESULT_DIR="${BFCL_RESULT_DIR:-result/qvac-qwen35}"
BFCL_SCORE_DIR="${BFCL_SCORE_DIR:-score/qvac-qwen35}"
BFCL_TEST_CATEGORIES="${BFCL_TEST_CATEGORIES:-all_scoring}"
BFCL_NUM_THREADS="${BFCL_NUM_THREADS:-1}"
BFCL_ALLOW_OVERWRITE="${BFCL_ALLOW_OVERWRITE:-0}"
BFCL_PARTIAL_EVAL="${BFCL_PARTIAL_EVAL:-0}"
BFCL_INCLUDE_INPUT_LOG="${BFCL_INCLUDE_INPUT_LOG:-0}"
BFCL_EXCLUDE_STATE_LOG="${BFCL_EXCLUDE_STATE_LOG:-0}"
BFCL_RUN_IDS="${BFCL_RUN_IDS:-0}"

ALL_PRESETS=(
  "08b:think"
  "08b:think-vl-webdev"
  "08b:nothink"
  "08b:nothink-vl"
  "08b:qvac-current"
  "2b:think"
  "2b:think-vl-webdev"
  "2b:nothink"
  "2b:nothink-vl"
  "2b:qvac-current"
  "4b:think"
  "4b:nothink"
  "4b:qvac-current"
)

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

safe_preset_name() {
  printf '%s' "$1" | tr ':/' '--'
}

ensure_dirs() {
  mkdir -p "${RUN_DIR}" "${CONFIG_DIR}" "${LOG_DIR}"
}

describe_os() {
  local kernel
  local label
  kernel="$(uname -s)"

  case "${kernel}" in
    Darwin)
      if command -v sw_vers >/dev/null 2>&1; then
        label="macOS $(sw_vers -productVersion)"
      else
        label="Darwin $(uname -r)"
      fi
      ;;
    Linux)
      label="Linux"
      if [[ -r /etc/os-release ]]; then
        label="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-Linux}")"
      fi
      ;;
    *)
      label="${kernel} $(uname -r)"
      ;;
  esac

  printf '%s %s\n' "${label}" "$(uname -m)"
}

choose_python() {
  if [[ -n "${PYTHON_BIN:-}" ]]; then
    printf '%s\n' "${PYTHON_BIN}"
    return
  fi

  for candidate in python3.12 python3.11 python3.10 python3; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return
    fi
  done

  die "Python 3.10+ is required"
}

activate_bfcl_venv() {
  if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
    die "BFCL virtualenv not found at ${VENV_DIR}. Run 01-install-user-deps.sh first."
  fi
  # shellcheck source=/dev/null
  source "${VENV_DIR}/bin/activate"
}

load_preset() {
  local preset="${1:-}"
  [[ -n "${preset}" ]] || die "missing preset"

  REPEAT_PENALTY=""
  FREQUENCY_PENALTY=""
  REASONING_BUDGET=""
  MODEL_CONSTANT=""

  case "${preset}" in
    08b:think|08b:think-text)
      HF_REPO="unsloth/Qwen3.5-0.8B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_0_8B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-08b-q4km-think-text"
      TEMPERATURE="1.0"
      TOP_P="0.95"
      TOP_K="20"
      PRESENCE_PENALTY="1.5"
      ENABLE_THINKING="true"
      ;;
    08b:think-vl-webdev)
      HF_REPO="unsloth/Qwen3.5-0.8B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_0_8B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-08b-q4km-think-vl-webdev"
      TEMPERATURE="0.6"
      TOP_P="0.95"
      TOP_K="20"
      PRESENCE_PENALTY="0.0"
      ENABLE_THINKING="true"
      ;;
    08b:nothink|08b:nothink-text)
      HF_REPO="unsloth/Qwen3.5-0.8B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_0_8B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-08b-q4km-nothink-text"
      TEMPERATURE="1.0"
      TOP_P="1.0"
      TOP_K="20"
      PRESENCE_PENALTY="2.0"
      ENABLE_THINKING="false"
      ;;
    08b:nothink-vl)
      HF_REPO="unsloth/Qwen3.5-0.8B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_0_8B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-08b-q4km-nothink-vl"
      TEMPERATURE="0.7"
      TOP_P="0.80"
      TOP_K="20"
      PRESENCE_PENALTY="1.5"
      ENABLE_THINKING="false"
      ;;
    08b:qvac-current)
      HF_REPO="unsloth/Qwen3.5-0.8B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_0_8B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-08b-q4km-qvac-current"
      TEMPERATURE="0.1"
      TOP_P="0.9"
      TOP_K="40"
      REPEAT_PENALTY="1.1"
      PRESENCE_PENALTY="0"
      FREQUENCY_PENALTY="0"
      REASONING_BUDGET="-1"
      ENABLE_THINKING="true"
      ;;
    2b:think|2b:think-text)
      HF_REPO="unsloth/Qwen3.5-2B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_2B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-2b-q4km-think"
      TEMPERATURE="1.0"
      TOP_P="0.95"
      TOP_K="20"
      PRESENCE_PENALTY="1.5"
      REPEAT_PENALTY="1.0"
      ENABLE_THINKING="true"
      ;;
    2b:think-vl-webdev)
      HF_REPO="unsloth/Qwen3.5-2B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_2B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-2b-q4km-think-vl-webdev"
      TEMPERATURE="0.6"
      TOP_P="0.95"
      TOP_K="20"
      PRESENCE_PENALTY="0.0"
      REPEAT_PENALTY="1.0"
      ENABLE_THINKING="true"
      ;;
    2b:nothink|2b:nothink-text)
      HF_REPO="unsloth/Qwen3.5-2B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_2B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-2b-q4km-nothink"
      TEMPERATURE="1.0"
      TOP_P="1.0"
      TOP_K="20"
      PRESENCE_PENALTY="2.0"
      REPEAT_PENALTY="1.0"
      ENABLE_THINKING="false"
      ;;
    2b:nothink-vl)
      HF_REPO="unsloth/Qwen3.5-2B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_2B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-2b-q4km-nothink-vl"
      TEMPERATURE="0.7"
      TOP_P="0.80"
      TOP_K="20"
      PRESENCE_PENALTY="1.5"
      REPEAT_PENALTY="1.0"
      ENABLE_THINKING="false"
      ;;
    2b:qvac-current)
      HF_REPO="unsloth/Qwen3.5-2B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_2B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-2b-q4km-qvac-current"
      TEMPERATURE="0.1"
      TOP_P="0.9"
      TOP_K="40"
      REPEAT_PENALTY="1.1"
      PRESENCE_PENALTY="0"
      FREQUENCY_PENALTY="0"
      REASONING_BUDGET="-1"
      ENABLE_THINKING="true"
      ;;
    4b:think|4b:think-text)
      HF_REPO="unsloth/Qwen3.5-4B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_4B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-4b-q4km-think"
      TEMPERATURE="1.0"
      TOP_P="0.95"
      TOP_K="20"
      PRESENCE_PENALTY="1.5"
      ENABLE_THINKING="true"
      ;;
    4b:nothink|4b:nothink-text)
      HF_REPO="unsloth/Qwen3.5-4B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_4B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-4b-q4km-nothink"
      TEMPERATURE="1.0"
      TOP_P="1.0"
      TOP_K="40"
      PRESENCE_PENALTY="2.0"
      ENABLE_THINKING="false"
      ;;
    4b:qvac-current)
      HF_REPO="unsloth/Qwen3.5-4B-GGUF:Q4_K_M"
      MODEL_CONSTANT="QWEN3_5_4B_MULTIMODAL_Q4_K_M"
      MODEL_ALIAS="local-qwen35-4b-q4km-qvac-current"
      TEMPERATURE="0.1"
      TOP_P="0.9"
      TOP_K="40"
      REPEAT_PENALTY="1.1"
      PRESENCE_PENALTY="0"
      FREQUENCY_PENALTY="0"
      REASONING_BUDGET="-1"
      ENABLE_THINKING="true"
      ;;
    *)
      die "unknown preset '${preset}'"
      ;;
  esac

  PRESET="${preset}"
  PRESET_SAFE="$(safe_preset_name "${PRESET}")"
  QVAC_CONFIG_PATH="${CONFIG_DIR}/qvac-${PRESET_SAFE}.config.json"
  QVAC_SERVER_LOG="${LOG_DIR}/qvac-${PRESET_SAFE}.log"
}

print_preset() {
  printf 'preset=%s\n' "${PRESET}"
  printf 'model_alias=%s\n' "${MODEL_ALIAS}"
  printf 'hf_repo=%s\n' "${HF_REPO}"
  printf 'model_constant=%s\n' "${MODEL_CONSTANT}"
  printf 'temperature=%s top_p=%s top_k=%s presence_penalty=%s repetition_penalty=%s enable_thinking=%s\n' \
    "${TEMPERATURE}" "${TOP_P}" "${TOP_K}" "${PRESENCE_PENALTY}" "${REPEAT_PENALTY}" "${ENABLE_THINKING}"
}

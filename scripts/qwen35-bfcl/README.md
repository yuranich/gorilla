# Qwen 3.5 BFCL v4 via QVAC

Run BFCL v4 against local Qwen 3.5 GGUF Q4_K_M models served by `@qvac/cli` through its OpenAI-compatible HTTP server.

## Environment

These scripts are intended to run on Linux and macOS. They require `git`, `curl`, `jq`, Node/npm, and Python 3.10+. They prefer `python3.12`, then `python3.11`, `python3.10`, and finally `python3`. `uv` is reported by the environment check for convenience but is not required by this flow.

```bash
bash scripts/qwen35-bfcl/00-check-env.sh
bash scripts/qwen35-bfcl/01-install-user-deps.sh
```

`01-install-user-deps.sh` creates `berkeley-function-call-leaderboard/.venv-qvac-bfcl`, installs BFCL editable dependencies, and installs `@qvac/cli` with npm. If the system npm global prefix is not writable, it falls back to the user prefix `~/.local` and later scripts add `~/.local/bin` to `PATH` when that directory exists. Set `QVAC_NPM_PREFIX=/custom/prefix` if you want a different npm install location. The install script also patches local QVAC 0.7.0 schema files so llama.cpp `min_p` can be used in preset model configs.

## One-Preset Flow

Terminal 1:

```bash
bash scripts/qwen35-bfcl/03-serve-model.sh 08b:think
```

Terminal 2:

```bash
bash scripts/qwen35-bfcl/04-smoke.sh 08b:think
bash scripts/qwen35-bfcl/05-run-benchmark.sh 08b:think all_scoring
bash scripts/qwen35-bfcl/07-summarize.sh
```

Useful category shortcuts from BFCL v4:

- `single_turn`
- `multi_turn`
- `agentic`
- `all_scoring`

For a short local sanity run, set `BFCL_RUN_IDS=1` and create `berkeley-function-call-leaderboard/test_case_ids_to_generate.json` using BFCL's documented format.

## Matrix Flow

Run every preset sequentially:

```bash
bash scripts/qwen35-bfcl/06-run-matrix.sh all_scoring
```

Run a smaller matrix:

```bash
bash scripts/qwen35-bfcl/06-run-matrix.sh agentic 08b:think 2b:think 4b:think
```

## Presets

Supported presets:

- `08b:think`, `08b:think-vl-webdev`, `08b:nothink`, `08b:nothink-vl`, `08b:qvac-current`
- `2b:think`, `2b:think-vl-webdev`, `2b:nothink`, `2b:nothink-vl`, `2b:qvac-current`
- `4b:think`, `4b:nothink`, `4b:qvac-current`

The generated QVAC config stores preset sampling and thinking values in the QVAC model alias. Smoke and BFCL benchmark requests intentionally send no generation overrides, so each result is tied to the loaded preset alias. `ENABLE_THINKING=true|false` maps to QVAC's llama.cpp `reasoning_budget=-1|0` at load time. Generated configs default to `QVAC_CONTEXT_SIZE=32768`; override `QVAC_CONTEXT_SIZE` before registration/serving if you need a different `ctx_size`.

## Outputs

Default outputs:

- QVAC configs and logs: `scripts/qwen35-bfcl/.run/`
- BFCL results: `berkeley-function-call-leaderboard/result/qvac-qwen35/`
- BFCL scores: `berkeley-function-call-leaderboard/score/qvac-qwen35/`

Useful overrides:

```bash
BFCL_TEST_CATEGORIES=agentic BFCL_NUM_THREADS=1 bash scripts/qwen35-bfcl/05-run-benchmark.sh 4b:qvac-current
QVAC_PORT=11435 bash scripts/qwen35-bfcl/03-serve-model.sh 2b:nothink
BFCL_ALLOW_OVERWRITE=1 bash scripts/qwen35-bfcl/05-run-benchmark.sh 08b:think single_turn
```

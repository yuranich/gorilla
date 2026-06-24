# Qwen 3.5 BFCL v4 via QVAC

Run BFCL v4 against local Qwen 3.5 GGUF Q4_K_M models served by `@qvac/cli` through its OpenAI-compatible HTTP server.

## Environment

On this Mac, the missing dependency is `qvac`. Node/npm, `jq`, `curl`, `git`, Homebrew, `uv`, and Python 3.12 are available. The default `python3` is 3.14, so the install script prefers `python3.12` for BFCL.

```bash
bash scripts/qwen35-bfcl/00-check-env.sh
bash scripts/qwen35-bfcl/01-install-user-deps.sh
```

`01-install-user-deps.sh` creates `berkeley-function-call-leaderboard/.venv-qvac-bfcl`, installs BFCL editable dependencies, and installs `@qvac/cli` globally with npm. The Docker GPU script is a macOS no-op kept only for parity with other benchmark scaffolds.

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
- `2b:think`, `2b:nothink`, `2b:qvac-current`
- `4b:think`, `4b:nothink`, `4b:qvac-current`

The generated QVAC config stores preset sampling and thinking values in the QVAC model alias. Smoke and BFCL benchmark requests intentionally send no generation overrides, so each result is tied to the loaded preset alias. `ENABLE_THINKING=true|false` maps to QVAC's llama.cpp `reasoning_budget=-1|0` at load time.

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

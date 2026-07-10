#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
from pathlib import Path
from types import SimpleNamespace


def split_csv(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def register_qvac_model(alias: str, display_name: str, is_fc_model: bool = True) -> None:
    from bfcl_eval.constants.model_config import MODEL_CONFIG_MAPPING, ModelConfig
    from bfcl_eval.model_handler.api_inference.openai_completion import (
        OpenAICompletionsHandler,
    )

    class QvacPresetHandler(OpenAICompletionsHandler):
        def _query_FC(self, inference_data: dict):
            message: list[dict] = inference_data["message"]
            tools = inference_data["tools"]
            inference_data["inference_input_log"] = {
                "message": repr(message),
                "tools": tools,
            }

            kwargs = {
                "messages": message,
                "model": self.model_name,
                "store": False,
            }

            if len(tools) > 0:
                kwargs["tools"] = tools

            return self.generate_with_backoff(**kwargs)

        def _query_prompting(self, inference_data: dict):
            inference_data["inference_input_log"] = {
                "message": repr(inference_data["message"])
            }

            return self.generate_with_backoff(
                messages=inference_data["message"],
                model=self.model_name,
                store=False,
            )

    MODEL_CONFIG_MAPPING[alias] = ModelConfig(
        model_name=alias,
        display_name=display_name,
        url=f"local-qvac://{alias}",
        org="QVAC local",
        license="Model license follows the configured Hugging Face source",
        model_handler=QvacPresetHandler,
        input_price=None,
        output_price=None,
        is_fc_model=is_fc_model,
        underscore_to_dot=True,
    )


def register_existing_qvac_models(args: argparse.Namespace, is_fc_model: bool) -> None:
    from bfcl_eval.constants.eval_config import PROJECT_ROOT

    for dirname in [args.result_dir, args.score_dir]:
        path = Path(dirname)
        if not path.is_absolute():
            path = PROJECT_ROOT / path
        if not path.exists():
            continue

        for model_dir in path.iterdir():
            if model_dir.is_dir() and model_dir.name.startswith("local-qwen35-"):
                register_qvac_model(
                    alias=model_dir.name,
                    display_name=model_dir.name,
                    is_fc_model=is_fc_model,
                )


def generate(args: argparse.Namespace) -> None:
    from bfcl_eval._llm_response_generation import main as generation_main

    generation_args = SimpleNamespace(
        model=[args.model_alias],
        test_category=split_csv(args.categories),
        temperature=0.001,
        include_input_log=args.include_input_log,
        exclude_state_log=args.exclude_state_log,
        num_gpus=0,
        num_threads=args.num_threads,
        gpu_memory_utilization=0.0,
        backend="sglang",
        skip_server_setup=True,
        local_model_path=None,
        result_dir=args.result_dir,
        allow_overwrite=args.allow_overwrite,
        run_ids=args.run_ids,
        enable_lora=False,
        max_lora_rank=None,
        lora_modules=None,
    )
    generation_main(generation_args)


def evaluate(args: argparse.Namespace) -> None:
    from bfcl_eval.eval_checker.eval_runner import main as evaluation_main

    evaluation_main(
        [args.model_alias],
        split_csv(args.categories),
        args.result_dir,
        args.score_dir,
        args.partial_eval,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Run BFCL against a QVAC OpenAI endpoint")
    parser.add_argument("command", choices=["generate", "evaluate", "generate-evaluate"])
    parser.add_argument("--model-alias", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--categories", default="all_scoring")
    parser.add_argument("--num-threads", type=int, default=1)
    parser.add_argument("--base-url", default="http://127.0.0.1:11434/v1")
    parser.add_argument("--api-key", default="EMPTY")
    parser.add_argument("--result-dir", default="result/qvac-qwen35")
    parser.add_argument("--score-dir", default="score/qvac-qwen35")
    parser.add_argument("--allow-overwrite", action="store_true")
    parser.add_argument("--partial-eval", action="store_true")
    parser.add_argument("--include-input-log", action="store_true")
    parser.add_argument("--exclude-state-log", action="store_true")
    parser.add_argument("--run-ids", action="store_true")
    parser.add_argument("--prompt-mode", action="store_true")
    args = parser.parse_args()

    os.environ["OPENAI_BASE_URL"] = args.base_url
    os.environ["OPENAI_API_KEY"] = args.api_key
    os.environ["TOKENIZERS_PARALLELISM"] = "false"

    is_fc_model = not args.prompt_mode
    register_existing_qvac_models(args, is_fc_model=is_fc_model)
    register_qvac_model(
        alias=args.model_alias,
        display_name=args.display_name,
        is_fc_model=is_fc_model,
    )

    if args.command in {"generate", "generate-evaluate"}:
        generate(args)
    if args.command in {"evaluate", "generate-evaluate"}:
        evaluate(args)


if __name__ == "__main__":
    main()

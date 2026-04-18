from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal
from app.services.perf_sample_seed_service import (
    build_runtime_order_ref,
    reset_runtime_samples,
    seed_production_craft_samples,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="初始化 production + craft 性能样本。")
    parser.add_argument(
        "--mode",
        choices=["ensure", "check", "reset"],
        default="ensure",
        help="ensure=初始化基线样本；check=校验并输出当前上下文；reset=复位指定 run_id 的运行时样本。",
    )
    parser.add_argument("--run-id", default="baseline", help="运行标识，默认 baseline。")
    parser.add_argument(
        "--output-json",
        default=".tmp_runtime/production_craft_samples.json",
        help="ensure 模式输出的上下文 JSON 路径。",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    db = SessionLocal()
    try:
        if args.mode == "ensure":
            result = seed_production_craft_samples(db, run_id=args.run_id, mode="baseline")
            output_path = Path(args.output_json)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(
                json.dumps(result.context, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            print(
                json.dumps(
                    {
                        "created_count": result.created_count,
                        "updated_count": result.updated_count,
                        "output_json": str(output_path),
                    },
                    ensure_ascii=False,
                )
            )
            return

        if args.mode == "check":
            result = seed_production_craft_samples(db, run_id=args.run_id, mode="baseline")
            print(json.dumps(result.context, ensure_ascii=False, indent=2))
            return

        runtime_refs = []
        if args.run_id and args.run_id != "baseline":
            runtime_refs.append(build_runtime_order_ref(args.run_id))
        reset_runtime_samples(db, runtime_refs, restore_strategy="rebuild")
        print(
            json.dumps(
                {
                    "reset_refs": runtime_refs,
                    "status": "ok",
                },
                ensure_ascii=False,
            )
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()

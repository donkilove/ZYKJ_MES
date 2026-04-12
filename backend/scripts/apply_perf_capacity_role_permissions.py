from __future__ import annotations

import argparse
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal
from app.services.perf_capacity_permission_service import (
    apply_perf_capacity_permission_rollout,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="下发后端 P95-40 阶段 1 业务角色模块权限。")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只计算变更，不写入数据库。",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    db = SessionLocal()
    try:
        result = apply_perf_capacity_permission_rollout(db, dry_run=args.dry_run)
        print(
            "Applied perf capacity role permissions. "
            f"role_module_pairs={result.role_module_pairs}, updated_count={result.updated_count}, dry_run={args.dry_run}"
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.config import settings
from app.db.session import SessionLocal
from app.services.bootstrap_seed_service import seed_initial_data
from app.services.perf_capacity_permission_service import (
    apply_perf_capacity_permission_rollout,
)
from app.services.perf_user_seed_service import seed_perf_capacity_users


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="初始化后端 P95-40 压测账号。")
    parser.add_argument(
        "--password",
        default=os.getenv("PERF_USER_PASSWORD") or settings.bootstrap_admin_password,
        help="压测账号统一密码。默认读取 PERF_USER_PASSWORD，其次回落到 BOOTSTRAP_ADMIN_PASSWORD。",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    db = SessionLocal()
    try:
        seed_initial_data(
            db,
            admin_username=settings.bootstrap_admin_username,
            admin_password=settings.bootstrap_admin_password,
        )
        result = seed_perf_capacity_users(db, password=args.password)
        permission_result = apply_perf_capacity_permission_rollout(db)
        print(
            "Initialized perf capacity users. "
            f"created={result.created_count}, updated={result.updated_count}, "
            f"permission_updates={permission_result.updated_count}, "
            f"usernames={','.join(result.usernames)}"
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()

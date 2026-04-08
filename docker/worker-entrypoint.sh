#!/usr/bin/env sh
set -eu

cd /app/backend

exec python - <<'PY'
import asyncio
import importlib
import inspect


def try_run_worker_main() -> bool:
    try:
        module = importlib.import_module("app.worker_main")
    except ModuleNotFoundError as exc:
        if exc.name == "app.worker_main":
            return False
        raise

    entry = getattr(module, "main", None) or getattr(module, "run", None)
    if entry is None:
        raise RuntimeError("app.worker_main 存在，但未提供 main() 或 run()")

    result = entry()
    if inspect.isawaitable(result):
        asyncio.run(result)
    return True


if try_run_worker_main():
    raise SystemExit(0)

from app.bootstrap import run_startup_bootstrap
from app.core.config import settings
from app.services.maintenance_scheduler_service import run_maintenance_auto_generate_loop
from app.services.message_service import run_message_delivery_maintenance_loop


async def legacy_main() -> None:
    run_startup_bootstrap()
    tasks = []
    if settings.maintenance_auto_generate_enabled:
        tasks.append(asyncio.create_task(run_maintenance_auto_generate_loop()))
    if settings.message_delivery_maintenance_enabled:
        tasks.append(asyncio.create_task(run_message_delivery_maintenance_loop()))
    if not tasks:
        while True:
            await asyncio.sleep(3600)
    await asyncio.gather(*tasks)


asyncio.run(legacy_main())
PY

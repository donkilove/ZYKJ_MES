from __future__ import annotations

import asyncio
import logging

from app.bootstrap import run_startup_bootstrap
from app.core.config import ensure_runtime_settings_secure, settings
from app.services.maintenance_scheduler_service import run_maintenance_auto_generate_loop
from app.services.message_service import run_message_delivery_maintenance_loop


logger = logging.getLogger(__name__)


async def run_worker() -> None:
    ensure_runtime_settings_secure()
    if settings.worker_run_bootstrap:
        run_startup_bootstrap()

    if not settings.worker_run_background_loops:
        logger.info("[WORKER] 后台循环已禁用，worker 直接退出。")
        return

    tasks: list[asyncio.Task[None]] = []
    if settings.maintenance_auto_generate_enabled:
        tasks.append(asyncio.create_task(run_maintenance_auto_generate_loop()))
    if settings.message_delivery_maintenance_enabled:
        tasks.append(asyncio.create_task(run_message_delivery_maintenance_loop()))
    if not tasks:
        logger.info("[WORKER] 没有可运行的后台循环，worker 直接退出。")
        return
    await asyncio.gather(*tasks)


def main() -> None:
    asyncio.run(run_worker())


if __name__ == "__main__":
    main()

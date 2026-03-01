from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.core.config import settings
from app.db.session import SessionLocal
from app.services.equipment_service import generate_due_work_orders_for_today

logger = logging.getLogger(__name__)


def _resolve_timezone() -> ZoneInfo:
    try:
        return ZoneInfo(settings.maintenance_auto_generate_timezone)
    except ZoneInfoNotFoundError:
        logger.warning(
            "[MAINT_SCHED] Invalid timezone '%s', fallback to UTC.",
            settings.maintenance_auto_generate_timezone,
        )
        return ZoneInfo("UTC")


def _resolve_target_clock() -> tuple[int, int]:
    value = settings.maintenance_auto_generate_time.strip()
    try:
        hour_text, minute_text = value.split(":", maxsplit=1)
        hour = int(hour_text)
        minute = int(minute_text)
    except (ValueError, TypeError):
        logger.warning(
            "[MAINT_SCHED] Invalid MAINTENANCE_AUTO_GENERATE_TIME='%s', fallback to 00:05.",
            value,
        )
        return 0, 5

    if hour < 0 or hour > 23 or minute < 0 or minute > 59:
        logger.warning(
            "[MAINT_SCHED] Out-of-range MAINTENANCE_AUTO_GENERATE_TIME='%s', fallback to 00:05.",
            value,
        )
        return 0, 5
    return hour, minute


def _seconds_until_next_run(now: datetime, hour: int, minute: int) -> float:
    target = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if target <= now:
        target += timedelta(days=1)
    return max(1.0, (target - now).total_seconds())


async def run_maintenance_auto_generate_loop() -> None:
    tz = _resolve_timezone()
    hour, minute = _resolve_target_clock()
    logger.info(
        "[MAINT_SCHED] Auto generation loop started at %02d:%02d %s.",
        hour,
        minute,
        tz.key,
    )

    while True:
        now = datetime.now(tz)
        sleep_seconds = _seconds_until_next_run(now, hour, minute)
        await asyncio.sleep(sleep_seconds)

        db = SessionLocal()
        try:
            total, created, existing = generate_due_work_orders_for_today(db)
            logger.info(
                "[MAINT_SCHED] Scan done. plans=%s created=%s existing=%s.",
                total,
                created,
                existing,
            )
        except Exception:
            logger.exception("[MAINT_SCHED] Auto generation failed.")
        finally:
            db.close()

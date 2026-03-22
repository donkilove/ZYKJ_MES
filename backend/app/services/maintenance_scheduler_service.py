from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.core.config import settings
from app.core.rbac import ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.db.session import SessionLocal
from app.services.equipment_service import generate_due_work_orders_for_today
from app.services.message_service import create_message_for_users
from app.services.user_service import get_active_user_ids_by_role

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
            total, created, existing, failed, new_orders, _ = (
                generate_due_work_orders_for_today(db, include_new_orders=True)
            )
            logger.info(
                "[MAINT_SCHED] Scan done. plans=%s created=%s existing=%s failed=%s.",
                total,
                created,
                existing,
                failed,
            )
            # 为每条新建工单推送消息给执行人和管理员
            if new_orders:
                admin_ids = get_active_user_ids_by_role(
                    db, ROLE_SYSTEM_ADMIN
                ) + get_active_user_ids_by_role(db, ROLE_PRODUCTION_ADMIN)
                for wo in new_orders:
                    recipient_ids: list[int] = list(
                        {
                            *([wo.executor_user_id] if wo.executor_user_id else []),
                            *admin_ids,
                        }
                    )
                    if not recipient_ids:
                        continue
                    create_message_for_users(
                        db,
                        message_type="todo",
                        priority="important",
                        title=f"保养工单已生成：{wo.source_equipment_name} - {wo.source_item_name}",
                        summary=f"到期日：{wo.due_date}，请及时安排保养执行。",
                        source_module="equipment",
                        source_type="maintenance_work_order",
                        source_id=str(wo.id),
                        source_code=str(wo.id),
                        target_page_code="equipment",
                        target_tab_code="maintenance_execution",
                        target_route_payload_json=json.dumps(
                            {
                                "action": "detail",
                                "work_order_id": wo.id,
                            },
                            ensure_ascii=False,
                        ),
                        recipient_user_ids=recipient_ids,
                        dedupe_key=f"maint_wo_created_{wo.id}",
                    )
        except Exception:
            logger.exception("[MAINT_SCHED] Auto generation failed.")
        finally:
            db.close()

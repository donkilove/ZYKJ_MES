from __future__ import annotations

from typing import Any

from datetime import UTC, datetime
from sqlalchemy import Select, String, and_, cast as sa_cast, func, select
from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog
from app.models.user import User


def _build_audit_log_filters(
    *,
    operator_username: str | None = None,
    action_code: str | None = None,
    target_type: str | None = None,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
) -> list[Any]:
    filters: list[Any] = []
    if operator_username:
        filters.append(
            sa_cast(AuditLog.operator_username, String).ilike(
                f"%{operator_username.strip()}%"
            )
        )
    if action_code:
        filters.append(AuditLog.action_code == action_code.strip())
    if target_type:
        filters.append(AuditLog.target_type == target_type.strip())
    if start_time:
        filters.append(AuditLog.occurred_at >= start_time)
    if end_time:
        filters.append(AuditLog.occurred_at <= end_time)
    return filters


def write_audit_log(
    db: Session,
    *,
    action_code: str,
    action_name: str,
    target_type: str,
    target_id: str | None = None,
    target_name: str | None = None,
    operator: User | None = None,
    before_data: dict[str, object] | None = None,
    after_data: dict[str, object] | None = None,
    ip_address: str | None = None,
    terminal_info: str | None = None,
    result: str = "success",
    remark: str | None = None,
) -> AuditLog:
    row = AuditLog(
        occurred_at=datetime.now(UTC),
        operator_user_id=operator.id if operator else None,
        operator_username=operator.username if operator else None,
        action_code=action_code,
        action_name=action_name,
        target_type=target_type,
        target_id=target_id,
        target_name=target_name,
        result=result,
        before_data=before_data,
        after_data=after_data,
        ip_address=ip_address,
        terminal_info=terminal_info,
        remark=remark,
    )
    db.add(row)
    db.flush()
    return row


def query_audit_logs(
    *,
    operator_username: str | None = None,
    action_code: str | None = None,
    target_type: str | None = None,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
) -> Select[tuple[AuditLog]]:
    stmt = select(AuditLog).order_by(AuditLog.occurred_at.desc(), AuditLog.id.desc())
    filters = _build_audit_log_filters(
        operator_username=operator_username,
        action_code=action_code,
        target_type=target_type,
        start_time=start_time,
        end_time=end_time,
    )
    if filters:
        stmt = stmt.where(and_(*filters))
    return stmt


def list_audit_logs(
    db: Session,
    *,
    page: int,
    page_size: int,
    operator_username: str | None = None,
    action_code: str | None = None,
    target_type: str | None = None,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
) -> tuple[int, list[AuditLog]]:
    filters = _build_audit_log_filters(
        operator_username=operator_username,
        action_code=action_code,
        target_type=target_type,
        start_time=start_time,
        end_time=end_time,
    )
    stmt = query_audit_logs(
        operator_username=operator_username,
        action_code=action_code,
        target_type=target_type,
        start_time=start_time,
        end_time=end_time,
    )
    total_stmt = select(func.count(AuditLog.id))
    if filters:
        total_stmt = total_stmt.where(and_(*filters))
    total = int(db.execute(total_stmt).scalar_one())
    rows: list[AuditLog] = list(
        db.execute(stmt.offset((page - 1) * page_size).limit(page_size)).scalars().all()
    )
    return total, rows

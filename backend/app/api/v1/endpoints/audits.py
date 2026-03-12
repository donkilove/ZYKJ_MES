from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.audit_log import AuditLog
from app.models.user import User
from app.schemas.audit import AuditLogItem, AuditLogListResult
from app.schemas.common import ApiResponse, success_response
from app.services.audit_service import list_audit_logs


router = APIRouter()


def to_item(row: AuditLog) -> AuditLogItem:
    return AuditLogItem(
        id=row.id,
        occurred_at=row.occurred_at,
        operator_user_id=row.operator_user_id,
        operator_username=row.operator_username,
        action_code=row.action_code,
        action_name=row.action_name,
        target_type=row.target_type,
        target_id=row.target_id,
        target_name=row.target_name,
        result=row.result,
        before_data=row.before_data,
        after_data=row.after_data,
        ip_address=row.ip_address,
        terminal_info=row.terminal_info,
        remark=row.remark,
    )


@router.get("", response_model=ApiResponse[AuditLogListResult])
def get_audit_logs(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    operator_username: str | None = Query(default=None),
    action_code: str | None = Query(default=None),
    target_type: str | None = Query(default=None),
    start_time: datetime | None = Query(default=None),
    end_time: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.audit_logs.list")),
) -> ApiResponse[AuditLogListResult]:
    total, items = list_audit_logs(
        db,
        page=page,
        page_size=page_size,
        operator_username=operator_username,
        action_code=action_code,
        target_type=target_type,
        start_time=start_time,
        end_time=end_time,
    )
    return success_response(AuditLogListResult(total=total, items=[to_item(row) for row in items]))

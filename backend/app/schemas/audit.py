from datetime import datetime

from pydantic import BaseModel


class AuditLogItem(BaseModel):
    id: int
    occurred_at: datetime
    operator_user_id: int | None = None
    operator_username: str | None = None
    action_code: str
    action_name: str
    target_type: str
    target_id: str | None = None
    target_name: str | None = None
    result: str
    before_data: dict[str, object] | None = None
    after_data: dict[str, object] | None = None
    ip_address: str | None = None
    terminal_info: str | None = None
    remark: str | None = None


class AuditLogListResult(BaseModel):
    total: int
    items: list[AuditLogItem]

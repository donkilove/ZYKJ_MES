from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class MessageItem(BaseModel):
    """消息列表条目"""

    id: int
    message_type: str
    priority: str
    title: str
    summary: str | None
    content: str | None = None
    source_module: str | None
    source_type: str | None
    source_code: str | None
    target_page_code: str | None
    target_tab_code: str | None
    target_route_payload_json: str | None
    status: str
    inactive_reason: str | None = None
    published_at: datetime | None
    expires_at: datetime | None = None
    # 收件记录字段
    is_read: bool
    read_at: datetime | None
    delivered_at: datetime | None
    delivery_status: str
    delivery_attempt_count: int
    last_push_at: datetime | None
    next_retry_at: datetime | None


class AnnouncementManagementItem(BaseModel):
    id: int
    message_type: str
    priority: str
    title: str
    summary: str | None
    content: str | None = None
    source_module: str | None
    source_type: str | None
    source_code: str | None
    target_page_code: str | None
    target_tab_code: str | None
    target_route_payload_json: str | None
    status: str
    inactive_reason: str | None = None
    published_at: datetime | None
    expires_at: datetime | None = None


class MessageListResult(BaseModel):
    items: list[MessageItem]
    total: int
    page: int
    page_size: int


class MessageDetailResult(BaseModel):
    id: int
    message_type: str
    priority: str
    title: str
    summary: str | None
    content: str | None = None
    source_module: str | None
    source_type: str | None
    source_id: str | None
    source_code: str | None
    target_page_code: str | None
    target_tab_code: str | None
    target_route_payload_json: str | None
    status: str
    inactive_reason: str | None = None
    published_at: datetime | None
    is_read: bool
    read_at: datetime | None
    delivered_at: datetime | None
    delivery_status: str
    delivery_attempt_count: int
    last_push_at: datetime | None
    next_retry_at: datetime | None
    failure_reason_hint: str | None = None


class MessageJumpResult(BaseModel):
    can_jump: bool
    disabled_reason: str | None = None
    target_page_code: str | None = None
    target_tab_code: str | None = None
    target_route_payload_json: str | None = None


class MessageSummaryResult(BaseModel):
    total_count: int
    unread_count: int
    todo_unread_count: int
    urgent_unread_count: int


class MessageBatchReadRequest(BaseModel):
    message_ids: list[int]


class UnreadCountResult(BaseModel):
    unread_count: int


class MessageCreateRequest(BaseModel):
    """内部创建消息请求（供来源模块调用）"""

    message_type: str
    priority: str = "normal"
    title: str
    summary: str | None = None
    content: str | None = None
    source_module: str | None = None
    source_type: str | None = None
    source_id: str | None = None
    source_code: str | None = None
    target_page_code: str | None = None
    target_tab_code: str | None = None
    target_route_payload_json: str | None = None
    dedupe_key: str | None = None
    expires_at: datetime | None = None
    recipient_user_ids: list[int] = Field(default_factory=list)
    created_by_user_id: int | None = None


class AnnouncementPublishRequest(BaseModel):
    title: str
    content: str
    priority: str = "normal"
    range_type: str
    role_codes: list[str] = Field(default_factory=list)
    user_ids: list[int] = Field(default_factory=list)
    expires_at: datetime | None = None


class AnnouncementPublishResult(BaseModel):
    message_id: int
    recipient_count: int


class AnnouncementOfflineResult(BaseModel):
    message_id: int
    status: str


class MessageMaintenanceResult(BaseModel):
    pending_compensated: int
    failed_retried: int
    source_unavailable_updated: int
    archived_messages: int

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class MessageItem(BaseModel):
    """消息列表条目"""

    id: int
    message_type: str
    priority: str
    title: str
    summary: str | None
    source_module: str | None
    source_type: str | None
    source_code: str | None
    target_page_code: str | None
    target_tab_code: str | None
    target_route_payload_json: str | None
    status: str
    published_at: datetime | None
    # 收件记录字段
    is_read: bool
    read_at: datetime | None
    delivered_at: datetime | None


class MessageListResult(BaseModel):
    items: list[MessageItem]
    total: int
    page: int
    page_size: int


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
    recipient_user_ids: list[int] = []
    created_by_user_id: int | None = None

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Message(Base, TimestampMixin):
    """站内消息主表"""

    __tablename__ = "msg_message"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    # 消息类型：todo=待处理提醒 / notice=普通通知 / announcement=系统公告 / warning=异常预警
    message_type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    # 优先级：normal=普通 / important=重要 / urgent=紧急
    priority: Mapped[str] = mapped_column(String(16), nullable=False, default="normal", index=True)
    title: Mapped[str] = mapped_column(String(256), nullable=False)
    summary: Mapped[str | None] = mapped_column(String(512), nullable=True)
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    # 来源模块标识，如 user / production / equipment / quality / craft / product
    source_module: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    # 来源业务类型，如 registration_request / assist_authorization / maintenance_work_order
    source_type: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    # 来源业务对象 ID
    source_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    # 来源业务对象编号（用于展示）
    source_code: Mapped[str | None] = mapped_column(String(128), nullable=True)
    # 跳转目标页面 code
    target_page_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    # 跳转目标 tab code
    target_tab_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    # 跳转路由附加参数（JSON 字符串）
    target_route_payload_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    # 去重键，防止同一事件重复创建消息；非空时全局唯一
    dedupe_key: Mapped[str | None] = mapped_column(String(256), nullable=True)
    # 消息状态：active=有效 / source_unavailable=来源失效 / archived=已归档
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="active", index=True)
    published_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"), nullable=True
    )

    recipients: Mapped[list["MessageRecipient"]] = relationship(
        "MessageRecipient", back_populates="message", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index(
            "uq_msg_message_dedupe_key_not_null",
            "dedupe_key",
            unique=True,
            postgresql_where=dedupe_key.isnot(None),
            sqlite_where=dedupe_key.isnot(None),
        ),
        Index("ix_msg_message_type_priority_published", "message_type", "priority", "published_at"),
        Index("ix_msg_message_source", "source_module", "source_type", "source_id"),
    )

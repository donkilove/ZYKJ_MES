from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class MessageRecipient(Base, TimestampMixin):
    """消息收件记录表，按用户维度记录已读状态"""

    __tablename__ = "msg_message_recipient"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    message_id: Mapped[int] = mapped_column(
        ForeignKey("msg_message.id", ondelete="CASCADE"), nullable=False, index=True
    )
    recipient_user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # 投递状态：pending=待投递 / delivered=已投递 / failed=投递失败
    delivery_status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="pending"
    )
    delivered_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_read: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, index=True
    )
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_deleted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    last_push_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # 最近一次失败原因，便于补偿与排障
    last_failure_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # 已发起的投递尝试次数（包含首次推送）
    delivery_attempt_count: Mapped[int] = mapped_column(nullable=False, default=0)
    # 下次重试时间；为空表示当前无待执行重试
    next_retry_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )

    message: Mapped["Message"] = relationship("Message", back_populates="recipients")

    __table_args__ = (
        UniqueConstraint(
            "message_id", "recipient_user_id", name="uq_msg_recipient_message_user"
        ),
        Index(
            "ix_msg_recipient_user_unread",
            "recipient_user_id",
            "is_read",
            "created_at",
        ),
    )

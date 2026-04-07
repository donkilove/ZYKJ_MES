from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UserExportTask(Base):
    __tablename__ = "sys_user_export_task"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    task_code: Mapped[str] = mapped_column(String(64), nullable=False, unique=True, index=True)
    created_by_user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        server_default=text("'pending'"),
        index=True,
    )
    format: Mapped[str] = mapped_column(String(16), nullable=False)
    deleted_scope: Mapped[str] = mapped_column(String(16), nullable=False)
    keyword: Mapped[str | None] = mapped_column(String(255), nullable=True)
    role_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    is_active: Mapped[bool | None] = mapped_column(nullable=True)
    record_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=text("0"),
    )
    file_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    mime_type: Mapped[str | None] = mapped_column(String(128), nullable=True)
    storage_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    failure_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    requested_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=text("now()"),
        index=True,
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)

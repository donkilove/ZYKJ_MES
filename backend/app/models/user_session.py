from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UserSession(Base):
    __tablename__ = "sys_user_session"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    session_token_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="active",
        server_default=text("'active'"),
        index=True,
    )
    is_forced_offline: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    login_type: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="web",
        server_default=text("'web'"),
    )
    login_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True,
    )
    last_active_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True,
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    logout_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    login_ip: Mapped[str | None] = mapped_column(String(64), nullable=True)
    terminal_info: Mapped[str | None] = mapped_column(String(255), nullable=True)

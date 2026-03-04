from datetime import date

from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class DailyVerificationCode(Base, TimestampMixin):
    __tablename__ = "mes_daily_verification_code"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    verify_date: Mapped[date] = mapped_column(Date, nullable=False, unique=True, index=True)
    code: Mapped[str] = mapped_column(String(32), nullable=False)
    created_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    created_by = relationship("User")

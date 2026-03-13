from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class FirstArticleDisposition(Base, TimestampMixin):
    __tablename__ = "mes_first_article_disposition"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    first_article_record_id: Mapped[int] = mapped_column(
        ForeignKey("mes_first_article_record.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        unique=True,
    )
    disposition_opinion: Mapped[str] = mapped_column(Text, nullable=False)
    disposition_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    disposition_username: Mapped[str | None] = mapped_column(String(128), nullable=True)
    disposition_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    recheck_result: Mapped[str | None] = mapped_column(String(32), nullable=True)
    final_judgment: Mapped[str] = mapped_column(String(32), nullable=False)

    first_article_record = relationship("FirstArticleRecord")
    disposition_user = relationship("User")

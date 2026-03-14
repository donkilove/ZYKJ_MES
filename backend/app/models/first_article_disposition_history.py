from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class FirstArticleDispositionHistory(Base, TimestampMixin):
    """首件处置历史记录表，每次处置均追加一条，禁止覆盖。"""

    __tablename__ = "mes_first_article_disposition_history"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    first_article_record_id: Mapped[int] = mapped_column(
        ForeignKey("mes_first_article_record.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
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
    # 版本号，从 1 开始递增
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)

    first_article_record = relationship("FirstArticleRecord")
    disposition_user = relationship("User")

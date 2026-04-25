from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class FirstArticleRecord(Base, TimestampMixin):
    __tablename__ = "mes_first_article_record"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    order_id: Mapped[int] = mapped_column(
        ForeignKey("mes_order.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    order_process_id: Mapped[int] = mapped_column(
        ForeignKey("mes_order_process.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    operator_user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    template_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_first_article_template.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    verification_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    verification_code: Mapped[str] = mapped_column(String(32), nullable=False)
    result: Mapped[str] = mapped_column(String(32), nullable=False, default="passed")
    check_content: Mapped[str | None] = mapped_column(Text, nullable=True)
    test_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    remark: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewer_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    review_remark: Mapped[str | None] = mapped_column(Text, nullable=True)

    order = relationship("ProductionOrder", back_populates="first_article_records")
    order_process = relationship("ProductionOrderProcess", back_populates="first_article_records")
    operator = relationship("User", foreign_keys=[operator_user_id])
    reviewer = relationship("User", foreign_keys=[reviewer_user_id])
    template = relationship("FirstArticleTemplate")
    participants = relationship(
        "FirstArticleParticipant",
        back_populates="record",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

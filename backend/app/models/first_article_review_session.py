from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class FirstArticleReviewSession(Base, TimestampMixin):
    __tablename__ = "mes_first_article_review_session"
    __table_args__ = (
        Index(
            "ix_mes_first_article_review_session_token_hash",
            "token_hash",
            unique=True,
        ),
        Index("ix_mes_first_article_review_session_status", "status"),
        Index("ix_mes_first_article_review_session_expires_at", "expires_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    token_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
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
    pipeline_instance_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_order_sub_order_pipeline_instance.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    operator_user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    assist_authorization_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_production_assist_authorization.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    template_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_first_article_template.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    check_content: Mapped[str] = mapped_column(Text, nullable=False)
    test_value: Mapped[str] = mapped_column(Text, nullable=False)
    participant_user_ids: Mapped[list[int]] = mapped_column(
        JSON,
        nullable=False,
        default=list,
    )
    reviewer_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    review_result: Mapped[str | None] = mapped_column(String(32), nullable=True)
    review_remark: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    first_article_record_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_first_article_record.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    order = relationship("ProductionOrder")
    order_process = relationship("ProductionOrderProcess")
    pipeline_instance = relationship("OrderSubOrderPipelineInstance")
    operator = relationship("User", foreign_keys=[operator_user_id])
    reviewer = relationship("User", foreign_keys=[reviewer_user_id])
    assist_authorization = relationship("ProductionAssistAuthorization")
    template = relationship("FirstArticleTemplate")
    first_article_record = relationship("FirstArticleRecord")

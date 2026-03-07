from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductionAssistAuthorization(Base, TimestampMixin):
    __tablename__ = "mes_production_assist_authorization"
    __table_args__ = (
        Index(
            "ix_mes_production_assist_authorization_status",
            "status",
        ),
        Index(
            "ix_mes_production_assist_authorization_helper_user_id",
            "helper_user_id",
        ),
        Index(
            "ix_mes_production_assist_authorization_requester_user_id",
            "requester_user_id",
        ),
        Index(
            "ix_mes_production_assist_authorization_order_process",
            "order_id",
            "order_process_id",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    order_id: Mapped[int] = mapped_column(
        ForeignKey("mes_order.id", ondelete="CASCADE"),
        nullable=False,
    )
    order_process_id: Mapped[int] = mapped_column(
        ForeignKey("mes_order_process.id", ondelete="CASCADE"),
        nullable=False,
    )
    target_operator_user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="RESTRICT"),
        nullable=False,
    )
    requester_user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="RESTRICT"),
        nullable=False,
    )
    helper_user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="RESTRICT"),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="pending",
    )
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    review_remark: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewer_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    first_article_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    end_production_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    order = relationship("ProductionOrder")
    order_process = relationship("ProductionOrderProcess")
    target_operator = relationship("User", foreign_keys=[target_operator_user_id])
    requester = relationship("User", foreign_keys=[requester_user_id])
    helper = relationship("User", foreign_keys=[helper_user_id])
    reviewer = relationship("User", foreign_keys=[reviewer_user_id])

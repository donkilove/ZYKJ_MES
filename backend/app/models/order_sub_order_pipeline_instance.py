from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class OrderSubOrderPipelineInstance(Base, TimestampMixin):
    __tablename__ = "mes_order_sub_order_pipeline_instance"
    __table_args__ = (
        UniqueConstraint(
            "sub_order_id",
            "pipeline_seq",
            name="uq_mes_order_sub_order_pipeline_instance_sub_order_seq",
        ),
        UniqueConstraint(
            "pipeline_sub_order_no",
            name="uq_mes_order_sub_order_pipeline_instance_no",
        ),
        Index(
            "ix_mes_order_sub_order_pipeline_instance_order_process",
            "order_id",
            "order_process_id",
        ),
        Index(
            "ix_mes_order_sub_order_pipeline_instance_is_active",
            "is_active",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    sub_order_id: Mapped[int] = mapped_column(
        ForeignKey("mes_order_sub_order.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
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
    process_code: Mapped[str] = mapped_column(String(64), nullable=False)
    pipeline_seq: Mapped[int] = mapped_column(Integer, nullable=False)
    pipeline_sub_order_no: Mapped[str] = mapped_column(String(64), nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    invalid_reason: Mapped[str | None] = mapped_column(String(128), nullable=True)
    invalidated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    order = relationship("ProductionOrder", back_populates="pipeline_instances")
    order_process = relationship("ProductionOrderProcess")
    sub_order = relationship("ProductionSubOrder", back_populates="pipeline_instances")

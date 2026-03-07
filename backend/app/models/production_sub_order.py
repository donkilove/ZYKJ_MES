from sqlalchemy import Boolean, ForeignKey, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductionSubOrder(Base, TimestampMixin):
    __tablename__ = "mes_order_sub_order"
    __table_args__ = (
        UniqueConstraint(
            "order_process_id",
            "operator_user_id",
            name="uq_mes_order_sub_order_order_process_id_operator_user_id",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
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
    assigned_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    completed_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending", index=True)
    is_visible: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=text("true"))

    order_process = relationship("ProductionOrderProcess", back_populates="sub_orders")
    operator = relationship("User")
    production_records = relationship("ProductionRecord", back_populates="sub_order")
    pipeline_instances = relationship(
        "OrderSubOrderPipelineInstance",
        back_populates="sub_order",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

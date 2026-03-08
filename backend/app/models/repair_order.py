from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class RepairOrder(Base, TimestampMixin):
    __tablename__ = "mes_repair_order"
    __table_args__ = (
        CheckConstraint("repair_quantity > 0", name="repair_quantity_positive"),
        CheckConstraint("repaired_quantity >= 0", name="repaired_quantity_non_negative"),
        CheckConstraint("scrap_quantity >= 0", name="scrap_quantity_non_negative"),
        CheckConstraint("status IN ('in_repair', 'completed')", name="status_allowed"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    repair_order_code: Mapped[str] = mapped_column(String(64), nullable=False, unique=True, index=True)
    source_order_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_order.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    source_order_code: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    product_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_product.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    product_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    source_order_process_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_order_process.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    source_process_code: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    source_process_name: Mapped[str] = mapped_column(String(128), nullable=False)
    sender_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    sender_username: Mapped[str | None] = mapped_column(String(128), nullable=True)
    production_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    repair_quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    repaired_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    scrap_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    scrap_replenished: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    repair_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="in_repair", index=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    repair_operator_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    repair_operator_username: Mapped[str | None] = mapped_column(String(128), nullable=True)

    source_order = relationship("ProductionOrder")
    product = relationship("Product")
    source_order_process = relationship("ProductionOrderProcess")
    sender_user = relationship("User", foreign_keys=[sender_user_id])
    repair_operator_user = relationship("User", foreign_keys=[repair_operator_user_id])
    defect_rows = relationship(
        "RepairDefectPhenomenon",
        back_populates="repair_order",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    cause_rows = relationship(
        "RepairCause",
        back_populates="repair_order",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    return_routes = relationship(
        "RepairReturnRoute",
        back_populates="repair_order",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class RepairDefectPhenomenon(Base, TimestampMixin):
    __tablename__ = "mes_repair_defect_phenomenon"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="quantity_positive"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    repair_order_id: Mapped[int] = mapped_column(
        ForeignKey("mes_repair_order.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    production_record_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_production_record.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    order_id: Mapped[int | None] = mapped_column(nullable=True, index=True)
    order_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    product_id: Mapped[int | None] = mapped_column(nullable=True, index=True)
    product_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    process_id: Mapped[int | None] = mapped_column(nullable=True, index=True)
    process_code: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    process_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    phenomenon: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    operator_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    operator_username: Mapped[str | None] = mapped_column(String(128), nullable=True)
    production_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)

    repair_order = relationship("RepairOrder", back_populates="defect_rows")
    operator_user = relationship("User")
    production_record = relationship("ProductionRecord")

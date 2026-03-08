from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class RepairCause(Base, TimestampMixin):
    __tablename__ = "mes_repair_cause"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="quantity_positive"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    repair_order_id: Mapped[int] = mapped_column(
        ForeignKey("mes_repair_order.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    order_id: Mapped[int | None] = mapped_column(nullable=True, index=True)
    order_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    product_id: Mapped[int | None] = mapped_column(nullable=True, index=True)
    product_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    process_id: Mapped[int | None] = mapped_column(nullable=True, index=True)
    process_code: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    process_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    phenomenon: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    reason: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    is_scrap: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
        index=True,
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    cause_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    operator_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    operator_username: Mapped[str | None] = mapped_column(String(128), nullable=True)

    repair_order = relationship("RepairOrder", back_populates="cause_rows")
    operator_user = relationship("User")

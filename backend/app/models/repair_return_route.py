from sqlalchemy import CheckConstraint, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class RepairReturnRoute(Base, TimestampMixin):
    __tablename__ = "mes_repair_return_route"
    __table_args__ = (
        CheckConstraint("return_quantity > 0", name="return_quantity_positive"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    repair_order_id: Mapped[int] = mapped_column(
        ForeignKey("mes_repair_order.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    source_order_id: Mapped[int | None] = mapped_column(nullable=True, index=True)
    source_process_id: Mapped[int | None] = mapped_column(nullable=True, index=True)
    source_process_code: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    source_process_name: Mapped[str] = mapped_column(String(128), nullable=False)
    target_process_id: Mapped[int | None] = mapped_column(nullable=True, index=True)
    target_process_code: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    target_process_name: Mapped[str] = mapped_column(String(128), nullable=False)
    return_quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    operator_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    operator_username: Mapped[str | None] = mapped_column(String(128), nullable=True)

    repair_order = relationship("RepairOrder", back_populates="return_routes")
    operator_user = relationship("User")

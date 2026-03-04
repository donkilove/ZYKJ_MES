from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductionRecord(Base, TimestampMixin):
    __tablename__ = "mes_production_record"

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
    sub_order_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_order_sub_order.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    operator_user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    production_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    record_type: Mapped[str] = mapped_column(String(32), nullable=False, default="production")

    order = relationship("ProductionOrder", back_populates="production_records")
    order_process = relationship("ProductionOrderProcess", back_populates="production_records")
    sub_order = relationship("ProductionSubOrder", back_populates="production_records")
    operator = relationship("User")

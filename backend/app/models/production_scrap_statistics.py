from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductionScrapStatistics(Base, TimestampMixin):
    __tablename__ = "mes_production_scrap_statistics"
    __table_args__ = (
        CheckConstraint("scrap_quantity > 0", name="scrap_quantity_positive"),
        CheckConstraint("progress IN ('pending_apply', 'applied')", name="progress_allowed"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    order_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_order.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    order_code: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    product_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_product.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    product_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    process_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_order_process.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    process_code: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    process_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    scrap_reason: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    scrap_quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    last_scrap_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    progress: Mapped[str] = mapped_column(String(32), nullable=False, default="pending_apply", index=True)
    applied_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    order = relationship("ProductionOrder")
    product = relationship("Product")
    process = relationship("ProductionOrderProcess")

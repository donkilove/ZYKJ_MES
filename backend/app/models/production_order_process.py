from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductionOrderProcess(Base, TimestampMixin):
    __tablename__ = "mes_order_process"
    __table_args__ = (
        UniqueConstraint("order_id", "process_order", name="uq_mes_order_process_order_id_process_order"),
        UniqueConstraint("order_id", "process_code", name="uq_mes_order_process_order_id_process_code"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    order_id: Mapped[int] = mapped_column(
        ForeignKey("mes_order.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    process_id: Mapped[int] = mapped_column(
        ForeignKey("mes_process.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    process_code: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    process_name: Mapped[str] = mapped_column(String(128), nullable=False)
    process_order: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending", index=True)
    visible_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    completed_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    order = relationship("ProductionOrder", back_populates="processes")
    process = relationship("Process")
    sub_orders = relationship(
        "ProductionSubOrder",
        back_populates="order_process",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    first_article_records = relationship(
        "FirstArticleRecord",
        back_populates="order_process",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    production_records = relationship(
        "ProductionRecord",
        back_populates="order_process",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

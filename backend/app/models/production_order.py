from datetime import date

from sqlalchemy import Boolean, Date, ForeignKey, Integer, String, Text, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductionOrder(Base, TimestampMixin):
    __tablename__ = "mes_order"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    order_code: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    product_id: Mapped[int] = mapped_column(ForeignKey("mes_product.id", ondelete="RESTRICT"), nullable=False)
    supplier_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_supplier.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    supplier_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    product_version: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending", index=True)
    current_process_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    remark: Mapped[str | None] = mapped_column(Text, nullable=True)
    process_template_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_product_process_template.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    process_template_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    process_template_version: Mapped[int | None] = mapped_column(Integer, nullable=True)
    pipeline_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    pipeline_process_codes: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default="",
        server_default=text("''"),
    )
    created_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    product = relationship("Product")
    supplier = relationship("Supplier", back_populates="orders")
    created_by = relationship("User")
    process_template = relationship("ProductProcessTemplate")
    processes = relationship(
        "ProductionOrderProcess",
        back_populates="order",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    first_article_records = relationship(
        "FirstArticleRecord",
        back_populates="order",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    production_records = relationship(
        "ProductionRecord",
        back_populates="order",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    event_logs = relationship(
        "OrderEventLog",
        back_populates="order",
        cascade="save-update, merge",
        passive_deletes=True,
    )
    pipeline_instances = relationship(
        "ProcessPipelineInstance",
        back_populates="order",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

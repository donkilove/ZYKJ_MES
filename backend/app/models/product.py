from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Product(Base, TimestampMixin):
    __tablename__ = "mes_product"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    category: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="",
        server_default=text("''"),
    )
    parameter_template_initialized: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    lifecycle_status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="active",
        server_default=text("'active'"),
        index=True,
    )
    current_version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        server_default=text("1"),
    )
    effective_version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default=text("0"),
    )
    effective_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    inactive_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    remark: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        default="",
        server_default=text("''"),
    )

    parameters = relationship(
        "ProductParameter",
        back_populates="product",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    parameter_histories = relationship(
        "ProductParameterHistory",
        back_populates="product",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    revisions = relationship(
        "ProductRevision",
        back_populates="product",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ProductRevision.version.desc()",
    )

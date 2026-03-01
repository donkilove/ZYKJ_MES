from sqlalchemy import Boolean, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Product(Base, TimestampMixin):
    __tablename__ = "mes_product"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    parameter_template_initialized: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
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

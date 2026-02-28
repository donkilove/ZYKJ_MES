from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Product(Base, TimestampMixin):
    __tablename__ = "mes_product"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)

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

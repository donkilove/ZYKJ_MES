from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductParameter(Base, TimestampMixin):
    __tablename__ = "mes_product_parameter"
    __table_args__ = (
        UniqueConstraint("product_id", "param_key", name="uq_mes_product_parameter_product_id_param_key"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    product_id: Mapped[int] = mapped_column(
        ForeignKey("mes_product.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    param_key: Mapped[str] = mapped_column(String(128), nullable=False)
    param_value: Mapped[str] = mapped_column(String(1024), nullable=False, default="")

    product = relationship("Product", back_populates="parameters")

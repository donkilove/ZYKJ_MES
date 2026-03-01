from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductParameter(Base, TimestampMixin):
    __tablename__ = "mes_product_parameter"
    __table_args__ = (
        UniqueConstraint("product_id", "param_key", name="uq_mes_product_parameter_product_id_param_key"),
        CheckConstraint("param_type IN ('Text', 'Link')", name="ck_mes_product_parameter_param_type_allowed"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    product_id: Mapped[int] = mapped_column(
        ForeignKey("mes_product.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    param_key: Mapped[str] = mapped_column(String(128), nullable=False)
    param_category: Mapped[str] = mapped_column(String(128), nullable=False, default="")
    param_type: Mapped[str] = mapped_column(String(16), nullable=False, default="Text")
    param_value: Mapped[str] = mapped_column(String(1024), nullable=False, default="")
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0, index=True)
    is_preset: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    product = relationship("Product", back_populates="parameters")

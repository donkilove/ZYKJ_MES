from sqlalchemy import JSON, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductParameterHistory(Base, TimestampMixin):
    __tablename__ = "mes_product_parameter_history"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    product_id: Mapped[int] = mapped_column(
        ForeignKey("mes_product.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    operator_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )
    operator_username: Mapped[str] = mapped_column(String(64), nullable=False)
    remark: Mapped[str] = mapped_column(String(512), nullable=False)
    changed_keys: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)

    product = relationship("Product", back_populates="parameter_histories")
    operator = relationship("User", foreign_keys=[operator_user_id])

from sqlalchemy import Boolean, ForeignKey, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductProcessTemplate(Base, TimestampMixin):
    __tablename__ = "mes_product_process_template"
    __table_args__ = (
        UniqueConstraint(
            "product_id",
            "template_name",
            "version",
            name="uq_mes_product_process_template_product_id_template_name_version",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    product_id: Mapped[int] = mapped_column(
        ForeignKey("mes_product.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    template_name: Mapped[str] = mapped_column(String(128), nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    is_default: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
        index=True,
    )
    is_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
        index=True,
    )
    created_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    updated_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    product = relationship("Product")
    created_by = relationship("User", foreign_keys=[created_by_user_id])
    updated_by = relationship("User", foreign_keys=[updated_by_user_id])
    steps = relationship(
        "ProductProcessTemplateStep",
        back_populates="template",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ProductProcessTemplateStep.step_order.asc()",
    )

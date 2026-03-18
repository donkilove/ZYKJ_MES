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
            name="uq_mes_pp_template_pid_tname_ver",
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
    lifecycle_status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="draft",
        server_default=text("'draft'"),
        index=True,
    )
    published_version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default=text("0"),
    )
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
    remark: Mapped[str] = mapped_column(String(500), nullable=False, default="", server_default=text("''"))
    source_type: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="manual",
        server_default=text("'manual'"),
    )
    source_template_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_product_process_template.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    source_template_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    source_template_version: Mapped[int | None] = mapped_column(Integer, nullable=True)
    source_product_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_product.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    source_system_master_version: Mapped[int | None] = mapped_column(Integer, nullable=True)

    product = relationship("Product", foreign_keys=[product_id])
    source_template = relationship("ProductProcessTemplate", remote_side=[id])
    source_product = relationship("Product", foreign_keys=[source_product_id])
    created_by = relationship("User", foreign_keys=[created_by_user_id])
    updated_by = relationship("User", foreign_keys=[updated_by_user_id])
    steps = relationship(
        "ProductProcessTemplateStep",
        back_populates="template",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ProductProcessTemplateStep.step_order.asc()",
    )
    revisions = relationship(
        "ProductProcessTemplateRevision",
        back_populates="template",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ProductProcessTemplateRevision.version.desc()",
    )

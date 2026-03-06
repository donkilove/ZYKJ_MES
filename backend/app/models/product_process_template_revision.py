from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductProcessTemplateRevision(Base, TimestampMixin):
    __tablename__ = "mes_product_process_template_revision"
    __table_args__ = (
        UniqueConstraint(
            "template_id",
            "version",
            name="uq_mes_product_process_template_revision_template_id_version",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    template_id: Mapped[int] = mapped_column(
        ForeignKey("mes_product_process_template.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    action: Mapped[str] = mapped_column(String(32), nullable=False, default="publish")
    note: Mapped[str | None] = mapped_column(String(256), nullable=True)
    source_revision_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_product_process_template_revision.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    created_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    template = relationship("ProductProcessTemplate", back_populates="revisions")
    source_revision = relationship("ProductProcessTemplateRevision", remote_side=[id])
    created_by = relationship("User")
    steps = relationship(
        "ProductProcessTemplateRevisionStep",
        back_populates="revision",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ProductProcessTemplateRevisionStep.step_order.asc()",
    )

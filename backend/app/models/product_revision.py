from sqlalchemy import ForeignKey, Integer, String, Text, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.product_revision_parameter import ProductRevisionParameter


class ProductRevision(Base, TimestampMixin):
    __tablename__ = "mes_product_revision"
    __table_args__ = (
        UniqueConstraint(
            "product_id",
            "version",
            name="uq_mes_product_revision_product_id_version",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    product_id: Mapped[int] = mapped_column(
        ForeignKey("mes_product.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    version_label: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="V1.0",
        server_default=text("'V1.0'"),
    )
    lifecycle_status: Mapped[str] = mapped_column(String(32), nullable=False)
    action: Mapped[str] = mapped_column(String(32), nullable=False, default="snapshot")
    note: Mapped[str | None] = mapped_column(String(256), nullable=True)
    source_revision_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_product_revision.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    snapshot_json: Mapped[str] = mapped_column(Text, nullable=False)
    created_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    product = relationship("Product", back_populates="revisions")
    source_revision = relationship("ProductRevision", remote_side=[id])
    created_by = relationship("User")
    parameters = relationship(
        "ProductRevisionParameter",
        back_populates="revision",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by=ProductRevisionParameter.sort_order.asc(),
    )

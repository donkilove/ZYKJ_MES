from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class CraftSystemMasterTemplateRevision(Base, TimestampMixin):
    __tablename__ = "sys_craft_system_master_template_revision"
    __table_args__ = (
        UniqueConstraint(
            "template_id",
            "version",
            name="uq_sys_craft_smtr_template_id_version",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    template_id: Mapped[int] = mapped_column(
        ForeignKey("sys_craft_system_master_template.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    action: Mapped[str] = mapped_column(String(32), nullable=False, default="update")
    note: Mapped[str | None] = mapped_column(String(256), nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    template = relationship("CraftSystemMasterTemplate", back_populates="revisions")
    created_by = relationship("User")
    steps = relationship(
        "CraftSystemMasterTemplateRevisionStep",
        back_populates="revision",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="CraftSystemMasterTemplateRevisionStep.step_order.asc()",
    )

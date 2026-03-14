from sqlalchemy import CheckConstraint, ForeignKey, Integer, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class CraftSystemMasterTemplate(Base, TimestampMixin):
    __tablename__ = "sys_craft_system_master_template"
    __table_args__ = (
        CheckConstraint("id = 1", name="singleton_id_eq_1"),
    )

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
        nullable=False,
        default=1,
        server_default=text("1"),
    )
    version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        server_default=text("1"),
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

    created_by = relationship("User", foreign_keys=[created_by_user_id])
    updated_by = relationship("User", foreign_keys=[updated_by_user_id])
    steps = relationship(
        "CraftSystemMasterTemplateStep",
        back_populates="template",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="CraftSystemMasterTemplateStep.step_order.asc()",
    )
    revisions = relationship(
        "CraftSystemMasterTemplateRevision",
        back_populates="template",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="CraftSystemMasterTemplateRevision.version.desc()",
    )

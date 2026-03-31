from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class CraftSystemMasterTemplateStep(Base, TimestampMixin):
    __tablename__ = "sys_craft_system_master_template_step"
    __table_args__ = (
        UniqueConstraint(
            "template_id",
            "step_order",
            name="uq_sys_craft_system_master_template_step_template_id_step_order",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    template_id: Mapped[int] = mapped_column(
        ForeignKey("sys_craft_system_master_template.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    step_order: Mapped[int] = mapped_column(Integer, nullable=False)
    stage_id: Mapped[int] = mapped_column(
        ForeignKey("mes_process_stage.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    stage_code: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    stage_name: Mapped[str] = mapped_column(String(128), nullable=False)
    process_id: Mapped[int] = mapped_column(
        ForeignKey("mes_process.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    process_code: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    process_name: Mapped[str] = mapped_column(String(128), nullable=False)
    template = relationship("CraftSystemMasterTemplate", back_populates="steps")
    stage = relationship("ProcessStage")
    process = relationship("Process")

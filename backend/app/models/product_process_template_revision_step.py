from sqlalchemy import Boolean, ForeignKey, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProductProcessTemplateRevisionStep(Base, TimestampMixin):
    __tablename__ = "mes_product_process_template_revision_step"
    __table_args__ = (
        UniqueConstraint(
            "revision_id",
            "step_order",
            name="uq_ppt_rev_step_revision_id_step_order",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    revision_id: Mapped[int] = mapped_column(
        ForeignKey("mes_product_process_template_revision.id", ondelete="CASCADE"),
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
    standard_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default=text("0"))
    is_key_process: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default=text("false"))
    step_remark: Mapped[str] = mapped_column(String(500), nullable=False, default="", server_default=text("''"))
    revision = relationship("ProductProcessTemplateRevision", back_populates="steps")
    stage = relationship("ProcessStage")
    process = relationship("Process")

from sqlalchemy import Boolean, ForeignKey, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.associations import user_processes
from app.models.base import Base, TimestampMixin


class Process(Base, TimestampMixin):
    __tablename__ = "mes_process"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    code: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    stage_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_process_stage.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    is_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
        index=True,
    )
    remark: Mapped[str] = mapped_column(String(500), nullable=False, default="", server_default=text("''"))

    users = relationship("User", secondary=user_processes, back_populates="processes")
    stage = relationship("ProcessStage", back_populates="processes")

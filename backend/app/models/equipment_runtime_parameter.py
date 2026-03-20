from sqlalchemy import Boolean, DateTime, ForeignKey, Numeric, String, Text, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class EquipmentRuntimeParameter(Base, TimestampMixin):
    __tablename__ = "mes_equipment_runtime_parameter"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    equipment_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_equipment.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    equipment_type: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    equipment_code: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    equipment_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    param_code: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    param_name: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    unit: Mapped[str] = mapped_column(String(32), nullable=False, default="")
    standard_value: Mapped[object] = mapped_column(Numeric(18, 4), nullable=True)
    upper_limit: Mapped[object] = mapped_column(Numeric(18, 4), nullable=True)
    lower_limit: Mapped[object] = mapped_column(Numeric(18, 4), nullable=True)
    effective_at: Mapped[object] = mapped_column(DateTime(timezone=True), nullable=True)
    is_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
        index=True,
    )
    remark: Mapped[str] = mapped_column(Text, nullable=False, default="")

    equipment = relationship("Equipment")

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class EquipmentRule(Base, TimestampMixin):
    __tablename__ = "mes_equipment_rule"
    __table_args__ = (
        UniqueConstraint("rule_code", name="uq_mes_equipment_rule_rule_code"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    equipment_id: Mapped[int | None] = mapped_column(
        ForeignKey("mes_equipment.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    equipment_type: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    equipment_code: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    equipment_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    rule_code: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    rule_name: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    rule_type: Mapped[str] = mapped_column(String(64), nullable=False, default="", index=True)
    condition_desc: Mapped[str] = mapped_column(Text, nullable=False, default="")
    is_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
        index=True,
    )
    effective_at: Mapped[object] = mapped_column(DateTime(timezone=True), nullable=True)
    remark: Mapped[str] = mapped_column(Text, nullable=False, default="")

    equipment = relationship("Equipment")

from datetime import date

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class MaintenancePlan(Base, TimestampMixin):
    __tablename__ = "mes_maintenance_plan"
    __table_args__ = (
        UniqueConstraint(
            "equipment_id",
            "item_id",
            name="uq_mes_maintenance_plan_equipment_id_item_id",
        ),
        CheckConstraint("cycle_days > 0", name="ck_mes_maintenance_plan_cycle_days_positive"),
        CheckConstraint(
            "estimated_duration_minutes IS NULL OR estimated_duration_minutes > 0",
            name="ck_mes_maintenance_plan_duration_positive",
        ),
        CheckConstraint(
            "execution_process_code IN ('laser_marking', 'product_testing', 'product_assembly', 'product_packaging')",
            name="ck_mes_maintenance_plan_execution_process_code_allowed",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    equipment_id: Mapped[int] = mapped_column(
        ForeignKey("mes_equipment.id", ondelete="RESTRICT"),
        index=True,
        nullable=False,
    )
    item_id: Mapped[int] = mapped_column(
        ForeignKey("mes_maintenance_item.id", ondelete="RESTRICT"),
        index=True,
        nullable=False,
    )
    cycle_days: Mapped[int] = mapped_column(Integer, nullable=False, default=30)
    execution_process_code: Mapped[str] = mapped_column(
        String(64),
        index=True,
        nullable=False,
        default="laser_marking",
        server_default=text("'laser_marking'"),
    )
    estimated_duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    next_due_date: Mapped[date] = mapped_column(Date, nullable=False)
    default_executor_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )
    is_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )

    equipment = relationship("Equipment", back_populates="plans")
    item = relationship("MaintenanceItem", back_populates="plans")
    default_executor = relationship("User", foreign_keys=[default_executor_user_id])
    work_orders = relationship("MaintenanceWorkOrder", back_populates="plan")

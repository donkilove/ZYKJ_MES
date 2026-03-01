from datetime import date, datetime

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class MaintenanceWorkOrder(Base, TimestampMixin):
    __tablename__ = "mes_maintenance_work_order"
    __table_args__ = (
        UniqueConstraint(
            "plan_id",
            "due_date",
            name="uq_mes_maintenance_work_order_plan_id_due_date",
        ),
        CheckConstraint(
            "status IN ('pending', 'in_progress', 'done', 'overdue', 'cancelled')",
            name="ck_mes_maintenance_work_order_status_allowed",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    plan_id: Mapped[int] = mapped_column(
        ForeignKey("mes_maintenance_plan.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
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
    due_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    status: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="pending",
        server_default=text("'pending'"),
        index=True,
    )
    executor_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    result_summary: Mapped[str | None] = mapped_column(String(255), nullable=True)
    result_remark: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    attachment_link: Mapped[str | None] = mapped_column(String(1024), nullable=True)

    plan = relationship("MaintenancePlan", back_populates="work_orders")
    equipment = relationship("Equipment", back_populates="work_orders")
    item = relationship("MaintenanceItem", back_populates="work_orders")
    executor = relationship("User", foreign_keys=[executor_user_id])

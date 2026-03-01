from datetime import date, datetime

from sqlalchemy import Date, DateTime, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class MaintenanceRecord(Base, TimestampMixin):
    __tablename__ = "mes_maintenance_record"
    __table_args__ = (
        UniqueConstraint("work_order_id", name="uq_mes_maintenance_record_work_order_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    work_order_id: Mapped[int] = mapped_column(index=True, nullable=False)

    source_plan_id: Mapped[int | None] = mapped_column(index=True, nullable=True)
    source_plan_cycle_days: Mapped[int | None] = mapped_column(nullable=True)
    source_plan_start_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    source_equipment_id: Mapped[int | None] = mapped_column(index=True, nullable=True)
    source_equipment_code: Mapped[str] = mapped_column(String(64), nullable=False, default="")
    source_equipment_name: Mapped[str] = mapped_column(String(128), nullable=False, default="")

    source_item_id: Mapped[int | None] = mapped_column(index=True, nullable=True)
    source_item_name: Mapped[str] = mapped_column(String(128), nullable=False, default="")

    due_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)

    executor_user_id: Mapped[int | None] = mapped_column(index=True, nullable=True)
    executor_username: Mapped[str] = mapped_column(String(64), nullable=False, default="")

    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    result_summary: Mapped[str] = mapped_column(String(255), nullable=False)
    result_remark: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    attachment_link: Mapped[str | None] = mapped_column(String(1024), nullable=True)

from sqlalchemy import Boolean, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class MaintenanceItem(Base, TimestampMixin):
    __tablename__ = "mes_maintenance_item"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    category: Mapped[str] = mapped_column(String(64), nullable=False, default="")
    default_cycle_days: Mapped[int] = mapped_column(Integer, nullable=False, default=30)
    default_duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=60)
    is_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )

    plans = relationship("MaintenancePlan", back_populates="item")
    work_orders = relationship("MaintenanceWorkOrder", back_populates="item")

from sqlalchemy import Boolean, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Equipment(Base, TimestampMixin):
    __tablename__ = "mes_equipment"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    model: Mapped[str] = mapped_column(String(128), nullable=False, default="")
    location: Mapped[str] = mapped_column(String(255), nullable=False, default="")
    owner_name: Mapped[str] = mapped_column(String(64), nullable=False, default="")
    is_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )

    plans = relationship("MaintenancePlan", back_populates="equipment")
    work_orders = relationship("MaintenanceWorkOrder", back_populates="equipment")

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class OrderEventLog(Base, TimestampMixin):
    __tablename__ = "mes_order_event_log"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    order_id: Mapped[int] = mapped_column(
        ForeignKey("mes_order.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    order_code_snapshot: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    order_status_snapshot: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    product_name_snapshot: Mapped[str | None] = mapped_column(String(128), nullable=True)
    process_code_snapshot: Mapped[str | None] = mapped_column(String(64), nullable=True)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    event_title: Mapped[str] = mapped_column(String(255), nullable=False)
    event_detail: Mapped[str | None] = mapped_column(Text, nullable=True)
    operator_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    payload_json: Mapped[str | None] = mapped_column(Text, nullable=True)

    order = relationship("ProductionOrder", back_populates="event_logs")
    operator = relationship("User")

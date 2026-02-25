from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.associations import user_processes
from app.models.base import Base, TimestampMixin


class Process(Base, TimestampMixin):
    __tablename__ = "mes_process"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    code: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)

    users = relationship("User", secondary=user_processes, back_populates="processes")


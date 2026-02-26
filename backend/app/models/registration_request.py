from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class RegistrationRequest(Base, TimestampMixin):
    __tablename__ = "sys_registration_request"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    account: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.associations import role_permissions
from app.models.base import Base, TimestampMixin


class Permission(Base, TimestampMixin):
    __tablename__ = "sys_permission"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    code: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(128), nullable=False)

    roles = relationship("Role", secondary=role_permissions, back_populates="permissions")


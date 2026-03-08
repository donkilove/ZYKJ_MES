from sqlalchemy import Boolean, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class PermissionCatalog(Base, TimestampMixin):
    __tablename__ = "sys_permission_catalog"
    __table_args__ = (
        UniqueConstraint("permission_code", name="uq_sys_permission_catalog_permission_code"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    permission_code: Mapped[str] = mapped_column(String(128), index=True, nullable=False)
    permission_name: Mapped[str] = mapped_column(String(128), nullable=False)
    module_code: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    resource_type: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    parent_permission_code: Mapped[str | None] = mapped_column(String(128), nullable=True)
    is_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

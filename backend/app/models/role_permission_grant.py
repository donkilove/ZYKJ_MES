from sqlalchemy import Boolean, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class RolePermissionGrant(Base, TimestampMixin):
    __tablename__ = "sys_role_permission_grant"
    __table_args__ = (
        UniqueConstraint("role_code", "permission_code", name="uq_sys_role_permission_grant_role_code_permission_code"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    role_code: Mapped[str] = mapped_column(String(64), ForeignKey("sys_role.code", ondelete="CASCADE"), index=True, nullable=False)
    permission_code: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("sys_permission_catalog.permission_code", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    granted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class AuthzModuleRevision(Base, TimestampMixin):
    __tablename__ = "sys_authz_module_revision"
    __table_args__ = (
        UniqueConstraint("module_code", name="uq_sys_authz_module_revision_module_code"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    module_code: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
    )

from sqlalchemy import JSON, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class AuthzChangeLog(Base, TimestampMixin):
    __tablename__ = "sys_authz_change_log"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    module_code: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    change_type: Mapped[str] = mapped_column(String(32), nullable=False, default="apply")
    remark: Mapped[str | None] = mapped_column(Text, nullable=True)
    operator_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )
    operator_username: Mapped[str | None] = mapped_column(String(64), nullable=True)
    rollback_of_change_log_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_authz_change_log.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )
    snapshot_json: Mapped[list[dict[str, object]]] = mapped_column(JSON, nullable=False, default=list)


class AuthzChangeLogItem(Base, TimestampMixin):
    __tablename__ = "sys_authz_change_log_item"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    change_log_id: Mapped[int] = mapped_column(
        ForeignKey("sys_authz_change_log.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    role_code: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    role_name: Mapped[str] = mapped_column(String(128), nullable=False)
    readonly: Mapped[bool] = mapped_column(nullable=False, default=False)
    before_capability_codes: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    after_capability_codes: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    added_capability_codes: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    removed_capability_codes: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    auto_linked_dependencies: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    effective_capability_codes: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    effective_page_permission_codes: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    updated_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

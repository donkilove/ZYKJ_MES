from sqlalchemy import Boolean, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class PageVisibility(Base, TimestampMixin):
    __tablename__ = "sys_page_visibility"
    __table_args__ = (
        UniqueConstraint("page_code", "role_code", name="uq_sys_page_visibility_page_code_role_code"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    page_code: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    role_code: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    is_visible: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

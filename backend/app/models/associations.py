from sqlalchemy import Column, ForeignKey, Table

from app.models.base import Base


user_roles = Table(
    "sys_user_role",
    Base.metadata,
    Column("user_id", ForeignKey("sys_user.id", ondelete="CASCADE"), primary_key=True),
    Column("role_id", ForeignKey("sys_role.id", ondelete="CASCADE"), primary_key=True),
)


user_processes = Table(
    "sys_user_process",
    Base.metadata,
    Column("user_id", ForeignKey("sys_user.id", ondelete="CASCADE"), primary_key=True),
    Column("process_id", ForeignKey("mes_process.id", ondelete="CASCADE"), primary_key=True),
)

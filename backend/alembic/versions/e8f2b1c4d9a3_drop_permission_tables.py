"""drop permission tables

Revision ID: e8f2b1c4d9a3
Revises: d4e7a6b9c1f2
Create Date: 2026-02-26 20:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "e8f2b1c4d9a3"
down_revision: Union[str, Sequence[str], None] = "d4e7a6b9c1f2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_table("sys_role_permission")
    op.drop_index(op.f("ix_sys_permission_code"), table_name="sys_permission")
    op.drop_index(op.f("ix_sys_permission_id"), table_name="sys_permission")
    op.drop_table("sys_permission")


def downgrade() -> None:
    """Downgrade schema."""
    op.create_table(
        "sys_permission",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_permission")),
    )
    op.create_index(op.f("ix_sys_permission_code"), "sys_permission", ["code"], unique=True)
    op.create_index(op.f("ix_sys_permission_id"), "sys_permission", ["id"], unique=False)
    op.create_table(
        "sys_role_permission",
        sa.Column("role_id", sa.Integer(), nullable=False),
        sa.Column("permission_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["permission_id"],
            ["sys_permission.id"],
            name=op.f("fk_sys_role_permission_permission_id_sys_permission"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["role_id"],
            ["sys_role.id"],
            name=op.f("fk_sys_role_permission_role_id_sys_role"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("role_id", "permission_id", name=op.f("pk_sys_role_permission")),
    )

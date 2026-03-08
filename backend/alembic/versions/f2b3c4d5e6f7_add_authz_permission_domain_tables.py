"""add authz permission domain tables

Revision ID: f2b3c4d5e6f7
Revises: e1b2c3d4f5a6
Create Date: 2026-03-08 23:55:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f2b3c4d5e6f7"
down_revision: Union[str, Sequence[str], None] = "e1b2c3d4f5a6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "sys_permission_catalog",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("permission_code", sa.String(length=128), nullable=False),
        sa.Column("permission_name", sa.String(length=128), nullable=False),
        sa.Column("module_code", sa.String(length=64), nullable=False),
        sa.Column("resource_type", sa.String(length=32), nullable=False),
        sa.Column("parent_permission_code", sa.String(length=128), nullable=True),
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_permission_catalog")),
        sa.UniqueConstraint("permission_code", name="uq_sys_permission_catalog_permission_code"),
    )
    op.create_index(op.f("ix_sys_permission_catalog_id"), "sys_permission_catalog", ["id"], unique=False)
    op.create_index(
        op.f("ix_sys_permission_catalog_permission_code"),
        "sys_permission_catalog",
        ["permission_code"],
        unique=False,
    )
    op.create_index(op.f("ix_sys_permission_catalog_module_code"), "sys_permission_catalog", ["module_code"], unique=False)
    op.create_index(
        op.f("ix_sys_permission_catalog_resource_type"),
        "sys_permission_catalog",
        ["resource_type"],
        unique=False,
    )

    op.create_table(
        "sys_role_permission_grant",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("role_code", sa.String(length=64), nullable=False),
        sa.Column("permission_code", sa.String(length=128), nullable=False),
        sa.Column("granted", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["permission_code"],
            ["sys_permission_catalog.permission_code"],
            name=op.f("fk_sys_role_permission_grant_permission_code_sys_permission_catalog"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["role_code"],
            ["sys_role.code"],
            name=op.f("fk_sys_role_permission_grant_role_code_sys_role"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_role_permission_grant")),
        sa.UniqueConstraint(
            "role_code",
            "permission_code",
            name="uq_sys_role_permission_grant_role_code_permission_code",
        ),
    )
    op.create_index(op.f("ix_sys_role_permission_grant_id"), "sys_role_permission_grant", ["id"], unique=False)
    op.create_index(
        op.f("ix_sys_role_permission_grant_role_code"),
        "sys_role_permission_grant",
        ["role_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_role_permission_grant_permission_code"),
        "sys_role_permission_grant",
        ["permission_code"],
        unique=False,
    )

def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_sys_role_permission_grant_permission_code"), table_name="sys_role_permission_grant")
    op.drop_index(op.f("ix_sys_role_permission_grant_role_code"), table_name="sys_role_permission_grant")
    op.drop_index(op.f("ix_sys_role_permission_grant_id"), table_name="sys_role_permission_grant")
    op.drop_table("sys_role_permission_grant")

    op.drop_index(op.f("ix_sys_permission_catalog_resource_type"), table_name="sys_permission_catalog")
    op.drop_index(op.f("ix_sys_permission_catalog_module_code"), table_name="sys_permission_catalog")
    op.drop_index(op.f("ix_sys_permission_catalog_permission_code"), table_name="sys_permission_catalog")
    op.drop_index(op.f("ix_sys_permission_catalog_id"), table_name="sys_permission_catalog")
    op.drop_table("sys_permission_catalog")

"""add authz module revision table

Revision ID: a1c3e5f7b9d2
Revises: f2b3c4d5e6f7
Create Date: 2026-03-09 14:20:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "a1c3e5f7b9d2"
down_revision: Union[str, Sequence[str], None] = "f2b3c4d5e6f7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "sys_authz_module_revision",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("module_code", sa.String(length=64), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("updated_by_user_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["updated_by_user_id"],
            ["sys_user.id"],
            name=op.f("fk_sys_authz_module_revision_updated_by_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_authz_module_revision")),
        sa.UniqueConstraint("module_code", name="uq_sys_authz_module_revision_module_code"),
    )
    op.create_index(
        op.f("ix_sys_authz_module_revision_id"),
        "sys_authz_module_revision",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_authz_module_revision_module_code"),
        "sys_authz_module_revision",
        ["module_code"],
        unique=False,
    )

    revision_table = sa.table(
        "sys_authz_module_revision",
        sa.column("module_code", sa.String(length=64)),
        sa.column("revision", sa.Integer()),
    )
    op.bulk_insert(
        revision_table,
        [
            {"module_code": "system", "revision": 0},
            {"module_code": "user", "revision": 0},
            {"module_code": "product", "revision": 0},
            {"module_code": "equipment", "revision": 0},
            {"module_code": "craft", "revision": 0},
            {"module_code": "quality", "revision": 0},
            {"module_code": "production", "revision": 0},
        ],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_sys_authz_module_revision_module_code"), table_name="sys_authz_module_revision")
    op.drop_index(op.f("ix_sys_authz_module_revision_id"), table_name="sys_authz_module_revision")
    op.drop_table("sys_authz_module_revision")

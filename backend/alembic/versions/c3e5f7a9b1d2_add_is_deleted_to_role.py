"""add is_deleted to sys_role

Revision ID: c3e5f7a9b1d2
Revises: b2c3d4e5f6a7
Create Date: 2026-03-13 22:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c3e5f7a9b1d2"
down_revision: Union[str, None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "sys_role",
        sa.Column(
            "is_deleted",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.create_index("ix_sys_role_is_deleted", "sys_role", ["is_deleted"])


def downgrade() -> None:
    op.drop_index("ix_sys_role_is_deleted", table_name="sys_role")
    op.drop_column("sys_role", "is_deleted")

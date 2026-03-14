"""add change_type to product parameter history

Revision ID: g7b8c9d0e1f2
Revises: f6a7b8c9d0e1
Create Date: 2026-03-14 14:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "g7b8c9d0e1f2"
down_revision: Union[str, None] = "f6a7b8c9d0e1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "mes_product_parameter_history",
        sa.Column(
            "change_type",
            sa.String(32),
            nullable=False,
            server_default=sa.text("'edit'"),
        ),
    )
    op.create_index(
        "ix_mes_product_parameter_history_change_type",
        "mes_product_parameter_history",
        ["change_type"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_mes_product_parameter_history_change_type",
        table_name="mes_product_parameter_history",
    )
    op.drop_column("mes_product_parameter_history", "change_type")

"""add process multi device production flag

Revision ID: e6f7a8b9c0d1
Revises: c1d2e3f4a5b6
Create Date: 2026-05-13 00:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "e6f7a8b9c0d1"
down_revision: Union[str, Sequence[str], None] = "c1d2e3f4a5b6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "mes_process",
        sa.Column(
            "allow_multi_device_production",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("mes_process", "allow_multi_device_production")

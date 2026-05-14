"""add process first article presets

Revision ID: c1d2e3f4a5b6
Revises: a1b9c3d5e7f9, ea6e7fdc381a
Create Date: 2026-05-13 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "c1d2e3f4a5b6"
down_revision: Union[str, Sequence[str], None] = (
    "a1b9c3d5e7f9",
    "ea6e7fdc381a",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "mes_process",
        sa.Column(
            "first_article_check_content",
            sa.Text(),
            nullable=False,
            server_default=sa.text("''"),
        ),
    )
    op.add_column(
        "mes_process",
        sa.Column(
            "first_article_test_value",
            sa.Text(),
            nullable=False,
            server_default=sa.text("''"),
        ),
    )


def downgrade() -> None:
    op.drop_column("mes_process", "first_article_test_value")
    op.drop_column("mes_process", "first_article_check_content")

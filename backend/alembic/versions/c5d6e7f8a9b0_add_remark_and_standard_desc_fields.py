"""add remark to equipment and standard_description to maintenance_item

Revision ID: c5d6e7f8a9b0
Revises: f94b1c2d3e45
Create Date: 2026-03-14 10:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "c5d6e7f8a9b0"
down_revision: Union[str, Sequence[str], None] = "f94b1c2d3e45"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "mes_equipment",
        sa.Column("remark", sa.Text(), nullable=False, server_default=""),
    )
    op.add_column(
        "mes_maintenance_item",
        sa.Column("standard_description", sa.Text(), nullable=False, server_default=""),
    )


def downgrade() -> None:
    op.drop_column("mes_equipment", "remark")
    op.drop_column("mes_maintenance_item", "standard_description")

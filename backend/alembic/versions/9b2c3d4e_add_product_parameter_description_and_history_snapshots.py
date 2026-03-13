"""add product parameter description and history snapshots

Revision ID: 9b2c3d4e
Revises: 8a1b2c3d
Create Date: 2026-03-13 14:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "9b2c3d4e"
down_revision: Union[str, Sequence[str], None] = "8a1b2c3d"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add param_description to mes_product_parameter and before/after snapshots to mes_product_parameter_history."""
    op.add_column(
        "mes_product_parameter",
        sa.Column(
            "param_description",
            sa.String(length=500),
            nullable=False,
            server_default=sa.text("''"),
        ),
    )
    op.add_column(
        "mes_product_parameter_history",
        sa.Column(
            "before_snapshot",
            sa.Text(),
            nullable=False,
            server_default=sa.text("'{}'"),
        ),
    )
    op.add_column(
        "mes_product_parameter_history",
        sa.Column(
            "after_snapshot",
            sa.Text(),
            nullable=False,
            server_default=sa.text("'{}'"),
        ),
    )


def downgrade() -> None:
    """Remove added columns."""
    op.drop_column("mes_product_parameter_history", "after_snapshot")
    op.drop_column("mes_product_parameter_history", "before_snapshot")
    op.drop_column("mes_product_parameter", "param_description")

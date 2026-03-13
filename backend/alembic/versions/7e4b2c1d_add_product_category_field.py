"""add product category field

Revision ID: 7e4b2c1d
Revises: f3d4e5a6b7c8
Create Date: 2026-03-13 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "7e4b2c1d"
down_revision: Union[str, Sequence[str], None] = "f3d4e5a6b7c8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "mes_product",
        sa.Column(
            "category",
            sa.String(length=32),
            nullable=False,
            server_default=sa.text("''"),
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("mes_product", "category")

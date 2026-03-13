"""narrow product lifecycle statuses

Revision ID: 8a1b2c3d
Revises: 7e4b2c1d
Create Date: 2026-03-13 12:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "8a1b2c3d"
down_revision: Union[str, Sequence[str], None] = "7e4b2c1d"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        sa.text(
            """
            UPDATE mes_product
            SET lifecycle_status = CASE
                WHEN lifecycle_status = 'inactive' THEN 'inactive'
                ELSE 'active'
            END
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE mes_product_revision
            SET lifecycle_status = CASE
                WHEN lifecycle_status = 'effective' THEN 'effective'
                WHEN lifecycle_status = 'inactive' THEN 'inactive'
                ELSE 'draft'
            END
            """
        )
    )
    op.alter_column(
        "mes_product",
        "lifecycle_status",
        existing_type=sa.String(length=32),
        existing_nullable=False,
        server_default=sa.text("'active'"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        sa.text(
            """
            UPDATE mes_product
            SET lifecycle_status = 'effective'
            WHERE lifecycle_status = 'active'
            """
        )
    )
    op.alter_column(
        "mes_product",
        "lifecycle_status",
        existing_type=sa.String(length=32),
        existing_nullable=False,
        server_default=sa.text("'draft'"),
    )

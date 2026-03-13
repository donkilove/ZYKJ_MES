"""add version_label to product revision

Revision ID: a1b2c3d4e5f6
Revises: 9b2c3d4e
Create Date: 2026-03-13 16:00:00.000000

"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "9b2c3d4e"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add version_label column to mes_product_revision and backfill."""
    op.add_column(
        "mes_product_revision",
        sa.Column(
            "version_label",
            sa.String(length=32),
            nullable=False,
            server_default=sa.text("'V1.0'"),
        ),
    )

    # Backfill: assign version labels based on per-product version ordering.
    # For each product, sort revisions by version asc and assign V1.0, V1.1, V1.2, ...
    conn = op.get_bind()
    product_ids = [
        row[0]
        for row in conn.execute(
            sa.text("SELECT DISTINCT product_id FROM mes_product_revision ORDER BY product_id ASC")
        ).fetchall()
    ]
    for product_id in product_ids:
        rows = conn.execute(
            sa.text(
                "SELECT id, version FROM mes_product_revision "
                "WHERE product_id = :pid ORDER BY version ASC, id ASC"
            ),
            {"pid": product_id},
        ).fetchall()
        for index, (rev_id, _version) in enumerate(rows):
            label = f"V1.{index}"
            conn.execute(
                sa.text(
                    "UPDATE mes_product_revision SET version_label = :label WHERE id = :rid"
                ),
                {"label": label, "rid": rev_id},
            )


def downgrade() -> None:
    """Remove version_label column."""
    op.drop_column("mes_product_revision", "version_label")

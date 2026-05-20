"""add repair return to production status

Revision ID: f7a8b9c0d1e2
Revises: e6f7a8b9c0d1
Create Date: 2026-05-14 00:00:00.000000

"""

from collections.abc import Sequence

from alembic import op


revision: str = "f7a8b9c0d1e2"
down_revision: str | Sequence[str] | None = "e6f7a8b9c0d1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("mes_repair_order") as batch_op:
        batch_op.drop_constraint("ck_mes_repair_order_status_allowed", type_="check")
        batch_op.create_check_constraint(
            "ck_mes_repair_order_status_allowed",
            "status IN ('in_repair', 'completed', 'returned_to_production')",
        )


def downgrade() -> None:
    op.execute(
        "UPDATE mes_repair_order "
        "SET status = 'in_repair', completed_at = NULL "
        "WHERE status = 'returned_to_production'"
    )
    with op.batch_alter_table("mes_repair_order") as batch_op:
        batch_op.drop_constraint("ck_mes_repair_order_status_allowed", type_="check")
        batch_op.create_check_constraint(
            "ck_mes_repair_order_status_allowed",
            "status IN ('in_repair', 'completed')",
        )

"""make work order plan nullable set null

Revision ID: 9c2a4d6e8f11
Revises: 1f4c2e6a9b10
Create Date: 2026-03-02 00:20:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "9c2a4d6e8f11"
down_revision: Union[str, Sequence[str], None] = "1f4c2e6a9b10"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(
        op.f("fk_mes_maintenance_work_order_plan_id_mes_maintenance_plan"),
        "mes_maintenance_work_order",
        type_="foreignkey",
    )
    op.alter_column(
        "mes_maintenance_work_order",
        "plan_id",
        existing_type=sa.Integer(),
        nullable=True,
    )
    op.create_foreign_key(
        op.f("fk_mes_maintenance_work_order_plan_id_mes_maintenance_plan"),
        "mes_maintenance_work_order",
        "mes_maintenance_plan",
        ["plan_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        op.f("fk_mes_maintenance_work_order_plan_id_mes_maintenance_plan"),
        "mes_maintenance_work_order",
        type_="foreignkey",
    )
    op.execute("DELETE FROM mes_maintenance_work_order WHERE plan_id IS NULL")
    op.alter_column(
        "mes_maintenance_work_order",
        "plan_id",
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.create_foreign_key(
        op.f("fk_mes_maintenance_work_order_plan_id_mes_maintenance_plan"),
        "mes_maintenance_work_order",
        "mes_maintenance_plan",
        ["plan_id"],
        ["id"],
        ondelete="CASCADE",
    )

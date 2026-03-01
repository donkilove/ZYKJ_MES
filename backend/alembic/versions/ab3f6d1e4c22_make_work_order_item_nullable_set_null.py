"""make work order item nullable set null

Revision ID: ab3f6d1e4c22
Revises: 9c2a4d6e8f11
Create Date: 2026-03-02 01:15:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "ab3f6d1e4c22"
down_revision: Union[str, Sequence[str], None] = "9c2a4d6e8f11"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(
        op.f("fk_mes_maintenance_work_order_item_id_mes_maintenance_item"),
        "mes_maintenance_work_order",
        type_="foreignkey",
    )
    op.alter_column(
        "mes_maintenance_work_order",
        "item_id",
        existing_type=sa.Integer(),
        nullable=True,
    )
    op.create_foreign_key(
        op.f("fk_mes_maintenance_work_order_item_id_mes_maintenance_item"),
        "mes_maintenance_work_order",
        "mes_maintenance_item",
        ["item_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        op.f("fk_mes_maintenance_work_order_item_id_mes_maintenance_item"),
        "mes_maintenance_work_order",
        type_="foreignkey",
    )
    op.execute("DELETE FROM mes_maintenance_work_order WHERE item_id IS NULL")
    op.alter_column(
        "mes_maintenance_work_order",
        "item_id",
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.create_foreign_key(
        op.f("fk_mes_maintenance_work_order_item_id_mes_maintenance_item"),
        "mes_maintenance_work_order",
        "mes_maintenance_item",
        ["item_id"],
        ["id"],
        ondelete="RESTRICT",
    )

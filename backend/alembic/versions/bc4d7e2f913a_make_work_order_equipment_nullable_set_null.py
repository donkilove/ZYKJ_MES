"""make work order equipment nullable set null

Revision ID: bc4d7e2f913a
Revises: ab3f6d1e4c22
Create Date: 2026-03-02 01:32:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "bc4d7e2f913a"
down_revision: Union[str, Sequence[str], None] = "ab3f6d1e4c22"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(
        op.f("fk_mes_maintenance_work_order_equipment_id_mes_equipment"),
        "mes_maintenance_work_order",
        type_="foreignkey",
    )
    op.alter_column(
        "mes_maintenance_work_order",
        "equipment_id",
        existing_type=sa.Integer(),
        nullable=True,
    )
    op.create_foreign_key(
        op.f("fk_mes_maintenance_work_order_equipment_id_mes_equipment"),
        "mes_maintenance_work_order",
        "mes_equipment",
        ["equipment_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        op.f("fk_mes_maintenance_work_order_equipment_id_mes_equipment"),
        "mes_maintenance_work_order",
        type_="foreignkey",
    )
    op.execute("DELETE FROM mes_maintenance_work_order WHERE equipment_id IS NULL")
    op.alter_column(
        "mes_maintenance_work_order",
        "equipment_id",
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.create_foreign_key(
        op.f("fk_mes_maintenance_work_order_equipment_id_mes_equipment"),
        "mes_maintenance_work_order",
        "mes_equipment",
        ["equipment_id"],
        ["id"],
        ondelete="RESTRICT",
    )

"""add work order snapshot fields

Revision ID: d15a9c4b7e32
Revises: bc4d7e2f913a
Create Date: 2026-03-02 02:05:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "d15a9c4b7e32"
down_revision: Union[str, Sequence[str], None] = "bc4d7e2f913a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("mes_maintenance_work_order", sa.Column("source_plan_id", sa.Integer(), nullable=True))
    op.add_column(
        "mes_maintenance_work_order",
        sa.Column("source_plan_cycle_days", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_maintenance_work_order",
        sa.Column("source_plan_start_date", sa.Date(), nullable=True),
    )
    op.add_column(
        "mes_maintenance_work_order",
        sa.Column("source_equipment_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_maintenance_work_order",
        sa.Column(
            "source_equipment_code",
            sa.String(length=64),
            nullable=False,
            server_default=sa.text("''"),
        ),
    )
    op.add_column(
        "mes_maintenance_work_order",
        sa.Column(
            "source_equipment_name",
            sa.String(length=128),
            nullable=False,
            server_default=sa.text("''"),
        ),
    )
    op.add_column(
        "mes_maintenance_work_order",
        sa.Column("source_item_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_maintenance_work_order",
        sa.Column(
            "source_item_name",
            sa.String(length=128),
            nullable=False,
            server_default=sa.text("''"),
        ),
    )

    op.create_index(
        op.f("ix_mes_maintenance_work_order_source_plan_id"),
        "mes_maintenance_work_order",
        ["source_plan_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_source_equipment_id"),
        "mes_maintenance_work_order",
        ["source_equipment_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_source_item_id"),
        "mes_maintenance_work_order",
        ["source_item_id"],
        unique=False,
    )

    # Backfill snapshots for existing unfinished work orders.
    op.execute(
        """
        UPDATE mes_maintenance_work_order AS wo
        SET
            source_plan_id = wo.plan_id,
            source_equipment_id = wo.equipment_id,
            source_item_id = wo.item_id
        WHERE wo.status <> 'done'
        """
    )
    op.execute(
        """
        UPDATE mes_maintenance_work_order AS wo
        SET
            source_plan_cycle_days = mp.cycle_days,
            source_plan_start_date = mp.start_date
        FROM mes_maintenance_plan AS mp
        WHERE wo.status <> 'done' AND wo.plan_id = mp.id
        """
    )
    op.execute(
        """
        UPDATE mes_maintenance_work_order AS wo
        SET
            source_equipment_code = COALESCE(eq.code, ''),
            source_equipment_name = COALESCE(eq.name, '')
        FROM mes_equipment AS eq
        WHERE wo.status <> 'done' AND wo.equipment_id = eq.id
        """
    )
    op.execute(
        """
        UPDATE mes_maintenance_work_order AS wo
        SET
            source_item_name = COALESCE(mi.name, '')
        FROM mes_maintenance_item AS mi
        WHERE wo.status <> 'done' AND wo.item_id = mi.id
        """
    )

    op.alter_column("mes_maintenance_work_order", "source_equipment_code", server_default=None)
    op.alter_column("mes_maintenance_work_order", "source_equipment_name", server_default=None)
    op.alter_column("mes_maintenance_work_order", "source_item_name", server_default=None)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_mes_maintenance_work_order_source_item_id"), table_name="mes_maintenance_work_order")
    op.drop_index(
        op.f("ix_mes_maintenance_work_order_source_equipment_id"),
        table_name="mes_maintenance_work_order",
    )
    op.drop_index(op.f("ix_mes_maintenance_work_order_source_plan_id"), table_name="mes_maintenance_work_order")

    op.drop_column("mes_maintenance_work_order", "source_item_name")
    op.drop_column("mes_maintenance_work_order", "source_item_id")
    op.drop_column("mes_maintenance_work_order", "source_equipment_name")
    op.drop_column("mes_maintenance_work_order", "source_equipment_code")
    op.drop_column("mes_maintenance_work_order", "source_equipment_id")
    op.drop_column("mes_maintenance_work_order", "source_plan_start_date")
    op.drop_column("mes_maintenance_work_order", "source_plan_cycle_days")
    op.drop_column("mes_maintenance_work_order", "source_plan_id")

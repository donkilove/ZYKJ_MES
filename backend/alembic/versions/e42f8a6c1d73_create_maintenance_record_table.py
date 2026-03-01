"""create maintenance record table

Revision ID: e42f8a6c1d73
Revises: d15a9c4b7e32
Create Date: 2026-03-02 02:10:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "e42f8a6c1d73"
down_revision: Union[str, Sequence[str], None] = "d15a9c4b7e32"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "mes_maintenance_record",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("work_order_id", sa.Integer(), nullable=False),
        sa.Column("source_plan_id", sa.Integer(), nullable=True),
        sa.Column("source_plan_cycle_days", sa.Integer(), nullable=True),
        sa.Column("source_plan_start_date", sa.Date(), nullable=True),
        sa.Column("source_equipment_id", sa.Integer(), nullable=True),
        sa.Column("source_equipment_code", sa.String(length=64), nullable=False, server_default=sa.text("''")),
        sa.Column("source_equipment_name", sa.String(length=128), nullable=False, server_default=sa.text("''")),
        sa.Column("source_item_id", sa.Integer(), nullable=True),
        sa.Column("source_item_name", sa.String(length=128), nullable=False, server_default=sa.text("''")),
        sa.Column("due_date", sa.Date(), nullable=False),
        sa.Column("executor_user_id", sa.Integer(), nullable=True),
        sa.Column("executor_username", sa.String(length=64), nullable=False, server_default=sa.text("''")),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("result_summary", sa.String(length=255), nullable=False),
        sa.Column("result_remark", sa.String(length=1024), nullable=True),
        sa.Column("attachment_link", sa.String(length=1024), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_maintenance_record")),
        sa.UniqueConstraint("work_order_id", name="uq_mes_maintenance_record_work_order_id"),
    )

    op.create_index(op.f("ix_mes_maintenance_record_id"), "mes_maintenance_record", ["id"], unique=False)
    op.create_index(
        op.f("ix_mes_maintenance_record_work_order_id"),
        "mes_maintenance_record",
        ["work_order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_record_source_equipment_name"),
        "mes_maintenance_record",
        ["source_equipment_name"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_record_source_item_name"),
        "mes_maintenance_record",
        ["source_item_name"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_record_executor_user_id"),
        "mes_maintenance_record",
        ["executor_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_record_completed_at"),
        "mes_maintenance_record",
        ["completed_at"],
        unique=False,
    )

    op.alter_column("mes_maintenance_record", "source_equipment_code", server_default=None)
    op.alter_column("mes_maintenance_record", "source_equipment_name", server_default=None)
    op.alter_column("mes_maintenance_record", "executor_username", server_default=None)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_mes_maintenance_record_completed_at"), table_name="mes_maintenance_record")
    op.drop_index(op.f("ix_mes_maintenance_record_executor_user_id"), table_name="mes_maintenance_record")
    op.drop_index(op.f("ix_mes_maintenance_record_source_item_name"), table_name="mes_maintenance_record")
    op.drop_index(op.f("ix_mes_maintenance_record_source_equipment_name"), table_name="mes_maintenance_record")
    op.drop_index(op.f("ix_mes_maintenance_record_work_order_id"), table_name="mes_maintenance_record")
    op.drop_index(op.f("ix_mes_maintenance_record_id"), table_name="mes_maintenance_record")
    op.drop_table("mes_maintenance_record")

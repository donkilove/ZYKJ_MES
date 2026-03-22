"""add pipeline link and repair record trace

Revision ID: v3w4x5y6z7a
Revises: u2v3w4x5y6z
Create Date: 2026-03-23 11:20:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "v3w4x5y6z7a"
down_revision: Union[str, Sequence[str], None] = "u2v3w4x5y6z"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "mes_order_sub_order_pipeline_instance",
        sa.Column("pipeline_link_id", sa.String(length=64), nullable=True),
    )
    op.create_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_pipeline_link_id"),
        "mes_order_sub_order_pipeline_instance",
        ["pipeline_link_id"],
        unique=False,
    )
    op.execute(
        """
        UPDATE mes_order_sub_order_pipeline_instance
        SET pipeline_link_id = 'LEGACY-' || order_id || '-' || pipeline_seq
        WHERE pipeline_link_id IS NULL
        """
    )

    op.add_column(
        "mes_repair_defect_phenomenon",
        sa.Column("production_record_id", sa.Integer(), nullable=True),
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_production_record_id"),
        "mes_repair_defect_phenomenon",
        ["production_record_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_mes_repair_defect_phenomenon_production_record_id",
        "mes_repair_defect_phenomenon",
        "mes_production_record",
        ["production_record_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_mes_repair_defect_phenomenon_production_record_id",
        "mes_repair_defect_phenomenon",
        type_="foreignkey",
    )
    op.drop_index(
        op.f("ix_mes_repair_defect_phenomenon_production_record_id"),
        table_name="mes_repair_defect_phenomenon",
    )
    op.drop_column("mes_repair_defect_phenomenon", "production_record_id")

    op.drop_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_pipeline_link_id"),
        table_name="mes_order_sub_order_pipeline_instance",
    )
    op.drop_column("mes_order_sub_order_pipeline_instance", "pipeline_link_id")

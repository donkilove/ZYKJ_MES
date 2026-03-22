"""add execution process snapshot to maintenance record

Revision ID: u2v3w4x5y6z
Revises: t1u2v3w4x5y6
Create Date: 2026-03-22 23:20:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "u2v3w4x5y6z"
down_revision: Union[str, Sequence[str], None] = "t1u2v3w4x5y6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "mes_maintenance_record",
        sa.Column(
            "source_execution_process_code",
            sa.String(length=64),
            nullable=False,
            server_default=sa.text("''"),
        ),
    )
    op.create_index(
        op.f("ix_mes_maintenance_record_source_execution_process_code"),
        "mes_maintenance_record",
        ["source_execution_process_code"],
        unique=False,
    )
    op.execute(
        """
        UPDATE mes_maintenance_record AS mr
        SET source_execution_process_code = COALESCE(wo.source_execution_process_code, '')
        FROM mes_maintenance_work_order AS wo
        WHERE mr.work_order_id = wo.id
        """
    )
    op.alter_column(
        "mes_maintenance_record",
        "source_execution_process_code",
        server_default=None,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_mes_maintenance_record_source_execution_process_code"),
        table_name="mes_maintenance_record",
    )
    op.drop_column("mes_maintenance_record", "source_execution_process_code")

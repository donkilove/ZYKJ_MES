"""drop_step_minutes_and_remark_fields

Revision ID: u7v8w9x0y1z2
Revises: v3w4x5y6z7a
Create Date: 2026-03-31 10:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "u7v8w9x0y1z2"
down_revision: Union[str, Sequence[str], None] = "v3w4x5y6z7a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


STEP_TABLES = (
    "mes_product_process_template_step",
    "mes_product_process_template_revision_step",
    "sys_craft_system_master_template_step",
    "sys_craft_system_master_template_revision_step",
)


def upgrade() -> None:
    for table_name in STEP_TABLES:
        op.drop_column(table_name, "step_remark")
        op.drop_column(table_name, "standard_minutes")


def downgrade() -> None:
    for table_name in STEP_TABLES:
        op.add_column(
            table_name,
            sa.Column(
                "standard_minutes",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("0"),
            ),
        )
        op.add_column(
            table_name,
            sa.Column(
                "step_remark",
                sa.String(length=500),
                nullable=False,
                server_default=sa.text("''"),
            ),
        )

"""drop_is_key_process_from_craft_steps

Revision ID: v4x5y6z7a8b
Revises: u7v8w9x0y1z2
Create Date: 2026-03-31 12:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "v4x5y6z7a8b"
down_revision: Union[str, Sequence[str], None] = "u7v8w9x0y1z2"
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
        op.drop_column(table_name, "is_key_process")


def downgrade() -> None:
    for table_name in STEP_TABLES:
        op.add_column(
            table_name,
            sa.Column(
                "is_key_process",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("false"),
            ),
        )

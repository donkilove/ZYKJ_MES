"""add_craft_remark_and_stage_name_unique

Revision ID: i1j2k3l4m5n6
Revises: h1i2j3k4l5m6
Create Date: 2026-03-14

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "i1j2k3l4m5n6"
down_revision: Union[str, Sequence[str], None] = "h1i2j3k4l5m6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("mes_process_stage", sa.Column("remark", sa.String(500), nullable=False, server_default=""))
    op.add_column("mes_process", sa.Column("remark", sa.String(500), nullable=False, server_default=""))
    op.add_column("mes_product_process_template", sa.Column("remark", sa.String(500), nullable=False, server_default=""))
    op.create_unique_constraint("uq_mes_process_stage_name", "mes_process_stage", ["name"])


def downgrade() -> None:
    op.drop_constraint("uq_mes_process_stage_name", "mes_process_stage", type_="unique")
    op.drop_column("mes_product_process_template", "remark")
    op.drop_column("mes_process", "remark")
    op.drop_column("mes_process_stage", "remark")

"""add_equipment_scope_fields

Revision ID: r9s0t1u2v3w4
Revises: q8r9s0t1u2v3
Create Date: 2026-03-19 03:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "r9s0t1u2v3w4"
down_revision: Union[str, Sequence[str], None] = "q8r9s0t1u2v3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("mes_equipment_rule", sa.Column("equipment_type", sa.String(length=64), nullable=True))
    op.create_index(op.f("ix_mes_equipment_rule_equipment_type"), "mes_equipment_rule", ["equipment_type"], unique=False)
    op.add_column("mes_equipment_runtime_parameter", sa.Column("equipment_type", sa.String(length=64), nullable=True))
    op.create_index(op.f("ix_mes_equipment_runtime_parameter_equipment_type"), "mes_equipment_runtime_parameter", ["equipment_type"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_mes_equipment_runtime_parameter_equipment_type"), table_name="mes_equipment_runtime_parameter")
    op.drop_column("mes_equipment_runtime_parameter", "equipment_type")
    op.drop_index(op.f("ix_mes_equipment_rule_equipment_type"), table_name="mes_equipment_rule")
    op.drop_column("mes_equipment_rule", "equipment_type")

"""extend_equipment_rule_and_parameter_state

Revision ID: q8r9s0t1u2v3
Revises: p7q8r9s0t1u2
Create Date: 2026-03-19 03:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "q8r9s0t1u2v3"
down_revision: Union[str, Sequence[str], None] = "p7q8r9s0t1u2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "mes_equipment_rule",
        sa.Column("rule_code", sa.String(length=64), nullable=True),
    )
    op.execute(
        sa.text(
            "UPDATE mes_equipment_rule SET rule_code = CONCAT('RULE-', id) WHERE rule_code IS NULL"
        )
    )
    op.alter_column("mes_equipment_rule", "rule_code", existing_type=sa.String(length=64), nullable=False)
    op.create_index(op.f("ix_mes_equipment_rule_rule_code"), "mes_equipment_rule", ["rule_code"], unique=False)
    op.create_unique_constraint(
        "uq_mes_equipment_rule_rule_code",
        "mes_equipment_rule",
        ["rule_code"],
    )

    op.add_column(
        "mes_equipment_runtime_parameter",
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )
    op.create_index(
        op.f("ix_mes_equipment_runtime_parameter_is_enabled"),
        "mes_equipment_runtime_parameter",
        ["is_enabled"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_mes_equipment_runtime_parameter_is_enabled"), table_name="mes_equipment_runtime_parameter")
    op.drop_column("mes_equipment_runtime_parameter", "is_enabled")

    op.drop_constraint("uq_mes_equipment_rule_rule_code", "mes_equipment_rule", type_="unique")
    op.drop_index(op.f("ix_mes_equipment_rule_rule_code"), table_name="mes_equipment_rule")
    op.drop_column("mes_equipment_rule", "rule_code")

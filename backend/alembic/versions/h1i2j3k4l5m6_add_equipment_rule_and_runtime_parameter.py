"""add_equipment_rule_and_runtime_parameter

Revision ID: h1i2j3k4l5m6
Revises: 0998ac4f196a
Create Date: 2026-03-14

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "h1i2j3k4l5m6"
down_revision: Union[str, Sequence[str], None] = "0998ac4f196a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mes_equipment_rule",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("equipment_id", sa.Integer(), nullable=True),
        sa.Column("equipment_code", sa.String(64), nullable=True),
        sa.Column("equipment_name", sa.String(128), nullable=True),
        sa.Column("rule_name", sa.String(128), nullable=False),
        sa.Column("rule_type", sa.String(64), nullable=False, server_default=""),
        sa.Column("condition_desc", sa.Text(), nullable=False, server_default=""),
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("effective_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("remark", sa.Text(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["equipment_id"], ["mes_equipment.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_mes_equipment_rule_id", "mes_equipment_rule", ["id"])
    op.create_index("ix_mes_equipment_rule_equipment_id", "mes_equipment_rule", ["equipment_id"])
    op.create_index("ix_mes_equipment_rule_equipment_code", "mes_equipment_rule", ["equipment_code"])
    op.create_index("ix_mes_equipment_rule_rule_name", "mes_equipment_rule", ["rule_name"])
    op.create_index("ix_mes_equipment_rule_rule_type", "mes_equipment_rule", ["rule_type"])
    op.create_index("ix_mes_equipment_rule_is_enabled", "mes_equipment_rule", ["is_enabled"])

    op.create_table(
        "mes_equipment_runtime_parameter",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("equipment_id", sa.Integer(), nullable=True),
        sa.Column("equipment_code", sa.String(64), nullable=True),
        sa.Column("equipment_name", sa.String(128), nullable=True),
        sa.Column("param_code", sa.String(64), nullable=False),
        sa.Column("param_name", sa.String(128), nullable=False),
        sa.Column("unit", sa.String(32), nullable=False, server_default=""),
        sa.Column("standard_value", sa.Numeric(18, 4), nullable=True),
        sa.Column("upper_limit", sa.Numeric(18, 4), nullable=True),
        sa.Column("lower_limit", sa.Numeric(18, 4), nullable=True),
        sa.Column("effective_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("remark", sa.Text(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["equipment_id"], ["mes_equipment.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_mes_equipment_runtime_parameter_id", "mes_equipment_runtime_parameter", ["id"])
    op.create_index("ix_mes_equipment_runtime_parameter_equipment_id", "mes_equipment_runtime_parameter", ["equipment_id"])
    op.create_index("ix_mes_equipment_runtime_parameter_equipment_code", "mes_equipment_runtime_parameter", ["equipment_code"])
    op.create_index("ix_mes_equipment_runtime_parameter_param_code", "mes_equipment_runtime_parameter", ["param_code"])
    op.create_index("ix_mes_equipment_runtime_parameter_param_name", "mes_equipment_runtime_parameter", ["param_name"])


def downgrade() -> None:
    op.drop_table("mes_equipment_runtime_parameter")
    op.drop_table("mes_equipment_rule")

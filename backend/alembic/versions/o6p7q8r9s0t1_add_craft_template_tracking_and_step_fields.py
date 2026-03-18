"""add_craft_template_tracking_and_step_fields

Revision ID: o6p7q8r9s0t1
Revises: m4n5o6p7q8r9
Create Date: 2026-03-19 00:40:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "o6p7q8r9s0t1"
down_revision: Union[str, Sequence[str], None] = "m4n5o6p7q8r9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _add_step_columns(table_name: str) -> None:
    op.add_column(table_name, sa.Column("standard_minutes", sa.Integer(), nullable=False, server_default=sa.text("0")))
    op.add_column(table_name, sa.Column("is_key_process", sa.Boolean(), nullable=False, server_default=sa.text("false")))
    op.add_column(table_name, sa.Column("step_remark", sa.String(length=500), nullable=False, server_default=sa.text("''")))


def _drop_step_columns(table_name: str) -> None:
    op.drop_column(table_name, "step_remark")
    op.drop_column(table_name, "is_key_process")
    op.drop_column(table_name, "standard_minutes")


def upgrade() -> None:
    op.add_column(
        "mes_product_process_template",
        sa.Column("source_type", sa.String(length=32), nullable=False, server_default=sa.text("'manual'")),
    )
    op.add_column(
        "mes_product_process_template",
        sa.Column("source_template_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_product_process_template",
        sa.Column("source_template_name", sa.String(length=128), nullable=True),
    )
    op.add_column(
        "mes_product_process_template",
        sa.Column("source_template_version", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_product_process_template",
        sa.Column("source_product_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_product_process_template",
        sa.Column("source_system_master_version", sa.Integer(), nullable=True),
    )
    op.create_index(
        op.f("ix_mes_product_process_template_source_template_id"),
        "mes_product_process_template",
        ["source_template_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_source_product_id"),
        "mes_product_process_template",
        ["source_product_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_mes_ppt_source_template_id",
        "mes_product_process_template",
        "mes_product_process_template",
        ["source_template_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_foreign_key(
        "fk_mes_ppt_source_product_id",
        "mes_product_process_template",
        "mes_product",
        ["source_product_id"],
        ["id"],
        ondelete="SET NULL",
    )

    for table_name in (
        "mes_product_process_template_step",
        "mes_product_process_template_revision_step",
        "sys_craft_system_master_template_step",
        "sys_craft_system_master_template_revision_step",
    ):
        _add_step_columns(table_name)


def downgrade() -> None:
    for table_name in (
        "sys_craft_system_master_template_revision_step",
        "sys_craft_system_master_template_step",
        "mes_product_process_template_revision_step",
        "mes_product_process_template_step",
    ):
        _drop_step_columns(table_name)

    op.drop_constraint("fk_mes_ppt_source_product_id", "mes_product_process_template", type_="foreignkey")
    op.drop_constraint("fk_mes_ppt_source_template_id", "mes_product_process_template", type_="foreignkey")
    op.drop_index(op.f("ix_mes_product_process_template_source_product_id"), table_name="mes_product_process_template")
    op.drop_index(op.f("ix_mes_product_process_template_source_template_id"), table_name="mes_product_process_template")
    op.drop_column("mes_product_process_template", "source_system_master_version")
    op.drop_column("mes_product_process_template", "source_product_id")
    op.drop_column("mes_product_process_template", "source_template_version")
    op.drop_column("mes_product_process_template", "source_template_name")
    op.drop_column("mes_product_process_template", "source_template_id")
    op.drop_column("mes_product_process_template", "source_type")

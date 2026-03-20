"""add_operator_to_scrap_statistics

Revision ID: s0t1u2v3w4x5
Revises: r9s0t1u2v3w4
Create Date: 2026-03-19 04:10:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "s0t1u2v3w4x5"
down_revision: Union[str, Sequence[str], None] = "r9s0t1u2v3w4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "mes_production_scrap_statistics",
        sa.Column("operator_user_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_production_scrap_statistics",
        sa.Column("operator_username", sa.String(length=128), nullable=True),
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_operator_user_id"),
        "mes_production_scrap_statistics",
        ["operator_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_operator_username"),
        "mes_production_scrap_statistics",
        ["operator_username"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_mes_prod_scrap_statistics_operator_user_id",
        "mes_production_scrap_statistics",
        "sys_user",
        ["operator_user_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_mes_prod_scrap_statistics_operator_user_id",
        "mes_production_scrap_statistics",
        type_="foreignkey",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_operator_username"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_operator_user_id"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_column("mes_production_scrap_statistics", "operator_username")
    op.drop_column("mes_production_scrap_statistics", "operator_user_id")

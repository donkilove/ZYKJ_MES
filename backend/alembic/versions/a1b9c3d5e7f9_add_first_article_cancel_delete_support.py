"""add first article cancel delete support

Revision ID: a1b9c3d5e7f9
Revises: z8a9b0c1d2e3
Create Date: 2026-05-11 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "a1b9c3d5e7f9"
down_revision: Union[str, Sequence[str], None] = "z8a9b0c1d2e3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "mes_first_article_record",
        sa.Column("sub_order_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_first_article_record",
        sa.Column("assist_authorization_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_first_article_record",
        sa.Column(
            "is_cancelled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "mes_first_article_record",
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "mes_first_article_record",
        sa.Column("cancelled_by_user_id", sa.Integer(), nullable=True),
    )
    op.create_index(
        op.f("ix_mes_first_article_record_sub_order_id"),
        "mes_first_article_record",
        ["sub_order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_first_article_record_assist_authorization_id"),
        "mes_first_article_record",
        ["assist_authorization_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_first_article_record_is_cancelled"),
        "mes_first_article_record",
        ["is_cancelled"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_first_article_record_cancelled_by_user_id"),
        "mes_first_article_record",
        ["cancelled_by_user_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_mes_first_article_record_sub_order_id",
        "mes_first_article_record",
        "mes_order_sub_order",
        ["sub_order_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_foreign_key(
        "fk_mes_first_article_record_assist_authorization_id",
        "mes_first_article_record",
        "mes_production_assist_authorization",
        ["assist_authorization_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_foreign_key(
        "fk_mes_first_article_record_cancelled_by_user_id",
        "mes_first_article_record",
        "sys_user",
        ["cancelled_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_mes_first_article_record_cancelled_by_user_id",
        "mes_first_article_record",
        type_="foreignkey",
    )
    op.drop_constraint(
        "fk_mes_first_article_record_assist_authorization_id",
        "mes_first_article_record",
        type_="foreignkey",
    )
    op.drop_constraint(
        "fk_mes_first_article_record_sub_order_id",
        "mes_first_article_record",
        type_="foreignkey",
    )
    op.drop_index(
        op.f("ix_mes_first_article_record_cancelled_by_user_id"),
        table_name="mes_first_article_record",
    )
    op.drop_index(
        op.f("ix_mes_first_article_record_is_cancelled"),
        table_name="mes_first_article_record",
    )
    op.drop_index(
        op.f("ix_mes_first_article_record_assist_authorization_id"),
        table_name="mes_first_article_record",
    )
    op.drop_index(
        op.f("ix_mes_first_article_record_sub_order_id"),
        table_name="mes_first_article_record",
    )
    op.drop_column("mes_first_article_record", "cancelled_by_user_id")
    op.drop_column("mes_first_article_record", "cancelled_at")
    op.drop_column("mes_first_article_record", "is_cancelled")
    op.drop_column("mes_first_article_record", "assist_authorization_id")
    op.drop_column("mes_first_article_record", "sub_order_id")

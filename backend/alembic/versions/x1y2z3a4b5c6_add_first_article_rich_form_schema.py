"""add first article rich form schema

Revision ID: x1y2z3a4b5c6
Revises: w6x7y8z9a0b
Create Date: 2026-04-03 12:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "x1y2z3a4b5c6"
down_revision: Union[str, Sequence[str], None] = "w6x7y8z9a0b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mes_first_article_template",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("product_id", sa.Integer(), nullable=False),
        sa.Column("process_code", sa.String(length=64), nullable=False),
        sa.Column("template_name", sa.String(length=128), nullable=False),
        sa.Column("check_content", sa.Text(), nullable=True),
        sa.Column("test_value", sa.Text(), nullable=True),
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.ForeignKeyConstraint(["product_id"], ["mes_product.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "product_id",
            "process_code",
            "template_name",
            name="uq_mes_first_article_template_product_process_name",
        ),
    )
    op.create_index(
        op.f("ix_mes_first_article_template_id"),
        "mes_first_article_template",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_first_article_template_product_id"),
        "mes_first_article_template",
        ["product_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_first_article_template_process_code"),
        "mes_first_article_template",
        ["process_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_first_article_template_is_enabled"),
        "mes_first_article_template",
        ["is_enabled"],
        unique=False,
    )

    op.add_column(
        "mes_first_article_record",
        sa.Column("template_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_first_article_record",
        sa.Column("check_content", sa.Text(), nullable=True),
    )
    op.add_column(
        "mes_first_article_record",
        sa.Column("test_value", sa.Text(), nullable=True),
    )
    op.create_index(
        op.f("ix_mes_first_article_record_template_id"),
        "mes_first_article_record",
        ["template_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_mes_first_article_record_template_id",
        "mes_first_article_record",
        "mes_first_article_template",
        ["template_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "mes_first_article_participant",
        sa.Column("record_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["record_id"],
            ["mes_first_article_record.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["sys_user.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("record_id", "user_id"),
    )
    op.create_index(
        op.f("ix_mes_first_article_participant_user_id"),
        "mes_first_article_participant",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_mes_first_article_participant_user_id"),
        table_name="mes_first_article_participant",
    )
    op.drop_table("mes_first_article_participant")

    op.drop_constraint(
        "fk_mes_first_article_record_template_id",
        "mes_first_article_record",
        type_="foreignkey",
    )
    op.drop_index(
        op.f("ix_mes_first_article_record_template_id"),
        table_name="mes_first_article_record",
    )
    op.drop_column("mes_first_article_record", "test_value")
    op.drop_column("mes_first_article_record", "check_content")
    op.drop_column("mes_first_article_record", "template_id")

    op.drop_index(
        op.f("ix_mes_first_article_template_is_enabled"),
        table_name="mes_first_article_template",
    )
    op.drop_index(
        op.f("ix_mes_first_article_template_process_code"),
        table_name="mes_first_article_template",
    )
    op.drop_index(
        op.f("ix_mes_first_article_template_product_id"),
        table_name="mes_first_article_template",
    )
    op.drop_index(
        op.f("ix_mes_first_article_template_id"),
        table_name="mes_first_article_template",
    )
    op.drop_table("mes_first_article_template")

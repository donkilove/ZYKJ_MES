"""add first article review session

Revision ID: z8a9b0c1d2e3
Revises: y7z8a9b0c1d2
Create Date: 2026-04-25 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "z8a9b0c1d2e3"
down_revision: Union[str, Sequence[str], None] = "y7z8a9b0c1d2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mes_first_article_review_session",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("token_hash", sa.String(length=128), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("order_process_id", sa.Integer(), nullable=False),
        sa.Column("pipeline_instance_id", sa.Integer(), nullable=True),
        sa.Column("operator_user_id", sa.Integer(), nullable=False),
        sa.Column("assist_authorization_id", sa.Integer(), nullable=True),
        sa.Column("template_id", sa.Integer(), nullable=True),
        sa.Column("check_content", sa.Text(), nullable=False),
        sa.Column("test_value", sa.Text(), nullable=False),
        sa.Column("participant_user_ids", sa.JSON(), nullable=False),
        sa.Column("reviewer_user_id", sa.Integer(), nullable=True),
        sa.Column("review_result", sa.String(length=32), nullable=True),
        sa.Column("review_remark", sa.Text(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("first_article_record_id", sa.Integer(), nullable=True),
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
        sa.ForeignKeyConstraint(
            ["assist_authorization_id"],
            ["mes_production_assist_authorization.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["first_article_record_id"],
            ["mes_first_article_record.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(["operator_user_id"], ["sys_user.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["order_id"], ["mes_order.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["order_process_id"],
            ["mes_order_process.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["pipeline_instance_id"],
            ["mes_order_sub_order_pipeline_instance.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(["reviewer_user_id"], ["sys_user.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["template_id"],
            ["mes_first_article_template.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_mes_first_article_review_session_id"),
        "mes_first_article_review_session",
        ["id"],
        unique=False,
    )
    op.create_index(
        "ix_mes_first_article_review_session_token_hash",
        "mes_first_article_review_session",
        ["token_hash"],
        unique=True,
    )
    op.create_index(
        "ix_mes_first_article_review_session_status",
        "mes_first_article_review_session",
        ["status"],
        unique=False,
    )
    op.create_index(
        "ix_mes_first_article_review_session_expires_at",
        "mes_first_article_review_session",
        ["expires_at"],
        unique=False,
    )
    for column_name in (
        "order_id",
        "order_process_id",
        "pipeline_instance_id",
        "operator_user_id",
        "assist_authorization_id",
        "template_id",
        "reviewer_user_id",
        "first_article_record_id",
    ):
        op.create_index(
            op.f(f"ix_mes_first_article_review_session_{column_name}"),
            "mes_first_article_review_session",
            [column_name],
            unique=False,
        )

    op.add_column(
        "mes_first_article_record",
        sa.Column("reviewer_user_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_first_article_record",
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "mes_first_article_record",
        sa.Column("review_remark", sa.Text(), nullable=True),
    )
    op.create_foreign_key(
        "fk_mes_first_article_record_reviewer_user_id",
        "mes_first_article_record",
        "sys_user",
        ["reviewer_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        op.f("ix_mes_first_article_record_reviewer_user_id"),
        "mes_first_article_record",
        ["reviewer_user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_mes_first_article_record_reviewer_user_id"),
        table_name="mes_first_article_record",
    )
    op.drop_constraint(
        "fk_mes_first_article_record_reviewer_user_id",
        "mes_first_article_record",
        type_="foreignkey",
    )
    op.drop_column("mes_first_article_record", "review_remark")
    op.drop_column("mes_first_article_record", "reviewed_at")
    op.drop_column("mes_first_article_record", "reviewer_user_id")

    for column_name in (
        "first_article_record_id",
        "reviewer_user_id",
        "template_id",
        "assist_authorization_id",
        "operator_user_id",
        "pipeline_instance_id",
        "order_process_id",
        "order_id",
    ):
        op.drop_index(
            op.f(f"ix_mes_first_article_review_session_{column_name}"),
            table_name="mes_first_article_review_session",
        )
    op.drop_index(
        "ix_mes_first_article_review_session_expires_at",
        table_name="mes_first_article_review_session",
    )
    op.drop_index(
        "ix_mes_first_article_review_session_status",
        table_name="mes_first_article_review_session",
    )
    op.drop_index(
        "ix_mes_first_article_review_session_token_hash",
        table_name="mes_first_article_review_session",
    )
    op.drop_index(
        op.f("ix_mes_first_article_review_session_id"),
        table_name="mes_first_article_review_session",
    )
    op.drop_table("mes_first_article_review_session")

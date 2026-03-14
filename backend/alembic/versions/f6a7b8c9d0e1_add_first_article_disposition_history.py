"""add first_article_disposition_history table

Revision ID: f6a7b8c9d0e1
Revises: d5e6f7a8b9c0
Create Date: 2026-03-14 14:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "f6a7b8c9d0e1"
down_revision: Union[str, None] = "d5e6f7a8b9c0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mes_first_article_disposition_history",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("first_article_record_id", sa.Integer(), nullable=False),
        sa.Column("disposition_opinion", sa.Text(), nullable=False),
        sa.Column("disposition_user_id", sa.Integer(), nullable=True),
        sa.Column("disposition_username", sa.String(128), nullable=True),
        sa.Column("disposition_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("recheck_result", sa.String(32), nullable=True),
        sa.Column("final_judgment", sa.String(32), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["first_article_record_id"],
            ["mes_first_article_record.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["disposition_user_id"],
            ["sys_user.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_mes_fa_disposition_history_id",
        "mes_first_article_disposition_history",
        ["id"],
    )
    op.create_index(
        "ix_mes_fa_disposition_history_record_id",
        "mes_first_article_disposition_history",
        ["first_article_record_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_mes_fa_disposition_history_record_id", table_name="mes_first_article_disposition_history")
    op.drop_index("ix_mes_fa_disposition_history_id", table_name="mes_first_article_disposition_history")
    op.drop_table("mes_first_article_disposition_history")

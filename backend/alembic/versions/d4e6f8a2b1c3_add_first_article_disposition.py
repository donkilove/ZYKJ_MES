"""add first_article_disposition table

Revision ID: d4e6f8a2b1c3
Revises: c3e5f7a9b1d2
Create Date: 2026-03-14 10:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "d4e6f8a2b1c3"
down_revision: Union[str, None] = "c3e5f7a9b1d2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mes_first_article_disposition",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("first_article_record_id", sa.Integer(), nullable=False),
        sa.Column("disposition_opinion", sa.Text(), nullable=False),
        sa.Column("disposition_user_id", sa.Integer(), nullable=True),
        sa.Column("disposition_username", sa.String(128), nullable=True),
        sa.Column("disposition_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("recheck_result", sa.String(32), nullable=True),
        sa.Column("final_judgment", sa.String(32), nullable=False),
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
        sa.UniqueConstraint("first_article_record_id", name="uq_disposition_record"),
    )
    op.create_index("ix_mes_first_article_disposition_id", "mes_first_article_disposition", ["id"])
    op.create_index(
        "ix_mes_first_article_disposition_record_id",
        "mes_first_article_disposition",
        ["first_article_record_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_mes_first_article_disposition_record_id", table_name="mes_first_article_disposition")
    op.drop_index("ix_mes_first_article_disposition_id", table_name="mes_first_article_disposition")
    op.drop_table("mes_first_article_disposition")

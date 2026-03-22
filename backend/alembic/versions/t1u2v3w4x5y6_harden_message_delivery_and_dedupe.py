"""harden_message_delivery_and_dedupe

Revision ID: t1u2v3w4x5y6
Revises: s0t1u2v3w4x5
Create Date: 2026-03-22 10:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "t1u2v3w4x5y6"
down_revision: Union[str, Sequence[str], None] = "s0t1u2v3w4x5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "msg_message_recipient",
        sa.Column("last_failure_reason", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "msg_message_recipient",
        sa.Column(
            "delivery_attempt_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "msg_message_recipient",
        sa.Column("next_retry_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        op.f("ix_msg_message_recipient_next_retry_at"),
        "msg_message_recipient",
        ["next_retry_at"],
        unique=False,
    )
    op.execute(
        sa.text(
            """
            WITH ranked_duplicates AS (
                SELECT id,
                       ROW_NUMBER() OVER (
                           PARTITION BY dedupe_key
                           ORDER BY id ASC
                       ) AS duplicate_rank
                FROM msg_message
                WHERE dedupe_key IS NOT NULL
            )
            UPDATE msg_message AS message_row
            SET dedupe_key = NULL
            FROM ranked_duplicates
            WHERE message_row.id = ranked_duplicates.id
              AND ranked_duplicates.duplicate_rank > 1
            """
        )
    )
    op.create_index(
        "uq_msg_message_dedupe_key_not_null",
        "msg_message",
        ["dedupe_key"],
        unique=True,
        postgresql_where=sa.text("dedupe_key IS NOT NULL"),
        sqlite_where=sa.text("dedupe_key IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("uq_msg_message_dedupe_key_not_null", table_name="msg_message")
    op.drop_index(
        op.f("ix_msg_message_recipient_next_retry_at"),
        table_name="msg_message_recipient",
    )
    op.drop_column("msg_message_recipient", "next_retry_at")
    op.drop_column("msg_message_recipient", "delivery_attempt_count")
    op.drop_column("msg_message_recipient", "last_failure_reason")

"""add message tables

Revision ID: e5f6a7b8c9d0
Revises: d4e6f8a2b1c3
Create Date: 2026-03-14 12:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e5f6a7b8c9d0"
down_revision: Union[str, None] = "d4e6f8a2b1c3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "msg_message",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("message_type", sa.String(32), nullable=False),
        sa.Column("priority", sa.String(16), nullable=False, server_default="normal"),
        sa.Column("title", sa.String(256), nullable=False),
        sa.Column("summary", sa.String(512), nullable=True),
        sa.Column("content", sa.Text(), nullable=True),
        sa.Column("source_module", sa.String(64), nullable=True),
        sa.Column("source_type", sa.String(64), nullable=True),
        sa.Column("source_id", sa.String(64), nullable=True),
        sa.Column("source_code", sa.String(128), nullable=True),
        sa.Column("target_page_code", sa.String(64), nullable=True),
        sa.Column("target_tab_code", sa.String(64), nullable=True),
        sa.Column("target_route_payload_json", sa.Text(), nullable=True),
        sa.Column("dedupe_key", sa.String(256), nullable=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="active"),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
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
            ["created_by_user_id"],
            ["sys_user.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_msg_message"),
    )
    op.create_index("ix_msg_message_id", "msg_message", ["id"])
    op.create_index("ix_msg_message_message_type", "msg_message", ["message_type"])
    op.create_index("ix_msg_message_priority", "msg_message", ["priority"])
    op.create_index("ix_msg_message_source_module", "msg_message", ["source_module"])
    op.create_index("ix_msg_message_source_type", "msg_message", ["source_type"])
    op.create_index("ix_msg_message_source_id", "msg_message", ["source_id"])
    op.create_index("ix_msg_message_status", "msg_message", ["status"])
    op.create_index("ix_msg_message_published_at", "msg_message", ["published_at"])
    op.create_index(
        "ix_msg_message_type_priority_published",
        "msg_message",
        ["message_type", "priority", "published_at"],
    )
    op.create_index(
        "ix_msg_message_source",
        "msg_message",
        ["source_module", "source_type", "source_id"],
    )

    op.create_table(
        "msg_message_recipient",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("message_id", sa.Integer(), nullable=False),
        sa.Column("recipient_user_id", sa.Integer(), nullable=False),
        sa.Column("delivery_status", sa.String(16), nullable=False, server_default="delivered"),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("last_push_at", sa.DateTime(timezone=True), nullable=True),
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
            ["message_id"],
            ["msg_message.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["recipient_user_id"],
            ["sys_user.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_msg_message_recipient"),
        sa.UniqueConstraint(
            "message_id",
            "recipient_user_id",
            name="uq_msg_recipient_message_user",
        ),
    )
    op.create_index("ix_msg_message_recipient_id", "msg_message_recipient", ["id"])
    op.create_index(
        "ix_msg_message_recipient_message_id", "msg_message_recipient", ["message_id"]
    )
    op.create_index(
        "ix_msg_message_recipient_recipient_user_id",
        "msg_message_recipient",
        ["recipient_user_id"],
    )
    op.create_index(
        "ix_msg_message_recipient_is_read", "msg_message_recipient", ["is_read"]
    )
    op.create_index(
        "ix_msg_recipient_user_unread",
        "msg_message_recipient",
        ["recipient_user_id", "is_read", "created_at"],
    )


def downgrade() -> None:
    op.drop_table("msg_message_recipient")
    op.drop_table("msg_message")

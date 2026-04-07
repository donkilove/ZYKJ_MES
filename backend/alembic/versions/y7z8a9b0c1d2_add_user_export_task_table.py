"""add user export task table

Revision ID: y7z8a9b0c1d2
Revises: c5d6e7f8a9b0, g7b8c9d0e1f2, x1y2z3a4b5c6
Create Date: 2026-04-07 20:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "y7z8a9b0c1d2"
down_revision: Union[str, Sequence[str], None] = (
    "c5d6e7f8a9b0",
    "g7b8c9d0e1f2",
    "x1y2z3a4b5c6",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "sys_user_export_task",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("task_code", sa.String(length=64), nullable=False),
        sa.Column("created_by_user_id", sa.Integer(), nullable=False),
        sa.Column(
            "status",
            sa.String(length=32),
            nullable=False,
            server_default=sa.text("'pending'"),
        ),
        sa.Column("format", sa.String(length=16), nullable=False),
        sa.Column("deleted_scope", sa.String(length=16), nullable=False),
        sa.Column("keyword", sa.String(length=255), nullable=True),
        sa.Column("role_code", sa.String(length=64), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=True),
        sa.Column(
            "record_count",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column("file_name", sa.String(length=255), nullable=True),
        sa.Column("mime_type", sa.String(length=128), nullable=True),
        sa.Column("storage_path", sa.Text(), nullable=True),
        sa.Column("failure_reason", sa.Text(), nullable=True),
        sa.Column(
            "requested_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["sys_user.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("task_code", name="uq_sys_user_export_task_task_code"),
    )
    op.create_index(
        op.f("ix_sys_user_export_task_id"),
        "sys_user_export_task",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_user_export_task_created_by_user_id"),
        "sys_user_export_task",
        ["created_by_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_user_export_task_status"),
        "sys_user_export_task",
        ["status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_user_export_task_requested_at"),
        "sys_user_export_task",
        ["requested_at"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_user_export_task_expires_at"),
        "sys_user_export_task",
        ["expires_at"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_user_export_task_task_code"),
        "sys_user_export_task",
        ["task_code"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_sys_user_export_task_task_code"),
        table_name="sys_user_export_task",
    )
    op.drop_index(
        op.f("ix_sys_user_export_task_expires_at"),
        table_name="sys_user_export_task",
    )
    op.drop_index(
        op.f("ix_sys_user_export_task_requested_at"),
        table_name="sys_user_export_task",
    )
    op.drop_index(
        op.f("ix_sys_user_export_task_status"),
        table_name="sys_user_export_task",
    )
    op.drop_index(
        op.f("ix_sys_user_export_task_created_by_user_id"),
        table_name="sys_user_export_task",
    )
    op.drop_index(
        op.f("ix_sys_user_export_task_id"),
        table_name="sys_user_export_task",
    )
    op.drop_table("sys_user_export_task")

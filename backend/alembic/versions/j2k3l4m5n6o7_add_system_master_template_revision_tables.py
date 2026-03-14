"""add_system_master_template_revision_tables

Revision ID: j2k3l4m5n6o7
Revises: i1j2k3l4m5n6
Create Date: 2026-03-14

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "j2k3l4m5n6o7"
down_revision: Union[str, Sequence[str], None] = "i1j2k3l4m5n6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "sys_craft_system_master_template_revision",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("template_id", sa.Integer(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("action", sa.String(length=32), nullable=False),
        sa.Column("note", sa.String(length=256), nullable=True),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["sys_user.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["template_id"], ["sys_craft_system_master_template.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "template_id",
            "version",
            name="uq_sys_craft_system_master_template_revision_template_id_version",
        ),
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_revision_id"),
        "sys_craft_system_master_template_revision",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_revision_template_id"),
        "sys_craft_system_master_template_revision",
        ["template_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_revision_created_by_user_id"),
        "sys_craft_system_master_template_revision",
        ["created_by_user_id"],
        unique=False,
    )

    op.create_table(
        "sys_craft_system_master_template_revision_step",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("revision_id", sa.Integer(), nullable=False),
        sa.Column("step_order", sa.Integer(), nullable=False),
        sa.Column("stage_id", sa.Integer(), nullable=False),
        sa.Column("stage_code", sa.String(length=64), nullable=False),
        sa.Column("stage_name", sa.String(length=128), nullable=False),
        sa.Column("process_id", sa.Integer(), nullable=False),
        sa.Column("process_code", sa.String(length=64), nullable=False),
        sa.Column("process_name", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.ForeignKeyConstraint(
            ["process_id"],
            ["mes_process.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["revision_id"],
            ["sys_craft_system_master_template_revision.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["stage_id"],
            ["mes_process_stage.id"],
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "revision_id",
            "step_order",
            name="uq_sys_craft_system_master_template_revision_step_revision_id_step_order",
        ),
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_revision_step_id"),
        "sys_craft_system_master_template_revision_step",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_revision_step_revision_id"),
        "sys_craft_system_master_template_revision_step",
        ["revision_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_revision_step_stage_id"),
        "sys_craft_system_master_template_revision_step",
        ["stage_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_revision_step_stage_code"),
        "sys_craft_system_master_template_revision_step",
        ["stage_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_revision_step_process_id"),
        "sys_craft_system_master_template_revision_step",
        ["process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_revision_step_process_code"),
        "sys_craft_system_master_template_revision_step",
        ["process_code"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_sys_craft_system_master_template_revision_step_process_code"), table_name="sys_craft_system_master_template_revision_step")
    op.drop_index(op.f("ix_sys_craft_system_master_template_revision_step_process_id"), table_name="sys_craft_system_master_template_revision_step")
    op.drop_index(op.f("ix_sys_craft_system_master_template_revision_step_stage_code"), table_name="sys_craft_system_master_template_revision_step")
    op.drop_index(op.f("ix_sys_craft_system_master_template_revision_step_stage_id"), table_name="sys_craft_system_master_template_revision_step")
    op.drop_index(op.f("ix_sys_craft_system_master_template_revision_step_revision_id"), table_name="sys_craft_system_master_template_revision_step")
    op.drop_index(op.f("ix_sys_craft_system_master_template_revision_step_id"), table_name="sys_craft_system_master_template_revision_step")
    op.drop_table("sys_craft_system_master_template_revision_step")

    op.drop_index(op.f("ix_sys_craft_system_master_template_revision_created_by_user_id"), table_name="sys_craft_system_master_template_revision")
    op.drop_index(op.f("ix_sys_craft_system_master_template_revision_template_id"), table_name="sys_craft_system_master_template_revision")
    op.drop_index(op.f("ix_sys_craft_system_master_template_revision_id"), table_name="sys_craft_system_master_template_revision")
    op.drop_table("sys_craft_system_master_template_revision")

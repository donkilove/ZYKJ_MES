"""add craft system master template tables

Revision ID: b1a2c3d4e5f6
Revises: a8b7c6d5e4f3
Create Date: 2026-03-06 12:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b1a2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "a8b7c6d5e4f3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "sys_craft_system_master_template",
        sa.Column("id", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
        sa.Column("updated_by_user_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("id = 1", name=op.f("ck_sys_craft_system_master_template_singleton_id_eq_1")),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["sys_user.id"],
            name=op.f("fk_sys_craft_system_master_template_created_by_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["updated_by_user_id"],
            ["sys_user.id"],
            name=op.f("fk_sys_craft_system_master_template_updated_by_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_craft_system_master_template")),
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_id"),
        "sys_craft_system_master_template",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_created_by_user_id"),
        "sys_craft_system_master_template",
        ["created_by_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_updated_by_user_id"),
        "sys_craft_system_master_template",
        ["updated_by_user_id"],
        unique=False,
    )

    op.create_table(
        "sys_craft_system_master_template_step",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("template_id", sa.Integer(), nullable=False),
        sa.Column("step_order", sa.Integer(), nullable=False),
        sa.Column("stage_id", sa.Integer(), nullable=False),
        sa.Column("stage_code", sa.String(length=64), nullable=False),
        sa.Column("stage_name", sa.String(length=128), nullable=False),
        sa.Column("process_id", sa.Integer(), nullable=False),
        sa.Column("process_code", sa.String(length=64), nullable=False),
        sa.Column("process_name", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["template_id"],
            ["sys_craft_system_master_template.id"],
            name=op.f("fk_sys_craft_system_master_template_step_template_id_sys_craft_system_master_template"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["stage_id"],
            ["mes_process_stage.id"],
            name=op.f("fk_sys_craft_system_master_template_step_stage_id_mes_process_stage"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["process_id"],
            ["mes_process.id"],
            name=op.f("fk_sys_craft_system_master_template_step_process_id_mes_process"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_craft_system_master_template_step")),
        sa.UniqueConstraint(
            "template_id",
            "step_order",
            name="uq_sys_craft_system_master_template_step_template_id_step_order",
        ),
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_step_id"),
        "sys_craft_system_master_template_step",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_step_template_id"),
        "sys_craft_system_master_template_step",
        ["template_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_step_stage_id"),
        "sys_craft_system_master_template_step",
        ["stage_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_step_stage_code"),
        "sys_craft_system_master_template_step",
        ["stage_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_step_process_id"),
        "sys_craft_system_master_template_step",
        ["process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_system_master_template_step_process_code"),
        "sys_craft_system_master_template_step",
        ["process_code"],
        unique=False,
    )

    op.execute("DROP TABLE IF EXISTS sys_craft_default_template_source CASCADE")


def downgrade() -> None:
    op.create_table(
        "sys_craft_default_template_source",
        sa.Column("id", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("source_template_id", sa.Integer(), nullable=True),
        sa.Column("updated_by_user_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("id = 1", name=op.f("ck_sys_craft_default_template_source_singleton_id_eq_1")),
        sa.ForeignKeyConstraint(
            ["source_template_id"],
            ["mes_product_process_template.id"],
            name=op.f("fk_sys_craft_default_template_source_source_template_id_mes_product_process_template"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["updated_by_user_id"],
            ["sys_user.id"],
            name=op.f("fk_sys_craft_default_template_source_updated_by_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_craft_default_template_source")),
    )
    op.create_index(
        op.f("ix_sys_craft_default_template_source_id"),
        "sys_craft_default_template_source",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_default_template_source_source_template_id"),
        "sys_craft_default_template_source",
        ["source_template_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_craft_default_template_source_updated_by_user_id"),
        "sys_craft_default_template_source",
        ["updated_by_user_id"],
        unique=False,
    )

    op.drop_index(
        op.f("ix_sys_craft_system_master_template_step_process_code"),
        table_name="sys_craft_system_master_template_step",
    )
    op.drop_index(
        op.f("ix_sys_craft_system_master_template_step_process_id"),
        table_name="sys_craft_system_master_template_step",
    )
    op.drop_index(
        op.f("ix_sys_craft_system_master_template_step_stage_code"),
        table_name="sys_craft_system_master_template_step",
    )
    op.drop_index(
        op.f("ix_sys_craft_system_master_template_step_stage_id"),
        table_name="sys_craft_system_master_template_step",
    )
    op.drop_index(
        op.f("ix_sys_craft_system_master_template_step_template_id"),
        table_name="sys_craft_system_master_template_step",
    )
    op.drop_index(
        op.f("ix_sys_craft_system_master_template_step_id"),
        table_name="sys_craft_system_master_template_step",
    )
    op.drop_table("sys_craft_system_master_template_step")

    op.drop_index(
        op.f("ix_sys_craft_system_master_template_updated_by_user_id"),
        table_name="sys_craft_system_master_template",
    )
    op.drop_index(
        op.f("ix_sys_craft_system_master_template_created_by_user_id"),
        table_name="sys_craft_system_master_template",
    )
    op.drop_index(
        op.f("ix_sys_craft_system_master_template_id"),
        table_name="sys_craft_system_master_template",
    )
    op.drop_table("sys_craft_system_master_template")

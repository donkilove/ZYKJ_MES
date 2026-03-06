"""reconcile system master template schema

Revision ID: c4f7d9e2a1b3
Revises: b1a2c3d4e5f6
Create Date: 2026-03-06 13:20:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "c4f7d9e2a1b3"
down_revision: Union[str, Sequence[str], None] = "b1a2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_exists(inspector: sa.Inspector, table_name: str) -> bool:
    return table_name in inspector.get_table_names(schema="public")


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not _table_exists(inspector, "sys_craft_system_master_template"):
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

    inspector = sa.inspect(bind)
    if not _table_exists(inspector, "sys_craft_system_master_template_step"):
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

    inspector = sa.inspect(bind)
    if _table_exists(inspector, "sys_craft_default_template_source"):
        op.drop_table("sys_craft_default_template_source")


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not _table_exists(inspector, "sys_craft_default_template_source"):
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

    inspector = sa.inspect(bind)
    if _table_exists(inspector, "sys_craft_system_master_template_step"):
        op.drop_table("sys_craft_system_master_template_step")
    inspector = sa.inspect(bind)
    if _table_exists(inspector, "sys_craft_system_master_template"):
        op.drop_table("sys_craft_system_master_template")

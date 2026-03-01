"""add equipment module tables

Revision ID: b7c8d9e0f1a2
Revises: f6a1d2c3b4e5
Create Date: 2026-03-01 22:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b7c8d9e0f1a2"
down_revision: Union[str, Sequence[str], None] = "f6a1d2c3b4e5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "mes_equipment",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("model", sa.String(length=128), nullable=False, server_default=sa.text("''")),
        sa.Column("location", sa.String(length=255), nullable=False, server_default=sa.text("''")),
        sa.Column("owner_name", sa.String(length=64), nullable=False, server_default=sa.text("''")),
        sa.Column(
            "is_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_equipment")),
        sa.UniqueConstraint("name", name=op.f("uq_mes_equipment_name")),
    )
    op.create_index(op.f("ix_mes_equipment_id"), "mes_equipment", ["id"], unique=False)
    op.create_index(op.f("ix_mes_equipment_name"), "mes_equipment", ["name"], unique=False)
    op.create_index(op.f("ix_mes_equipment_is_enabled"), "mes_equipment", ["is_enabled"], unique=False)

    op.create_table(
        "mes_maintenance_item",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("category", sa.String(length=64), nullable=False, server_default=sa.text("''")),
        sa.Column(
            "default_cycle_days",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("30"),
        ),
        sa.Column(
            "default_duration_minutes",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("60"),
        ),
        sa.Column(
            "is_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("default_cycle_days > 0", name="ck_mes_maintenance_item_cycle_days_positive"),
        sa.CheckConstraint(
            "default_duration_minutes > 0",
            name="ck_mes_maintenance_item_duration_positive",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_maintenance_item")),
        sa.UniqueConstraint("name", name=op.f("uq_mes_maintenance_item_name")),
    )
    op.create_index(op.f("ix_mes_maintenance_item_id"), "mes_maintenance_item", ["id"], unique=False)
    op.create_index(op.f("ix_mes_maintenance_item_name"), "mes_maintenance_item", ["name"], unique=False)
    op.create_index(
        op.f("ix_mes_maintenance_item_is_enabled"),
        "mes_maintenance_item",
        ["is_enabled"],
        unique=False,
    )

    op.create_table(
        "mes_maintenance_plan",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("equipment_id", sa.Integer(), nullable=False),
        sa.Column("item_id", sa.Integer(), nullable=False),
        sa.Column("cycle_days", sa.Integer(), nullable=False, server_default=sa.text("30")),
        sa.Column("estimated_duration_minutes", sa.Integer(), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("next_due_date", sa.Date(), nullable=False),
        sa.Column("default_executor_user_id", sa.Integer(), nullable=True),
        sa.Column(
            "is_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("cycle_days > 0", name="ck_mes_maintenance_plan_cycle_days_positive"),
        sa.CheckConstraint(
            "estimated_duration_minutes IS NULL OR estimated_duration_minutes > 0",
            name="ck_mes_maintenance_plan_duration_positive",
        ),
        sa.ForeignKeyConstraint(
            ["default_executor_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_maintenance_plan_default_executor_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["equipment_id"],
            ["mes_equipment.id"],
            name=op.f("fk_mes_maintenance_plan_equipment_id_mes_equipment"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["item_id"],
            ["mes_maintenance_item.id"],
            name=op.f("fk_mes_maintenance_plan_item_id_mes_maintenance_item"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_maintenance_plan")),
        sa.UniqueConstraint(
            "equipment_id",
            "item_id",
            name="uq_mes_maintenance_plan_equipment_id_item_id",
        ),
    )
    op.create_index(op.f("ix_mes_maintenance_plan_id"), "mes_maintenance_plan", ["id"], unique=False)
    op.create_index(
        op.f("ix_mes_maintenance_plan_equipment_id"),
        "mes_maintenance_plan",
        ["equipment_id"],
        unique=False,
    )
    op.create_index(op.f("ix_mes_maintenance_plan_item_id"), "mes_maintenance_plan", ["item_id"], unique=False)
    op.create_index(
        op.f("ix_mes_maintenance_plan_default_executor_user_id"),
        "mes_maintenance_plan",
        ["default_executor_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_plan_is_enabled"),
        "mes_maintenance_plan",
        ["is_enabled"],
        unique=False,
    )

    op.create_table(
        "mes_maintenance_work_order",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("plan_id", sa.Integer(), nullable=False),
        sa.Column("equipment_id", sa.Integer(), nullable=False),
        sa.Column("item_id", sa.Integer(), nullable=False),
        sa.Column("due_date", sa.Date(), nullable=False),
        sa.Column(
            "status",
            sa.String(length=16),
            nullable=False,
            server_default=sa.text("'pending'"),
        ),
        sa.Column("executor_user_id", sa.Integer(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("result_summary", sa.String(length=255), nullable=True),
        sa.Column("result_remark", sa.String(length=1024), nullable=True),
        sa.Column("attachment_link", sa.String(length=1024), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "status IN ('pending', 'in_progress', 'done', 'overdue', 'cancelled')",
            name="ck_mes_maintenance_work_order_status_allowed",
        ),
        sa.ForeignKeyConstraint(
            ["equipment_id"],
            ["mes_equipment.id"],
            name=op.f("fk_mes_maintenance_work_order_equipment_id_mes_equipment"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["executor_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_maintenance_work_order_executor_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["item_id"],
            ["mes_maintenance_item.id"],
            name=op.f("fk_mes_maintenance_work_order_item_id_mes_maintenance_item"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["plan_id"],
            ["mes_maintenance_plan.id"],
            name=op.f("fk_mes_maintenance_work_order_plan_id_mes_maintenance_plan"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_maintenance_work_order")),
        sa.UniqueConstraint(
            "plan_id",
            "due_date",
            name="uq_mes_maintenance_work_order_plan_id_due_date",
        ),
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_id"),
        "mes_maintenance_work_order",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_plan_id"),
        "mes_maintenance_work_order",
        ["plan_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_equipment_id"),
        "mes_maintenance_work_order",
        ["equipment_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_item_id"),
        "mes_maintenance_work_order",
        ["item_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_due_date"),
        "mes_maintenance_work_order",
        ["due_date"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_status"),
        "mes_maintenance_work_order",
        ["status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_executor_user_id"),
        "mes_maintenance_work_order",
        ["executor_user_id"],
        unique=False,
    )

    op.alter_column("mes_equipment", "model", server_default=None)
    op.alter_column("mes_equipment", "location", server_default=None)
    op.alter_column("mes_equipment", "owner_name", server_default=None)
    op.alter_column("mes_maintenance_item", "category", server_default=None)
    op.alter_column("mes_maintenance_item", "default_cycle_days", server_default=None)
    op.alter_column("mes_maintenance_item", "default_duration_minutes", server_default=None)
    op.alter_column("mes_maintenance_plan", "cycle_days", server_default=None)
    op.alter_column("mes_maintenance_work_order", "status", server_default=None)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_mes_maintenance_work_order_executor_user_id"), table_name="mes_maintenance_work_order")
    op.drop_index(op.f("ix_mes_maintenance_work_order_status"), table_name="mes_maintenance_work_order")
    op.drop_index(op.f("ix_mes_maintenance_work_order_due_date"), table_name="mes_maintenance_work_order")
    op.drop_index(op.f("ix_mes_maintenance_work_order_item_id"), table_name="mes_maintenance_work_order")
    op.drop_index(op.f("ix_mes_maintenance_work_order_equipment_id"), table_name="mes_maintenance_work_order")
    op.drop_index(op.f("ix_mes_maintenance_work_order_plan_id"), table_name="mes_maintenance_work_order")
    op.drop_index(op.f("ix_mes_maintenance_work_order_id"), table_name="mes_maintenance_work_order")
    op.drop_table("mes_maintenance_work_order")

    op.drop_index(op.f("ix_mes_maintenance_plan_is_enabled"), table_name="mes_maintenance_plan")
    op.drop_index(op.f("ix_mes_maintenance_plan_default_executor_user_id"), table_name="mes_maintenance_plan")
    op.drop_index(op.f("ix_mes_maintenance_plan_item_id"), table_name="mes_maintenance_plan")
    op.drop_index(op.f("ix_mes_maintenance_plan_equipment_id"), table_name="mes_maintenance_plan")
    op.drop_index(op.f("ix_mes_maintenance_plan_id"), table_name="mes_maintenance_plan")
    op.drop_table("mes_maintenance_plan")

    op.drop_index(op.f("ix_mes_maintenance_item_is_enabled"), table_name="mes_maintenance_item")
    op.drop_index(op.f("ix_mes_maintenance_item_name"), table_name="mes_maintenance_item")
    op.drop_index(op.f("ix_mes_maintenance_item_id"), table_name="mes_maintenance_item")
    op.drop_table("mes_maintenance_item")

    op.drop_index(op.f("ix_mes_equipment_is_enabled"), table_name="mes_equipment")
    op.drop_index(op.f("ix_mes_equipment_name"), table_name="mes_equipment")
    op.drop_index(op.f("ix_mes_equipment_id"), table_name="mes_equipment")
    op.drop_table("mes_equipment")

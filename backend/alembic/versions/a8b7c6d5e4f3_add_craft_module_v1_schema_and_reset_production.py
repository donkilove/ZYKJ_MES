"""add craft module v1 schema and reset production domain

Revision ID: a8b7c6d5e4f3
Revises: 4d2f8a7b9c31
Create Date: 2026-03-04 21:10:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "a8b7c6d5e4f3"
down_revision: Union[str, Sequence[str], None] = "4d2f8a7b9c31"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mes_process_stage",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_process_stage")),
    )
    op.create_index(op.f("ix_mes_process_stage_code"), "mes_process_stage", ["code"], unique=True)
    op.create_index(op.f("ix_mes_process_stage_sort_order"), "mes_process_stage", ["sort_order"], unique=False)

    op.add_column("mes_process", sa.Column("stage_id", sa.Integer(), nullable=True))
    op.add_column(
        "mes_process",
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )
    op.create_index(op.f("ix_mes_process_stage_id"), "mes_process", ["stage_id"], unique=False)
    op.create_index(op.f("ix_mes_process_is_enabled"), "mes_process", ["is_enabled"], unique=False)
    op.create_foreign_key(
        op.f("fk_mes_process_stage_id_mes_process_stage"),
        "mes_process",
        "mes_process_stage",
        ["stage_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.execute("ALTER TABLE mes_process DROP CONSTRAINT IF EXISTS uq_mes_process_name")

    op.create_table(
        "mes_product_process_template",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("product_id", sa.Integer(), nullable=False),
        sa.Column("template_name", sa.String(length=128), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
        sa.Column("updated_by_user_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["mes_product.id"],
            name=op.f("fk_mes_product_process_template_product_id_mes_product"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_product_process_template_created_by_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["updated_by_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_product_process_template_updated_by_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_product_process_template")),
        sa.UniqueConstraint(
            "product_id",
            "template_name",
            "version",
            name="uq_mes_pp_template_pid_tname_ver",
        ),
    )
    op.create_index(
        op.f("ix_mes_product_process_template_id"),
        "mes_product_process_template",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_product_id"),
        "mes_product_process_template",
        ["product_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_is_default"),
        "mes_product_process_template",
        ["is_default"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_is_enabled"),
        "mes_product_process_template",
        ["is_enabled"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_created_by_user_id"),
        "mes_product_process_template",
        ["created_by_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_updated_by_user_id"),
        "mes_product_process_template",
        ["updated_by_user_id"],
        unique=False,
    )

    op.create_table(
        "mes_product_process_template_step",
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
            ["mes_product_process_template.id"],
            name="fk_mes_pp_step_template_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["stage_id"],
            ["mes_process_stage.id"],
            name=op.f("fk_mes_product_process_template_step_stage_id_mes_process_stage"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["process_id"],
            ["mes_process.id"],
            name=op.f("fk_mes_product_process_template_step_process_id_mes_process"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_product_process_template_step")),
        sa.UniqueConstraint(
            "template_id",
            "step_order",
            name="uq_mes_product_process_template_step_template_id_step_order",
        ),
    )
    op.create_index(
        op.f("ix_mes_product_process_template_step_id"),
        "mes_product_process_template_step",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_step_template_id"),
        "mes_product_process_template_step",
        ["template_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_step_stage_id"),
        "mes_product_process_template_step",
        ["stage_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_step_stage_code"),
        "mes_product_process_template_step",
        ["stage_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_step_process_id"),
        "mes_product_process_template_step",
        ["process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_step_process_code"),
        "mes_product_process_template_step",
        ["process_code"],
        unique=False,
    )

    op.add_column("mes_order", sa.Column("process_template_id", sa.Integer(), nullable=True))
    op.add_column("mes_order", sa.Column("process_template_name", sa.String(length=128), nullable=True))
    op.add_column("mes_order", sa.Column("process_template_version", sa.Integer(), nullable=True))
    op.create_index(op.f("ix_mes_order_process_template_id"), "mes_order", ["process_template_id"], unique=False)
    op.create_foreign_key(
        op.f("fk_mes_order_process_template_id_mes_product_process_template"),
        "mes_order",
        "mes_product_process_template",
        ["process_template_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.add_column("mes_order_process", sa.Column("stage_id", sa.Integer(), nullable=True))
    op.add_column("mes_order_process", sa.Column("stage_code", sa.String(length=64), nullable=True))
    op.add_column("mes_order_process", sa.Column("stage_name", sa.String(length=128), nullable=True))
    op.create_index(op.f("ix_mes_order_process_stage_id"), "mes_order_process", ["stage_id"], unique=False)
    op.create_index(op.f("ix_mes_order_process_stage_code"), "mes_order_process", ["stage_code"], unique=False)
    op.create_foreign_key(
        op.f("fk_mes_order_process_stage_id_mes_process_stage"),
        "mes_order_process",
        "mes_process_stage",
        ["stage_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.drop_constraint(
        "uq_mes_order_process_order_id_process_code",
        "mes_order_process",
        type_="unique",
    )

    op.execute("ALTER TABLE mes_maintenance_plan DROP CONSTRAINT IF EXISTS ck_mes_maintenance_plan_execution_process_code_allowed")

    op.execute(
        """
        UPDATE mes_maintenance_plan
        SET execution_process_code = CASE
            WHEN execution_process_code IN ('laser_marking_fiber', 'laser_marking_uv', 'laser_marking_auto_fiber') THEN 'laser_marking'
            WHEN execution_process_code LIKE 'product_testing%' THEN 'product_testing'
            WHEN execution_process_code LIKE 'product_assembly%' THEN 'product_assembly'
            WHEN execution_process_code LIKE 'product_packaging%' THEN 'product_packaging'
            ELSE execution_process_code
        END
        """
    )
    op.execute(
        """
        UPDATE mes_maintenance_work_order
        SET source_execution_process_code = CASE
            WHEN source_execution_process_code IN ('laser_marking_fiber', 'laser_marking_uv', 'laser_marking_auto_fiber') THEN 'laser_marking'
            WHEN source_execution_process_code LIKE 'product_testing%' THEN 'product_testing'
            WHEN source_execution_process_code LIKE 'product_assembly%' THEN 'product_assembly'
            WHEN source_execution_process_code LIKE 'product_packaging%' THEN 'product_packaging'
            ELSE source_execution_process_code
        END
        """
    )

    op.execute(
        """
        UPDATE mes_maintenance_plan
        SET execution_process_code = 'laser_marking'
        WHERE execution_process_code IS NULL OR TRIM(execution_process_code) = ''
        """
    )
    op.execute(
        """
        UPDATE mes_maintenance_work_order
        SET source_execution_process_code = 'laser_marking'
        WHERE source_execution_process_code IS NULL OR TRIM(source_execution_process_code) = ''
        """
    )

    op.execute(
        """
        TRUNCATE TABLE
            mes_production_record,
            mes_first_article_record,
            mes_order_event_log,
            mes_order_sub_order,
            mes_order_process,
            mes_order,
            mes_daily_verification_code,
            sys_user_process,
            mes_product_process_template_step,
            mes_product_process_template,
            mes_process,
            mes_process_stage
        RESTART IDENTITY CASCADE
        """
    )
def downgrade() -> None:
    op.execute(
        """
        TRUNCATE TABLE
            mes_production_record,
            mes_first_article_record,
            mes_order_event_log,
            mes_order_sub_order,
            mes_order_process,
            mes_order,
            mes_daily_verification_code,
            sys_user_process,
            mes_product_process_template_step,
            mes_product_process_template,
            mes_process,
            mes_process_stage
        RESTART IDENTITY CASCADE
        """
    )

    op.execute(
        """
        UPDATE mes_maintenance_plan
        SET execution_process_code = 'laser_marking'
        WHERE execution_process_code IS NULL
           OR TRIM(execution_process_code) = ''
           OR execution_process_code NOT IN ('laser_marking', 'product_testing', 'product_assembly', 'product_packaging')
        """
    )
    op.execute(
        """
        UPDATE mes_maintenance_work_order
        SET source_execution_process_code = 'laser_marking'
        WHERE source_execution_process_code IS NULL
           OR TRIM(source_execution_process_code) = ''
           OR source_execution_process_code NOT IN ('laser_marking', 'product_testing', 'product_assembly', 'product_packaging')
        """
    )

    op.create_check_constraint(
        "ck_mes_maintenance_plan_execution_process_code_allowed",
        "mes_maintenance_plan",
        "execution_process_code IN ('laser_marking', 'product_testing', 'product_assembly', 'product_packaging')",
    )

    op.create_unique_constraint(
        "uq_mes_order_process_order_id_process_code",
        "mes_order_process",
        ["order_id", "process_code"],
    )
    op.drop_constraint(op.f("fk_mes_order_process_stage_id_mes_process_stage"), "mes_order_process", type_="foreignkey")
    op.drop_index(op.f("ix_mes_order_process_stage_code"), table_name="mes_order_process")
    op.drop_index(op.f("ix_mes_order_process_stage_id"), table_name="mes_order_process")
    op.drop_column("mes_order_process", "stage_name")
    op.drop_column("mes_order_process", "stage_code")
    op.drop_column("mes_order_process", "stage_id")

    op.drop_constraint(op.f("fk_mes_order_process_template_id_mes_product_process_template"), "mes_order", type_="foreignkey")
    op.drop_index(op.f("ix_mes_order_process_template_id"), table_name="mes_order")
    op.drop_column("mes_order", "process_template_version")
    op.drop_column("mes_order", "process_template_name")
    op.drop_column("mes_order", "process_template_id")

    op.drop_index(op.f("ix_mes_product_process_template_step_process_code"), table_name="mes_product_process_template_step")
    op.drop_index(op.f("ix_mes_product_process_template_step_process_id"), table_name="mes_product_process_template_step")
    op.drop_index(op.f("ix_mes_product_process_template_step_stage_code"), table_name="mes_product_process_template_step")
    op.drop_index(op.f("ix_mes_product_process_template_step_stage_id"), table_name="mes_product_process_template_step")
    op.drop_index(op.f("ix_mes_product_process_template_step_template_id"), table_name="mes_product_process_template_step")
    op.drop_index(op.f("ix_mes_product_process_template_step_id"), table_name="mes_product_process_template_step")
    op.drop_table("mes_product_process_template_step")

    op.drop_index(op.f("ix_mes_product_process_template_updated_by_user_id"), table_name="mes_product_process_template")
    op.drop_index(op.f("ix_mes_product_process_template_created_by_user_id"), table_name="mes_product_process_template")
    op.drop_index(op.f("ix_mes_product_process_template_is_enabled"), table_name="mes_product_process_template")
    op.drop_index(op.f("ix_mes_product_process_template_is_default"), table_name="mes_product_process_template")
    op.drop_index(op.f("ix_mes_product_process_template_product_id"), table_name="mes_product_process_template")
    op.drop_index(op.f("ix_mes_product_process_template_id"), table_name="mes_product_process_template")
    op.drop_table("mes_product_process_template")

    op.drop_constraint(op.f("fk_mes_process_stage_id_mes_process_stage"), "mes_process", type_="foreignkey")
    op.drop_index(op.f("ix_mes_process_is_enabled"), table_name="mes_process")
    op.drop_index(op.f("ix_mes_process_stage_id"), table_name="mes_process")
    op.drop_column("mes_process", "is_enabled")
    op.drop_column("mes_process", "stage_id")
    op.create_unique_constraint(op.f("uq_mes_process_name"), "mes_process", ["name"])

    op.drop_index(op.f("ix_mes_process_stage_sort_order"), table_name="mes_process_stage")
    op.drop_index(op.f("ix_mes_process_stage_code"), table_name="mes_process_stage")
    op.drop_table("mes_process_stage")

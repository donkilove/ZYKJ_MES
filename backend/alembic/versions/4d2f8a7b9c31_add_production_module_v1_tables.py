"""add production module v1 tables

Revision ID: 4d2f8a7b9c31
Revises: f94b1c2d3e45
Create Date: 2026-03-04 19:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "4d2f8a7b9c31"
down_revision: Union[str, Sequence[str], None] = "f94b1c2d3e45"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "mes_order",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_code", sa.String(length=64), nullable=False),
        sa.Column("product_id", sa.Integer(), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("status", sa.String(length=32), nullable=False, server_default=sa.text("'pending'")),
        sa.Column("current_process_code", sa.String(length=64), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=True),
        sa.Column("due_date", sa.Date(), nullable=True),
        sa.Column("remark", sa.Text(), nullable=True),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("quantity >= 0", name="ck_mes_order_quantity_non_negative"),
        sa.CheckConstraint(
            "status IN ('pending', 'in_progress', 'completed')",
            name="ck_mes_order_status_allowed",
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_order_created_by_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["mes_product.id"],
            name=op.f("fk_mes_order_product_id_mes_product"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_order")),
    )
    op.create_index(op.f("ix_mes_order_id"), "mes_order", ["id"], unique=False)
    op.create_index(op.f("ix_mes_order_order_code"), "mes_order", ["order_code"], unique=True)
    op.create_index(op.f("ix_mes_order_status"), "mes_order", ["status"], unique=False)
    op.create_index(
        op.f("ix_mes_order_created_by_user_id"),
        "mes_order",
        ["created_by_user_id"],
        unique=False,
    )

    op.create_table(
        "mes_order_process",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("process_id", sa.Integer(), nullable=False),
        sa.Column("process_code", sa.String(length=64), nullable=False),
        sa.Column("process_name", sa.String(length=128), nullable=False),
        sa.Column("process_order", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False, server_default=sa.text("'pending'")),
        sa.Column("visible_quantity", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("completed_quantity", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("process_order > 0", name="ck_mes_order_process_process_order_positive"),
        sa.CheckConstraint("visible_quantity >= 0", name="ck_mes_order_process_visible_quantity_non_negative"),
        sa.CheckConstraint("completed_quantity >= 0", name="ck_mes_order_process_completed_quantity_non_negative"),
        sa.CheckConstraint(
            "status IN ('pending', 'in_progress', 'partial', 'completed')",
            name="ck_mes_order_process_status_allowed",
        ),
        sa.ForeignKeyConstraint(
            ["order_id"],
            ["mes_order.id"],
            name=op.f("fk_mes_order_process_order_id_mes_order"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["process_id"],
            ["mes_process.id"],
            name=op.f("fk_mes_order_process_process_id_mes_process"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_order_process")),
        sa.UniqueConstraint(
            "order_id",
            "process_order",
            name="uq_mes_order_process_order_id_process_order",
        ),
        sa.UniqueConstraint(
            "order_id",
            "process_code",
            name="uq_mes_order_process_order_id_process_code",
        ),
    )
    op.create_index(op.f("ix_mes_order_process_id"), "mes_order_process", ["id"], unique=False)
    op.create_index(op.f("ix_mes_order_process_order_id"), "mes_order_process", ["order_id"], unique=False)
    op.create_index(op.f("ix_mes_order_process_process_id"), "mes_order_process", ["process_id"], unique=False)
    op.create_index(
        op.f("ix_mes_order_process_process_code"),
        "mes_order_process",
        ["process_code"],
        unique=False,
    )
    op.create_index(op.f("ix_mes_order_process_status"), "mes_order_process", ["status"], unique=False)

    op.create_table(
        "mes_order_sub_order",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_process_id", sa.Integer(), nullable=False),
        sa.Column("operator_user_id", sa.Integer(), nullable=False),
        sa.Column("assigned_quantity", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("completed_quantity", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("status", sa.String(length=32), nullable=False, server_default=sa.text("'pending'")),
        sa.Column("is_visible", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("assigned_quantity >= 0", name="ck_mes_order_sub_order_assigned_quantity_non_negative"),
        sa.CheckConstraint("completed_quantity >= 0", name="ck_mes_order_sub_order_completed_quantity_non_negative"),
        sa.CheckConstraint(
            "status IN ('pending', 'in_progress', 'done')",
            name="ck_mes_order_sub_order_status_allowed",
        ),
        sa.ForeignKeyConstraint(
            ["order_process_id"],
            ["mes_order_process.id"],
            name=op.f("fk_mes_order_sub_order_order_process_id_mes_order_process"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_order_sub_order_operator_user_id_sys_user"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_order_sub_order")),
        sa.UniqueConstraint(
            "order_process_id",
            "operator_user_id",
            name="uq_mes_order_sub_order_order_process_id_operator_user_id",
        ),
    )
    op.create_index(op.f("ix_mes_order_sub_order_id"), "mes_order_sub_order", ["id"], unique=False)
    op.create_index(
        op.f("ix_mes_order_sub_order_order_process_id"),
        "mes_order_sub_order",
        ["order_process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_order_sub_order_operator_user_id"),
        "mes_order_sub_order",
        ["operator_user_id"],
        unique=False,
    )
    op.create_index(op.f("ix_mes_order_sub_order_status"), "mes_order_sub_order", ["status"], unique=False)

    op.create_table(
        "mes_daily_verification_code",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("verify_date", sa.Date(), nullable=False),
        sa.Column("code", sa.String(length=32), nullable=False),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_daily_verification_code_created_by_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_daily_verification_code")),
    )
    op.create_index(
        op.f("ix_mes_daily_verification_code_id"),
        "mes_daily_verification_code",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_daily_verification_code_verify_date"),
        "mes_daily_verification_code",
        ["verify_date"],
        unique=True,
    )
    op.create_index(
        op.f("ix_mes_daily_verification_code_created_by_user_id"),
        "mes_daily_verification_code",
        ["created_by_user_id"],
        unique=False,
    )

    op.create_table(
        "mes_first_article_record",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("order_process_id", sa.Integer(), nullable=False),
        sa.Column("operator_user_id", sa.Integer(), nullable=False),
        sa.Column("verification_date", sa.Date(), nullable=False),
        sa.Column("verification_code", sa.String(length=32), nullable=False),
        sa.Column("result", sa.String(length=32), nullable=False, server_default=sa.text("'passed'")),
        sa.Column("remark", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("result IN ('passed', 'failed')", name="ck_mes_first_article_record_result_allowed"),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_first_article_record_operator_user_id_sys_user"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["order_id"],
            ["mes_order.id"],
            name=op.f("fk_mes_first_article_record_order_id_mes_order"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["order_process_id"],
            ["mes_order_process.id"],
            name=op.f("fk_mes_first_article_record_order_process_id_mes_order_process"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_first_article_record")),
    )
    op.create_index(op.f("ix_mes_first_article_record_id"), "mes_first_article_record", ["id"], unique=False)
    op.create_index(
        op.f("ix_mes_first_article_record_order_id"),
        "mes_first_article_record",
        ["order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_first_article_record_order_process_id"),
        "mes_first_article_record",
        ["order_process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_first_article_record_operator_user_id"),
        "mes_first_article_record",
        ["operator_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_first_article_record_verification_date"),
        "mes_first_article_record",
        ["verification_date"],
        unique=False,
    )

    op.create_table(
        "mes_production_record",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("order_process_id", sa.Integer(), nullable=False),
        sa.Column("sub_order_id", sa.Integer(), nullable=True),
        sa.Column("operator_user_id", sa.Integer(), nullable=False),
        sa.Column("production_quantity", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("record_type", sa.String(length=32), nullable=False, server_default=sa.text("'production'")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("production_quantity >= 0", name="ck_mes_production_record_quantity_non_negative"),
        sa.CheckConstraint(
            "record_type IN ('first_article', 'production')",
            name="ck_mes_production_record_record_type_allowed",
        ),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_production_record_operator_user_id_sys_user"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["order_id"],
            ["mes_order.id"],
            name=op.f("fk_mes_production_record_order_id_mes_order"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["order_process_id"],
            ["mes_order_process.id"],
            name=op.f("fk_mes_production_record_order_process_id_mes_order_process"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["sub_order_id"],
            ["mes_order_sub_order.id"],
            name=op.f("fk_mes_production_record_sub_order_id_mes_order_sub_order"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_production_record")),
    )
    op.create_index(op.f("ix_mes_production_record_id"), "mes_production_record", ["id"], unique=False)
    op.create_index(
        op.f("ix_mes_production_record_order_id"),
        "mes_production_record",
        ["order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_record_order_process_id"),
        "mes_production_record",
        ["order_process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_record_sub_order_id"),
        "mes_production_record",
        ["sub_order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_record_operator_user_id"),
        "mes_production_record",
        ["operator_user_id"],
        unique=False,
    )

    op.create_table(
        "mes_order_event_log",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("event_title", sa.String(length=255), nullable=False),
        sa.Column("event_detail", sa.Text(), nullable=True),
        sa.Column("operator_user_id", sa.Integer(), nullable=True),
        sa.Column("payload_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_order_event_log_operator_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["order_id"],
            ["mes_order.id"],
            name=op.f("fk_mes_order_event_log_order_id_mes_order"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_order_event_log")),
    )
    op.create_index(op.f("ix_mes_order_event_log_id"), "mes_order_event_log", ["id"], unique=False)
    op.create_index(
        op.f("ix_mes_order_event_log_order_id"),
        "mes_order_event_log",
        ["order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_order_event_log_event_type"),
        "mes_order_event_log",
        ["event_type"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_order_event_log_operator_user_id"),
        "mes_order_event_log",
        ["operator_user_id"],
        unique=False,
    )

    op.alter_column("mes_order", "quantity", server_default=None)
    op.alter_column("mes_order", "status", server_default=None)
    op.alter_column("mes_order_process", "status", server_default=None)
    op.alter_column("mes_order_process", "visible_quantity", server_default=None)
    op.alter_column("mes_order_process", "completed_quantity", server_default=None)
    op.alter_column("mes_order_sub_order", "assigned_quantity", server_default=None)
    op.alter_column("mes_order_sub_order", "completed_quantity", server_default=None)
    op.alter_column("mes_order_sub_order", "status", server_default=None)
    op.alter_column("mes_first_article_record", "result", server_default=None)
    op.alter_column("mes_production_record", "production_quantity", server_default=None)
    op.alter_column("mes_production_record", "record_type", server_default=None)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_mes_order_event_log_operator_user_id"), table_name="mes_order_event_log")
    op.drop_index(op.f("ix_mes_order_event_log_event_type"), table_name="mes_order_event_log")
    op.drop_index(op.f("ix_mes_order_event_log_order_id"), table_name="mes_order_event_log")
    op.drop_index(op.f("ix_mes_order_event_log_id"), table_name="mes_order_event_log")
    op.drop_table("mes_order_event_log")

    op.drop_index(op.f("ix_mes_production_record_operator_user_id"), table_name="mes_production_record")
    op.drop_index(op.f("ix_mes_production_record_sub_order_id"), table_name="mes_production_record")
    op.drop_index(op.f("ix_mes_production_record_order_process_id"), table_name="mes_production_record")
    op.drop_index(op.f("ix_mes_production_record_order_id"), table_name="mes_production_record")
    op.drop_index(op.f("ix_mes_production_record_id"), table_name="mes_production_record")
    op.drop_table("mes_production_record")

    op.drop_index(op.f("ix_mes_first_article_record_verification_date"), table_name="mes_first_article_record")
    op.drop_index(op.f("ix_mes_first_article_record_operator_user_id"), table_name="mes_first_article_record")
    op.drop_index(op.f("ix_mes_first_article_record_order_process_id"), table_name="mes_first_article_record")
    op.drop_index(op.f("ix_mes_first_article_record_order_id"), table_name="mes_first_article_record")
    op.drop_index(op.f("ix_mes_first_article_record_id"), table_name="mes_first_article_record")
    op.drop_table("mes_first_article_record")

    op.drop_index(
        op.f("ix_mes_daily_verification_code_created_by_user_id"),
        table_name="mes_daily_verification_code",
    )
    op.drop_index(op.f("ix_mes_daily_verification_code_verify_date"), table_name="mes_daily_verification_code")
    op.drop_index(op.f("ix_mes_daily_verification_code_id"), table_name="mes_daily_verification_code")
    op.drop_table("mes_daily_verification_code")

    op.drop_index(op.f("ix_mes_order_sub_order_status"), table_name="mes_order_sub_order")
    op.drop_index(op.f("ix_mes_order_sub_order_operator_user_id"), table_name="mes_order_sub_order")
    op.drop_index(op.f("ix_mes_order_sub_order_order_process_id"), table_name="mes_order_sub_order")
    op.drop_index(op.f("ix_mes_order_sub_order_id"), table_name="mes_order_sub_order")
    op.drop_table("mes_order_sub_order")

    op.drop_index(op.f("ix_mes_order_process_status"), table_name="mes_order_process")
    op.drop_index(op.f("ix_mes_order_process_process_code"), table_name="mes_order_process")
    op.drop_index(op.f("ix_mes_order_process_process_id"), table_name="mes_order_process")
    op.drop_index(op.f("ix_mes_order_process_order_id"), table_name="mes_order_process")
    op.drop_index(op.f("ix_mes_order_process_id"), table_name="mes_order_process")
    op.drop_table("mes_order_process")

    op.drop_index(op.f("ix_mes_order_created_by_user_id"), table_name="mes_order")
    op.drop_index(op.f("ix_mes_order_status"), table_name="mes_order")
    op.drop_index(op.f("ix_mes_order_order_code"), table_name="mes_order")
    op.drop_index(op.f("ix_mes_order_id"), table_name="mes_order")
    op.drop_table("mes_order")

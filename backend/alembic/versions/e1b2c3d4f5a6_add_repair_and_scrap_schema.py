"""add repair and scrap schema for production batch d

Revision ID: e1b2c3d4f5a6
Revises: d3a7b4c9e2f1
Create Date: 2026-03-08 22:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "e1b2c3d4f5a6"
down_revision: Union[str, Sequence[str], None] = "d3a7b4c9e2f1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "mes_repair_order",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("repair_order_code", sa.String(length=64), nullable=False),
        sa.Column("source_order_id", sa.Integer(), nullable=True),
        sa.Column("source_order_code", sa.String(length=64), nullable=True),
        sa.Column("product_id", sa.Integer(), nullable=True),
        sa.Column("product_name", sa.String(length=128), nullable=True),
        sa.Column("source_order_process_id", sa.Integer(), nullable=True),
        sa.Column("source_process_code", sa.String(length=64), nullable=False),
        sa.Column("source_process_name", sa.String(length=128), nullable=False),
        sa.Column("sender_user_id", sa.Integer(), nullable=True),
        sa.Column("sender_username", sa.String(length=128), nullable=True),
        sa.Column("production_quantity", sa.Integer(), nullable=False),
        sa.Column("repair_quantity", sa.Integer(), nullable=False),
        sa.Column("repaired_quantity", sa.Integer(), nullable=False),
        sa.Column("scrap_quantity", sa.Integer(), nullable=False),
        sa.Column("scrap_replenished", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("repair_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("repair_operator_user_id", sa.Integer(), nullable=True),
        sa.Column("repair_operator_username", sa.String(length=128), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("repair_quantity > 0", name=op.f("ck_mes_repair_order_repair_quantity_positive")),
        sa.CheckConstraint(
            "repaired_quantity >= 0",
            name=op.f("ck_mes_repair_order_repaired_quantity_non_negative"),
        ),
        sa.CheckConstraint("scrap_quantity >= 0", name=op.f("ck_mes_repair_order_scrap_quantity_non_negative")),
        sa.CheckConstraint(
            "status IN ('in_repair', 'completed')",
            name=op.f("ck_mes_repair_order_status_allowed"),
        ),
        sa.ForeignKeyConstraint(
            ["repair_operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_repair_order_repair_operator_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["sender_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_repair_order_sender_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["source_order_id"],
            ["mes_order.id"],
            name=op.f("fk_mes_repair_order_source_order_id_mes_order"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["mes_product.id"],
            name=op.f("fk_mes_repair_order_product_id_mes_product"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["source_order_process_id"],
            ["mes_order_process.id"],
            name=op.f("fk_mes_repair_order_source_order_process_id_mes_order_process"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_repair_order")),
        sa.UniqueConstraint("repair_order_code", name=op.f("uq_mes_repair_order_repair_order_code")),
    )
    op.create_index(op.f("ix_mes_repair_order_id"), "mes_repair_order", ["id"], unique=False)
    op.create_index(
        op.f("ix_mes_repair_order_repair_order_code"),
        "mes_repair_order",
        ["repair_order_code"],
        unique=True,
    )
    op.create_index(op.f("ix_mes_repair_order_source_order_id"), "mes_repair_order", ["source_order_id"], unique=False)
    op.create_index(
        op.f("ix_mes_repair_order_source_order_code"),
        "mes_repair_order",
        ["source_order_code"],
        unique=False,
    )
    op.create_index(op.f("ix_mes_repair_order_product_id"), "mes_repair_order", ["product_id"], unique=False)
    op.create_index(
        op.f("ix_mes_repair_order_source_order_process_id"),
        "mes_repair_order",
        ["source_order_process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_order_source_process_code"),
        "mes_repair_order",
        ["source_process_code"],
        unique=False,
    )
    op.create_index(op.f("ix_mes_repair_order_sender_user_id"), "mes_repair_order", ["sender_user_id"], unique=False)
    op.create_index(op.f("ix_mes_repair_order_repair_time"), "mes_repair_order", ["repair_time"], unique=False)
    op.create_index(op.f("ix_mes_repair_order_status"), "mes_repair_order", ["status"], unique=False)
    op.create_index(
        op.f("ix_mes_repair_order_repair_operator_user_id"),
        "mes_repair_order",
        ["repair_operator_user_id"],
        unique=False,
    )

    op.create_table(
        "mes_repair_defect_phenomenon",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("repair_order_id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=True),
        sa.Column("order_code", sa.String(length=64), nullable=True),
        sa.Column("product_id", sa.Integer(), nullable=True),
        sa.Column("product_name", sa.String(length=128), nullable=True),
        sa.Column("process_id", sa.Integer(), nullable=True),
        sa.Column("process_code", sa.String(length=64), nullable=True),
        sa.Column("process_name", sa.String(length=128), nullable=True),
        sa.Column("phenomenon", sa.String(length=128), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("operator_user_id", sa.Integer(), nullable=True),
        sa.Column("operator_username", sa.String(length=128), nullable=True),
        sa.Column("production_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("quantity > 0", name=op.f("ck_mes_repair_defect_phenomenon_quantity_positive")),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_repair_defect_phenomenon_operator_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["repair_order_id"],
            ["mes_repair_order.id"],
            name=op.f("fk_mes_repair_defect_phenomenon_repair_order_id_mes_repair_order"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_repair_defect_phenomenon")),
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_id"),
        "mes_repair_defect_phenomenon",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_repair_order_id"),
        "mes_repair_defect_phenomenon",
        ["repair_order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_order_id"),
        "mes_repair_defect_phenomenon",
        ["order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_product_id"),
        "mes_repair_defect_phenomenon",
        ["product_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_process_id"),
        "mes_repair_defect_phenomenon",
        ["process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_process_code"),
        "mes_repair_defect_phenomenon",
        ["process_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_phenomenon"),
        "mes_repair_defect_phenomenon",
        ["phenomenon"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_operator_user_id"),
        "mes_repair_defect_phenomenon",
        ["operator_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_defect_phenomenon_production_time"),
        "mes_repair_defect_phenomenon",
        ["production_time"],
        unique=False,
    )

    op.create_table(
        "mes_repair_cause",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("repair_order_id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=True),
        sa.Column("order_code", sa.String(length=64), nullable=True),
        sa.Column("product_id", sa.Integer(), nullable=True),
        sa.Column("product_name", sa.String(length=128), nullable=True),
        sa.Column("process_id", sa.Integer(), nullable=True),
        sa.Column("process_code", sa.String(length=64), nullable=True),
        sa.Column("process_name", sa.String(length=128), nullable=True),
        sa.Column("phenomenon", sa.String(length=128), nullable=True),
        sa.Column("reason", sa.String(length=128), nullable=False),
        sa.Column("is_scrap", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("cause_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("operator_user_id", sa.Integer(), nullable=True),
        sa.Column("operator_username", sa.String(length=128), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("quantity > 0", name=op.f("ck_mes_repair_cause_quantity_positive")),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_repair_cause_operator_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["repair_order_id"],
            ["mes_repair_order.id"],
            name=op.f("fk_mes_repair_cause_repair_order_id_mes_repair_order"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_repair_cause")),
    )
    op.create_index(op.f("ix_mes_repair_cause_id"), "mes_repair_cause", ["id"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_repair_order_id"), "mes_repair_cause", ["repair_order_id"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_order_id"), "mes_repair_cause", ["order_id"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_product_id"), "mes_repair_cause", ["product_id"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_process_id"), "mes_repair_cause", ["process_id"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_process_code"), "mes_repair_cause", ["process_code"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_phenomenon"), "mes_repair_cause", ["phenomenon"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_reason"), "mes_repair_cause", ["reason"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_is_scrap"), "mes_repair_cause", ["is_scrap"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_cause_time"), "mes_repair_cause", ["cause_time"], unique=False)
    op.create_index(op.f("ix_mes_repair_cause_operator_user_id"), "mes_repair_cause", ["operator_user_id"], unique=False)

    op.create_table(
        "mes_repair_return_route",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("repair_order_id", sa.Integer(), nullable=False),
        sa.Column("source_order_id", sa.Integer(), nullable=True),
        sa.Column("source_process_id", sa.Integer(), nullable=True),
        sa.Column("source_process_code", sa.String(length=64), nullable=False),
        sa.Column("source_process_name", sa.String(length=128), nullable=False),
        sa.Column("target_process_id", sa.Integer(), nullable=True),
        sa.Column("target_process_code", sa.String(length=64), nullable=False),
        sa.Column("target_process_name", sa.String(length=128), nullable=False),
        sa.Column("return_quantity", sa.Integer(), nullable=False),
        sa.Column("operator_user_id", sa.Integer(), nullable=True),
        sa.Column("operator_username", sa.String(length=128), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("return_quantity > 0", name=op.f("ck_mes_repair_return_route_return_quantity_positive")),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_repair_return_route_operator_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["repair_order_id"],
            ["mes_repair_order.id"],
            name=op.f("fk_mes_repair_return_route_repair_order_id_mes_repair_order"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_repair_return_route")),
    )
    op.create_index(op.f("ix_mes_repair_return_route_id"), "mes_repair_return_route", ["id"], unique=False)
    op.create_index(
        op.f("ix_mes_repair_return_route_repair_order_id"),
        "mes_repair_return_route",
        ["repair_order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_return_route_source_order_id"),
        "mes_repair_return_route",
        ["source_order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_return_route_source_process_id"),
        "mes_repair_return_route",
        ["source_process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_return_route_source_process_code"),
        "mes_repair_return_route",
        ["source_process_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_return_route_target_process_id"),
        "mes_repair_return_route",
        ["target_process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_return_route_target_process_code"),
        "mes_repair_return_route",
        ["target_process_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_repair_return_route_operator_user_id"),
        "mes_repair_return_route",
        ["operator_user_id"],
        unique=False,
    )

    op.create_table(
        "mes_production_scrap_statistics",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=True),
        sa.Column("order_code", sa.String(length=64), nullable=True),
        sa.Column("product_id", sa.Integer(), nullable=True),
        sa.Column("product_name", sa.String(length=128), nullable=True),
        sa.Column("process_id", sa.Integer(), nullable=True),
        sa.Column("process_code", sa.String(length=64), nullable=True),
        sa.Column("process_name", sa.String(length=128), nullable=True),
        sa.Column("scrap_reason", sa.String(length=128), nullable=False),
        sa.Column("scrap_quantity", sa.Integer(), nullable=False),
        sa.Column("last_scrap_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("progress", sa.String(length=32), nullable=False),
        sa.Column("applied_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "progress IN ('pending_apply', 'applied')",
            name=op.f("ck_mes_production_scrap_statistics_progress_allowed"),
        ),
        sa.CheckConstraint(
            "scrap_quantity > 0",
            name=op.f("ck_mes_production_scrap_statistics_scrap_quantity_positive"),
        ),
        sa.ForeignKeyConstraint(
            ["order_id"],
            ["mes_order.id"],
            name=op.f("fk_mes_production_scrap_statistics_order_id_mes_order"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["process_id"],
            ["mes_order_process.id"],
            name=op.f("fk_mes_production_scrap_statistics_process_id_mes_order_process"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["mes_product.id"],
            name=op.f("fk_mes_production_scrap_statistics_product_id_mes_product"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_production_scrap_statistics")),
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_id"),
        "mes_production_scrap_statistics",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_order_id"),
        "mes_production_scrap_statistics",
        ["order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_order_code"),
        "mes_production_scrap_statistics",
        ["order_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_product_id"),
        "mes_production_scrap_statistics",
        ["product_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_process_id"),
        "mes_production_scrap_statistics",
        ["process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_process_code"),
        "mes_production_scrap_statistics",
        ["process_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_scrap_reason"),
        "mes_production_scrap_statistics",
        ["scrap_reason"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_last_scrap_time"),
        "mes_production_scrap_statistics",
        ["last_scrap_time"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_production_scrap_statistics_progress"),
        "mes_production_scrap_statistics",
        ["progress"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_progress"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_last_scrap_time"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_scrap_reason"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_process_code"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_process_id"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_product_id"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_order_code"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_order_id"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_index(
        op.f("ix_mes_production_scrap_statistics_id"),
        table_name="mes_production_scrap_statistics",
    )
    op.drop_table("mes_production_scrap_statistics")

    op.drop_index(
        op.f("ix_mes_repair_return_route_operator_user_id"),
        table_name="mes_repair_return_route",
    )
    op.drop_index(
        op.f("ix_mes_repair_return_route_target_process_code"),
        table_name="mes_repair_return_route",
    )
    op.drop_index(
        op.f("ix_mes_repair_return_route_target_process_id"),
        table_name="mes_repair_return_route",
    )
    op.drop_index(
        op.f("ix_mes_repair_return_route_source_process_code"),
        table_name="mes_repair_return_route",
    )
    op.drop_index(
        op.f("ix_mes_repair_return_route_source_process_id"),
        table_name="mes_repair_return_route",
    )
    op.drop_index(
        op.f("ix_mes_repair_return_route_source_order_id"),
        table_name="mes_repair_return_route",
    )
    op.drop_index(
        op.f("ix_mes_repair_return_route_repair_order_id"),
        table_name="mes_repair_return_route",
    )
    op.drop_index(op.f("ix_mes_repair_return_route_id"), table_name="mes_repair_return_route")
    op.drop_table("mes_repair_return_route")

    op.drop_index(op.f("ix_mes_repair_cause_operator_user_id"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_cause_time"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_is_scrap"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_reason"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_phenomenon"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_process_code"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_process_id"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_product_id"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_order_id"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_repair_order_id"), table_name="mes_repair_cause")
    op.drop_index(op.f("ix_mes_repair_cause_id"), table_name="mes_repair_cause")
    op.drop_table("mes_repair_cause")

    op.drop_index(
        op.f("ix_mes_repair_defect_phenomenon_production_time"),
        table_name="mes_repair_defect_phenomenon",
    )
    op.drop_index(
        op.f("ix_mes_repair_defect_phenomenon_operator_user_id"),
        table_name="mes_repair_defect_phenomenon",
    )
    op.drop_index(
        op.f("ix_mes_repair_defect_phenomenon_phenomenon"),
        table_name="mes_repair_defect_phenomenon",
    )
    op.drop_index(
        op.f("ix_mes_repair_defect_phenomenon_process_code"),
        table_name="mes_repair_defect_phenomenon",
    )
    op.drop_index(
        op.f("ix_mes_repair_defect_phenomenon_process_id"),
        table_name="mes_repair_defect_phenomenon",
    )
    op.drop_index(
        op.f("ix_mes_repair_defect_phenomenon_product_id"),
        table_name="mes_repair_defect_phenomenon",
    )
    op.drop_index(
        op.f("ix_mes_repair_defect_phenomenon_order_id"),
        table_name="mes_repair_defect_phenomenon",
    )
    op.drop_index(
        op.f("ix_mes_repair_defect_phenomenon_repair_order_id"),
        table_name="mes_repair_defect_phenomenon",
    )
    op.drop_index(op.f("ix_mes_repair_defect_phenomenon_id"), table_name="mes_repair_defect_phenomenon")
    op.drop_table("mes_repair_defect_phenomenon")

    op.drop_index(op.f("ix_mes_repair_order_repair_operator_user_id"), table_name="mes_repair_order")
    op.drop_index(op.f("ix_mes_repair_order_status"), table_name="mes_repair_order")
    op.drop_index(op.f("ix_mes_repair_order_repair_time"), table_name="mes_repair_order")
    op.drop_index(op.f("ix_mes_repair_order_sender_user_id"), table_name="mes_repair_order")
    op.drop_index(op.f("ix_mes_repair_order_source_process_code"), table_name="mes_repair_order")
    op.drop_index(op.f("ix_mes_repair_order_product_id"), table_name="mes_repair_order")
    op.drop_index(op.f("ix_mes_repair_order_source_order_code"), table_name="mes_repair_order")
    op.drop_index(
        op.f("ix_mes_repair_order_source_order_process_id"),
        table_name="mes_repair_order",
    )
    op.drop_index(op.f("ix_mes_repair_order_source_order_id"), table_name="mes_repair_order")
    op.drop_index(op.f("ix_mes_repair_order_repair_order_code"), table_name="mes_repair_order")
    op.drop_index(op.f("ix_mes_repair_order_id"), table_name="mes_repair_order")
    op.drop_table("mes_repair_order")

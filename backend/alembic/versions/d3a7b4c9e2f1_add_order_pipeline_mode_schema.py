"""add order pipeline mode schema

Revision ID: d3a7b4c9e2f1
Revises: b2f4e8a1c9d0
Create Date: 2026-03-07 22:40:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "d3a7b4c9e2f1"
down_revision: Union[str, Sequence[str], None] = "b2f4e8a1c9d0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "mes_order",
        sa.Column(
            "pipeline_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "mes_order",
        sa.Column(
            "pipeline_process_codes",
            sa.Text(),
            nullable=False,
            server_default=sa.text("''"),
        ),
    )

    op.create_table(
        "mes_order_sub_order_pipeline_instance",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("sub_order_id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("order_process_id", sa.Integer(), nullable=False),
        sa.Column("process_code", sa.String(length=64), nullable=False),
        sa.Column("pipeline_seq", sa.Integer(), nullable=False),
        sa.Column("pipeline_sub_order_no", sa.String(length=64), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("invalid_reason", sa.String(length=128), nullable=True),
        sa.Column("invalidated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["sub_order_id"],
            ["mes_order_sub_order.id"],
            name=op.f("fk_mes_order_sub_order_pipeline_instance_sub_order_id_mes_order_sub_order"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["order_id"],
            ["mes_order.id"],
            name=op.f("fk_mes_order_sub_order_pipeline_instance_order_id_mes_order"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["order_process_id"],
            ["mes_order_process.id"],
            name=op.f("fk_mes_order_sub_order_pipeline_instance_order_process_id_mes_order_process"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_order_sub_order_pipeline_instance")),
        sa.UniqueConstraint(
            "sub_order_id",
            "pipeline_seq",
            name="uq_mes_order_sub_order_pipeline_instance_sub_order_seq",
        ),
        sa.UniqueConstraint(
            "pipeline_sub_order_no",
            name="uq_mes_order_sub_order_pipeline_instance_no",
        ),
    )
    op.create_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_id"),
        "mes_order_sub_order_pipeline_instance",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_sub_order_id"),
        "mes_order_sub_order_pipeline_instance",
        ["sub_order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_order_id"),
        "mes_order_sub_order_pipeline_instance",
        ["order_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_order_process_id"),
        "mes_order_sub_order_pipeline_instance",
        ["order_process_id"],
        unique=False,
    )
    op.create_index(
        "ix_mes_order_sub_order_pipeline_instance_order_process",
        "mes_order_sub_order_pipeline_instance",
        ["order_id", "order_process_id"],
        unique=False,
    )
    op.create_index(
        "ix_mes_order_sub_order_pipeline_instance_is_active",
        "mes_order_sub_order_pipeline_instance",
        ["is_active"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(
        "ix_mes_order_sub_order_pipeline_instance_is_active",
        table_name="mes_order_sub_order_pipeline_instance",
    )
    op.drop_index(
        "ix_mes_order_sub_order_pipeline_instance_order_process",
        table_name="mes_order_sub_order_pipeline_instance",
    )
    op.drop_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_order_process_id"),
        table_name="mes_order_sub_order_pipeline_instance",
    )
    op.drop_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_order_id"),
        table_name="mes_order_sub_order_pipeline_instance",
    )
    op.drop_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_sub_order_id"),
        table_name="mes_order_sub_order_pipeline_instance",
    )
    op.drop_index(
        op.f("ix_mes_order_sub_order_pipeline_instance_id"),
        table_name="mes_order_sub_order_pipeline_instance",
    )
    op.drop_table("mes_order_sub_order_pipeline_instance")
    op.drop_column("mes_order", "pipeline_process_codes")
    op.drop_column("mes_order", "pipeline_enabled")

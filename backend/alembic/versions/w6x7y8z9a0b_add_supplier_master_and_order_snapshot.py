"""add_supplier_master_and_order_snapshot

Revision ID: w6x7y8z9a0b
Revises: v4x5y6z7a8b
Create Date: 2026-04-02 11:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "w6x7y8z9a0b"
down_revision: Union[str, Sequence[str], None] = "v4x5y6z7a8b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mes_supplier",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("remark", sa.Text(), nullable=True),
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
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
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_mes_supplier_id"), "mes_supplier", ["id"], unique=False)
    op.create_index(op.f("ix_mes_supplier_is_enabled"), "mes_supplier", ["is_enabled"], unique=False)
    op.create_index(op.f("ix_mes_supplier_name"), "mes_supplier", ["name"], unique=True)

    op.add_column("mes_order", sa.Column("supplier_id", sa.Integer(), nullable=True))
    op.add_column("mes_order", sa.Column("supplier_name", sa.String(length=128), nullable=True))
    op.create_index(op.f("ix_mes_order_supplier_id"), "mes_order", ["supplier_id"], unique=False)
    op.create_foreign_key(
        "fk_mes_order_supplier_id",
        "mes_order",
        "mes_supplier",
        ["supplier_id"],
        ["id"],
        ondelete="RESTRICT",
    )


def downgrade() -> None:
    op.drop_constraint("fk_mes_order_supplier_id", "mes_order", type_="foreignkey")
    op.drop_index(op.f("ix_mes_order_supplier_id"), table_name="mes_order")
    op.drop_column("mes_order", "supplier_name")
    op.drop_column("mes_order", "supplier_id")

    op.drop_index(op.f("ix_mes_supplier_name"), table_name="mes_supplier")
    op.drop_index(op.f("ix_mes_supplier_is_enabled"), table_name="mes_supplier")
    op.drop_index(op.f("ix_mes_supplier_id"), table_name="mes_supplier")
    op.drop_table("mes_supplier")

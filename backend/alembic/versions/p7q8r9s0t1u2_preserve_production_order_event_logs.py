"""preserve_production_order_event_logs

Revision ID: p7q8r9s0t1u2
Revises: o6p7q8r9s0t1
Create Date: 2026-03-19 01:50:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "p7q8r9s0t1u2"
down_revision: Union[str, Sequence[str], None] = "o6p7q8r9s0t1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    constraint_name = bind.execute(
        sa.text(
            """
            SELECT con.conname
            FROM pg_constraint con
            JOIN pg_class rel ON rel.oid = con.conrelid
            WHERE rel.relname = 'mes_order_event_log'
              AND con.contype = 'f'
              AND pg_get_constraintdef(con.oid) LIKE 'FOREIGN KEY (order_id)%'
            LIMIT 1
            """
        )
    ).scalar()
    if constraint_name:
        op.drop_constraint(str(constraint_name), "mes_order_event_log", type_="foreignkey")
    op.alter_column("mes_order_event_log", "order_id", existing_type=sa.Integer(), nullable=True)
    op.create_foreign_key(
        "fk_mes_order_event_log_order_id",
        "mes_order_event_log",
        "mes_order",
        ["order_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.add_column("mes_order_event_log", sa.Column("order_code_snapshot", sa.String(length=64), nullable=True))
    op.add_column("mes_order_event_log", sa.Column("order_status_snapshot", sa.String(length=32), nullable=True))
    op.add_column("mes_order_event_log", sa.Column("product_name_snapshot", sa.String(length=128), nullable=True))
    op.add_column("mes_order_event_log", sa.Column("process_code_snapshot", sa.String(length=64), nullable=True))
    op.create_index(op.f("ix_mes_order_event_log_order_code_snapshot"), "mes_order_event_log", ["order_code_snapshot"], unique=False)
    op.create_index(op.f("ix_mes_order_event_log_order_status_snapshot"), "mes_order_event_log", ["order_status_snapshot"], unique=False)

    bind.execute(
        sa.text(
            """
            UPDATE mes_order_event_log log
            SET order_code_snapshot = ord.order_code,
                order_status_snapshot = ord.status,
                product_name_snapshot = prod.name,
                process_code_snapshot = ord.current_process_code
            FROM mes_order ord
            LEFT JOIN mes_product prod ON prod.id = ord.product_id
            WHERE log.order_id = ord.id
            """
        )
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_mes_order_event_log_order_status_snapshot"), table_name="mes_order_event_log")
    op.drop_index(op.f("ix_mes_order_event_log_order_code_snapshot"), table_name="mes_order_event_log")
    op.drop_column("mes_order_event_log", "process_code_snapshot")
    op.drop_column("mes_order_event_log", "product_name_snapshot")
    op.drop_column("mes_order_event_log", "order_status_snapshot")
    op.drop_column("mes_order_event_log", "order_code_snapshot")
    op.drop_constraint("fk_mes_order_event_log_order_id", "mes_order_event_log", type_="foreignkey")
    op.alter_column("mes_order_event_log", "order_id", existing_type=sa.Integer(), nullable=False)
    op.create_foreign_key(
        op.f("mes_order_event_log_order_id_fkey"),
        "mes_order_event_log",
        "mes_order",
        ["order_id"],
        ["id"],
        ondelete="CASCADE",
    )

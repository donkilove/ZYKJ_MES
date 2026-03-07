"""add production assist authorization table

Revision ID: b2f4e8a1c9d0
Revises: c9d8e7f6a5b4
Create Date: 2026-03-07 16:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b2f4e8a1c9d0"
down_revision: Union[str, Sequence[str], None] = "c9d8e7f6a5b4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "mes_production_assist_authorization",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("order_process_id", sa.Integer(), nullable=False),
        sa.Column("target_operator_user_id", sa.Integer(), nullable=False),
        sa.Column("requester_user_id", sa.Integer(), nullable=False),
        sa.Column("helper_user_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False, server_default=sa.text("'pending'")),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("review_remark", sa.Text(), nullable=True),
        sa.Column("reviewer_user_id", sa.Integer(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("first_article_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("end_production_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "status IN ('pending', 'approved', 'rejected', 'consumed')",
            name="ck_mes_production_assist_authorization_status_allowed",
        ),
        sa.ForeignKeyConstraint(
            ["order_id"],
            ["mes_order.id"],
            name=op.f("fk_mes_production_assist_authorization_order_id_mes_order"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["order_process_id"],
            ["mes_order_process.id"],
            name=op.f("fk_mes_production_assist_authorization_order_process_id_mes_order_process"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["target_operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_production_assist_authorization_target_operator_user_id_sys_user"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["requester_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_production_assist_authorization_requester_user_id_sys_user"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["helper_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_production_assist_authorization_helper_user_id_sys_user"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["reviewer_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_production_assist_authorization_reviewer_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_production_assist_authorization")),
    )
    op.create_index(
        op.f("ix_mes_production_assist_authorization_id"),
        "mes_production_assist_authorization",
        ["id"],
        unique=False,
    )
    op.create_index(
        "ix_mes_production_assist_authorization_status",
        "mes_production_assist_authorization",
        ["status"],
        unique=False,
    )
    op.create_index(
        "ix_mes_production_assist_authorization_helper_user_id",
        "mes_production_assist_authorization",
        ["helper_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_mes_production_assist_authorization_requester_user_id",
        "mes_production_assist_authorization",
        ["requester_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_mes_production_assist_authorization_order_process",
        "mes_production_assist_authorization",
        ["order_id", "order_process_id"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(
        "ix_mes_production_assist_authorization_order_process",
        table_name="mes_production_assist_authorization",
    )
    op.drop_index(
        "ix_mes_production_assist_authorization_requester_user_id",
        table_name="mes_production_assist_authorization",
    )
    op.drop_index(
        "ix_mes_production_assist_authorization_helper_user_id",
        table_name="mes_production_assist_authorization",
    )
    op.drop_index(
        "ix_mes_production_assist_authorization_status",
        table_name="mes_production_assist_authorization",
    )
    op.drop_index(
        op.f("ix_mes_production_assist_authorization_id"),
        table_name="mes_production_assist_authorization",
    )
    op.drop_table("mes_production_assist_authorization")

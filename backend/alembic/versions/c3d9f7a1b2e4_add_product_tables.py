"""add product tables

Revision ID: c3d9f7a1b2e4
Revises: e8f2b1c4d9a3
Create Date: 2026-02-28 17:40:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "c3d9f7a1b2e4"
down_revision: Union[str, Sequence[str], None] = "e8f2b1c4d9a3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "mes_product",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_product")),
    )
    op.create_index(op.f("ix_mes_product_id"), "mes_product", ["id"], unique=False)
    op.create_index(op.f("ix_mes_product_name"), "mes_product", ["name"], unique=True)

    op.create_table(
        "mes_product_parameter",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("product_id", sa.Integer(), nullable=False),
        sa.Column("param_key", sa.String(length=128), nullable=False),
        sa.Column("param_value", sa.String(length=1024), nullable=False, server_default=sa.text("''")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["mes_product.id"],
            name=op.f("fk_mes_product_parameter_product_id_mes_product"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_product_parameter")),
        sa.UniqueConstraint("product_id", "param_key", name="uq_mes_product_parameter_product_id_param_key"),
    )
    op.create_index(op.f("ix_mes_product_parameter_id"), "mes_product_parameter", ["id"], unique=False)
    op.create_index(
        op.f("ix_mes_product_parameter_product_id"),
        "mes_product_parameter",
        ["product_id"],
        unique=False,
    )
    op.create_index(op.f("ix_mes_product_parameter_param_key"), "mes_product_parameter", ["param_key"], unique=False)

    op.create_table(
        "mes_product_parameter_history",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("product_id", sa.Integer(), nullable=False),
        sa.Column("operator_user_id", sa.Integer(), nullable=True),
        sa.Column("operator_username", sa.String(length=64), nullable=False),
        sa.Column("remark", sa.String(length=512), nullable=False),
        sa.Column("changed_keys", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_mes_product_parameter_history_operator_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["mes_product.id"],
            name=op.f("fk_mes_product_parameter_history_product_id_mes_product"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_product_parameter_history")),
    )
    op.create_index(
        op.f("ix_mes_product_parameter_history_id"),
        "mes_product_parameter_history",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_parameter_history_operator_user_id"),
        "mes_product_parameter_history",
        ["operator_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_parameter_history_product_id"),
        "mes_product_parameter_history",
        ["product_id"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(
        op.f("ix_mes_product_parameter_history_product_id"),
        table_name="mes_product_parameter_history",
    )
    op.drop_index(
        op.f("ix_mes_product_parameter_history_operator_user_id"),
        table_name="mes_product_parameter_history",
    )
    op.drop_index(op.f("ix_mes_product_parameter_history_id"), table_name="mes_product_parameter_history")
    op.drop_table("mes_product_parameter_history")

    op.drop_index(op.f("ix_mes_product_parameter_param_key"), table_name="mes_product_parameter")
    op.drop_index(op.f("ix_mes_product_parameter_product_id"), table_name="mes_product_parameter")
    op.drop_index(op.f("ix_mes_product_parameter_id"), table_name="mes_product_parameter")
    op.drop_table("mes_product_parameter")

    op.drop_index(op.f("ix_mes_product_name"), table_name="mes_product")
    op.drop_index(op.f("ix_mes_product_id"), table_name="mes_product")
    op.drop_table("mes_product")

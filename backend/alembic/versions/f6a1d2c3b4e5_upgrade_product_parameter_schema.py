"""upgrade product parameter schema

Revision ID: f6a1d2c3b4e5
Revises: c3d9f7a1b2e4
Create Date: 2026-03-01 10:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f6a1d2c3b4e5"
down_revision: Union[str, Sequence[str], None] = "c3d9f7a1b2e4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "mes_product",
        sa.Column(
            "parameter_template_initialized",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )

    op.add_column(
        "mes_product_parameter",
        sa.Column(
            "param_category",
            sa.String(length=128),
            nullable=False,
            server_default=sa.text("'自定义参数'"),
        ),
    )
    op.add_column(
        "mes_product_parameter",
        sa.Column(
            "param_type",
            sa.String(length=16),
            nullable=False,
            server_default=sa.text("'Text'"),
        ),
    )
    op.add_column(
        "mes_product_parameter",
        sa.Column(
            "sort_order",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "mes_product_parameter",
        sa.Column(
            "is_preset",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.create_index(
        op.f("ix_mes_product_parameter_sort_order"),
        "mes_product_parameter",
        ["sort_order"],
        unique=False,
    )
    op.create_check_constraint(
        "ck_mes_product_parameter_param_type_allowed",
        "mes_product_parameter",
        "param_type IN ('Text', 'Link')",
    )

    op.execute(
        sa.text(
            """
            WITH ordered AS (
                SELECT id, ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY id) AS rn
                FROM mes_product_parameter
            )
            UPDATE mes_product_parameter AS p
            SET sort_order = ordered.rn
            FROM ordered
            WHERE p.id = ordered.id
            """
        )
    )

    op.alter_column("mes_product_parameter", "param_category", server_default=None)
    op.alter_column("mes_product_parameter", "param_type", server_default=None)
    op.alter_column("mes_product_parameter", "sort_order", server_default=None)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        "ck_mes_product_parameter_param_type_allowed",
        "mes_product_parameter",
        type_="check",
    )
    op.drop_index(op.f("ix_mes_product_parameter_sort_order"), table_name="mes_product_parameter")
    op.drop_column("mes_product_parameter", "is_preset")
    op.drop_column("mes_product_parameter", "sort_order")
    op.drop_column("mes_product_parameter", "param_type")
    op.drop_column("mes_product_parameter", "param_category")
    op.drop_column("mes_product", "parameter_template_initialized")


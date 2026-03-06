"""drop template standard/capacity configuration fields

Revision ID: a9e6c1f4d2b7
Revises: f1c2d3e4b5a6
Create Date: 2026-03-06 23:35:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "a9e6c1f4d2b7"
down_revision: Union[str, Sequence[str], None] = "f1c2d3e4b5a6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_column("mes_product_process_template_step", "capacity_per_hour")
    op.drop_column("mes_product_process_template_step", "standard_minutes")

    op.drop_column("sys_craft_system_master_template_step", "capacity_per_hour")
    op.drop_column("sys_craft_system_master_template_step", "standard_minutes")

    op.drop_column("mes_product_process_template_revision_step", "capacity_per_hour")
    op.drop_column("mes_product_process_template_revision_step", "standard_minutes")


def downgrade() -> None:
    """Downgrade schema."""
    op.add_column(
        "mes_product_process_template_revision_step",
        sa.Column("standard_minutes", sa.Integer(), nullable=False, server_default=sa.text("0")),
    )
    op.add_column(
        "mes_product_process_template_revision_step",
        sa.Column(
            "capacity_per_hour",
            sa.Numeric(precision=10, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )

    op.add_column(
        "sys_craft_system_master_template_step",
        sa.Column("standard_minutes", sa.Integer(), nullable=False, server_default=sa.text("0")),
    )
    op.add_column(
        "sys_craft_system_master_template_step",
        sa.Column(
            "capacity_per_hour",
            sa.Numeric(precision=10, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )

    op.add_column(
        "mes_product_process_template_step",
        sa.Column("standard_minutes", sa.Integer(), nullable=False, server_default=sa.text("0")),
    )
    op.add_column(
        "mes_product_process_template_step",
        sa.Column(
            "capacity_per_hour",
            sa.Numeric(precision=10, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )

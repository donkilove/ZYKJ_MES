"""update equipment code and name uniqueness

Revision ID: 1f4c2e6a9b10
Revises: b7c8d9e0f1a2
Create Date: 2026-03-01 23:35:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "1f4c2e6a9b10"
down_revision: Union[str, Sequence[str], None] = "b7c8d9e0f1a2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "mes_equipment",
        sa.Column("code", sa.String(length=64), nullable=True),
    )

    op.execute("UPDATE mes_equipment SET code = 'EQ-' || id::text WHERE code IS NULL")

    op.alter_column("mes_equipment", "code", existing_type=sa.String(length=64), nullable=False)

    op.create_unique_constraint(op.f("uq_mes_equipment_code"), "mes_equipment", ["code"])
    op.create_index(op.f("ix_mes_equipment_code"), "mes_equipment", ["code"], unique=False)

    op.drop_constraint(op.f("uq_mes_equipment_name"), "mes_equipment", type_="unique")


def downgrade() -> None:
    """Downgrade schema."""
    op.create_unique_constraint(op.f("uq_mes_equipment_name"), "mes_equipment", ["name"])

    op.drop_index(op.f("ix_mes_equipment_code"), table_name="mes_equipment")
    op.drop_constraint(op.f("uq_mes_equipment_code"), "mes_equipment", type_="unique")
    op.drop_column("mes_equipment", "code")


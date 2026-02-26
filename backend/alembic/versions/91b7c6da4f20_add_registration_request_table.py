"""add registration request table

Revision ID: 91b7c6da4f20
Revises: 142349cbdee9
Create Date: 2026-02-26 16:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "91b7c6da4f20"
down_revision: Union[str, Sequence[str], None] = "142349cbdee9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "sys_registration_request",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("account", sa.String(length=64), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_registration_request")),
        sa.UniqueConstraint("account", name=op.f("uq_sys_registration_request_account")),
    )
    op.create_index(op.f("ix_sys_registration_request_account"), "sys_registration_request", ["account"], unique=True)
    op.create_index(op.f("ix_sys_registration_request_id"), "sys_registration_request", ["id"], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_sys_registration_request_id"), table_name="sys_registration_request")
    op.drop_index(op.f("ix_sys_registration_request_account"), table_name="sys_registration_request")
    op.drop_table("sys_registration_request")

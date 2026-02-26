"""add page visibility table

Revision ID: d4e7a6b9c1f2
Revises: 91b7c6da4f20
Create Date: 2026-02-26 20:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "d4e7a6b9c1f2"
down_revision: Union[str, Sequence[str], None] = "91b7c6da4f20"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "sys_page_visibility",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("page_code", sa.String(length=64), nullable=False),
        sa.Column("role_code", sa.String(length=64), nullable=False),
        sa.Column("is_visible", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_page_visibility")),
        sa.UniqueConstraint("page_code", "role_code", name="uq_sys_page_visibility_page_code_role_code"),
    )
    op.create_index(op.f("ix_sys_page_visibility_id"), "sys_page_visibility", ["id"], unique=False)
    op.create_index(op.f("ix_sys_page_visibility_page_code"), "sys_page_visibility", ["page_code"], unique=False)
    op.create_index(op.f("ix_sys_page_visibility_role_code"), "sys_page_visibility", ["role_code"], unique=False)

    page_visibility = sa.table(
        "sys_page_visibility",
        sa.column("page_code", sa.String),
        sa.column("role_code", sa.String),
        sa.column("is_visible", sa.Boolean),
    )

    role_codes = ["system_admin", "production_admin", "quality_admin", "operator"]
    page_codes = ["user", "user_management", "registration_approval", "page_visibility_config"]
    default_visible = {
        ("system_admin", "user"),
        ("system_admin", "user_management"),
        ("system_admin", "registration_approval"),
        ("system_admin", "page_visibility_config"),
    }

    rows = []
    for role_code in role_codes:
        for page_code in page_codes:
            rows.append(
                {
                    "page_code": page_code,
                    "role_code": role_code,
                    "is_visible": (role_code, page_code) in default_visible,
                }
            )
    op.bulk_insert(page_visibility, rows)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_sys_page_visibility_role_code"), table_name="sys_page_visibility")
    op.drop_index(op.f("ix_sys_page_visibility_page_code"), table_name="sys_page_visibility")
    op.drop_index(op.f("ix_sys_page_visibility_id"), table_name="sys_page_visibility")
    op.drop_table("sys_page_visibility")

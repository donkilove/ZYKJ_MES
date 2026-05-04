"""add_login_type_to_sys_user_session

Revision ID: ea6e7fdc381a
Revises: n2o3p4q5r6s7
Create Date: 2026-05-04 17:30:41.927388

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'ea6e7fdc381a'
down_revision: Union[str, Sequence[str], None] = 'n2o3p4q5r6s7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'sys_user_session',
        sa.Column('login_type', sa.String(length=16), server_default=sa.text("'web'"), nullable=False),
    )


def downgrade() -> None:
    op.drop_column('sys_user_session', 'login_type')

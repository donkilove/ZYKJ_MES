"""merge_heads

Revision ID: 0998ac4f196a
Revises: c5d6e7f8a9b0, g7b8c9d0e1f2
Create Date: 2026-03-14 12:48:29.385880

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0998ac4f196a'
down_revision: Union[str, Sequence[str], None] = ('c5d6e7f8a9b0', 'g7b8c9d0e1f2')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass

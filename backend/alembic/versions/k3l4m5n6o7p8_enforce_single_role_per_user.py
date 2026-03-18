"""enforce_single_role_per_user

Revision ID: k3l4m5n6o7p8
Revises: j2k3l4m5n6o7
Create Date: 2026-03-18 20:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "k3l4m5n6o7p8"
down_revision: Union[str, Sequence[str], None] = "j2k3l4m5n6o7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    bind.execute(
        sa.text(
            """
            WITH ranked AS (
                SELECT
                    ur.user_id,
                    ur.role_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY ur.user_id
                        ORDER BY
                            CASE r.code
                                WHEN 'system_admin' THEN 1
                                WHEN 'production_admin' THEN 2
                                WHEN 'quality_admin' THEN 3
                                WHEN 'maintenance_staff' THEN 4
                                WHEN 'operator' THEN 5
                                ELSE 999
                            END,
                            r.code,
                            ur.role_id
                    ) AS rn
                FROM sys_user_role ur
                JOIN sys_role r ON r.id = ur.role_id
            )
            DELETE FROM sys_user_role ur
            USING ranked
            WHERE ur.user_id = ranked.user_id
              AND ur.role_id = ranked.role_id
              AND ranked.rn > 1
            """
        )
    )
    op.create_unique_constraint(
        "uq_sys_user_role_user_id",
        "sys_user_role",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_sys_user_role_user_id", "sys_user_role", type_="unique")

"""recode process codes by stage

Revision ID: e7b9c1d2a3f4
Revises: c4f7d9e2a1b3
Create Date: 2026-03-06 14:10:00.000000

"""

from __future__ import annotations

import uuid
from collections import defaultdict
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "e7b9c1d2a3f4"
down_revision: Union[str, Sequence[str], None] = "c4f7d9e2a1b3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()

    null_stage_count = bind.execute(
        sa.text("SELECT COUNT(*) FROM mes_process WHERE stage_id IS NULL")
    ).scalar_one()
    if int(null_stage_count) > 0:
        raise RuntimeError("Cannot recode process codes: found process records with NULL stage_id")

    long_stage_codes = bind.execute(
        sa.text(
            """
            SELECT id, code
            FROM mes_process_stage
            WHERE char_length(code) > 61
            ORDER BY id
            """
        )
    ).mappings().all()
    if long_stage_codes:
        detail = ", ".join(f"{row['id']}:{row['code']}" for row in long_stage_codes)
        raise RuntimeError(
            "Cannot recode process codes: stage code length would exceed process code max length (64). "
            f"Offending stages: {detail}"
        )

    overflow_rows = bind.execute(
        sa.text(
            """
            SELECT p.stage_id, s.code AS stage_code, COUNT(*) AS process_count
            FROM mes_process p
            JOIN mes_process_stage s ON s.id = p.stage_id
            GROUP BY p.stage_id, s.code
            HAVING COUNT(*) > 99
            ORDER BY p.stage_id
            """
        )
    ).mappings().all()
    if overflow_rows:
        detail = ", ".join(
            f"{row['stage_code']}({row['process_count']})"
            for row in overflow_rows
        )
        raise RuntimeError(
            "Cannot recode process codes: process count exceeds 99 under at least one stage. "
            f"Details: {detail}"
        )

    rows = bind.execute(
        sa.text(
            """
            SELECT p.id AS process_id, p.stage_id, s.code AS stage_code
            FROM mes_process p
            JOIN mes_process_stage s ON s.id = p.stage_id
            ORDER BY p.stage_id ASC, p.id ASC
            """
        )
    ).mappings().all()
    if not rows:
        return

    # Phase 1: assign temporary unique codes to avoid conflicts with unique index.
    run_token = uuid.uuid4().hex[:8]
    for row in rows:
        bind.execute(
            sa.text("UPDATE mes_process SET code = :code WHERE id = :process_id"),
            {
                "code": f"__TMP_RECODE_{run_token}_{row['process_id']}__",
                "process_id": row["process_id"],
            },
        )

    # Phase 2: assign final stage_code-XX codes by process id order within each stage.
    stage_counters: dict[int, int] = defaultdict(int)
    for row in rows:
        stage_id = int(row["stage_id"])
        stage_counters[stage_id] += 1
        serial = stage_counters[stage_id]
        final_code = f"{row['stage_code']}-{serial:02d}"
        bind.execute(
            sa.text("UPDATE mes_process SET code = :code WHERE id = :process_id"),
            {"code": final_code, "process_id": row["process_id"]},
        )


def downgrade() -> None:
    # Irreversible data migration: previous process codes cannot be restored.
    pass

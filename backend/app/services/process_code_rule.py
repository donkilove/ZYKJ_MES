from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.process import Process
from app.models.process_stage import ProcessStage


def normalize_process_code(value: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError("Process code is required")
    return normalized


def get_stage_for_process_write(
    db: Session,
    *,
    stage_id: int,
    require_enabled: bool = False,
) -> ProcessStage:
    stage = db.execute(select(ProcessStage).where(ProcessStage.id == stage_id)).scalars().first()
    if not stage:
        raise ValueError("Stage not found")
    if require_enabled and not stage.is_enabled:
        raise ValueError("Stage is disabled")
    return stage


def validate_process_code_matches_stage(
    *,
    code: str,
    stage: ProcessStage,
) -> str:
    normalized = normalize_process_code(code)
    prefix = f"{stage.code}-"
    if not normalized.startswith(prefix):
        raise ValueError(f"Process code must start with '{prefix}'")
    serial = normalized[len(prefix) :]
    if len(serial) != 2 or not serial.isdigit() or serial == "00":
        raise ValueError("Process code serial must be 01-99")
    if normalized != f"{stage.code}-{serial}":
        raise ValueError("Invalid process code format")
    return normalized


def ensure_process_code_unique(
    db: Session,
    *,
    code: str,
    exclude_process_id: int | None = None,
) -> None:
    stmt = select(Process.id).where(Process.code == code)
    if exclude_process_id is not None:
        stmt = stmt.where(Process.id != exclude_process_id)
    existing_id = db.execute(stmt).scalars().first()
    if existing_id is not None:
        raise ValueError("Process code already exists")

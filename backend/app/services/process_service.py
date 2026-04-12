from sqlalchemy import func, select
from sqlalchemy.orm import Session, load_only, selectinload

from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.schemas.process import ProcessCreate, ProcessUpdate
from app.services.process_code_rule import (
    ensure_process_code_unique,
    get_stage_for_process_write,
    validate_process_code_matches_stage,
)


def list_processes(db: Session, page: int, page_size: int, keyword: str | None) -> tuple[int, list[Process]]:
    stmt = (
        select(Process)
        .options(
            load_only(
                Process.id,
                Process.code,
                Process.name,
                Process.stage_id,
                Process.is_enabled,
                Process.created_at,
                Process.updated_at,
            ),
            selectinload(Process.stage).load_only(
                ProcessStage.id,
                ProcessStage.code,
                ProcessStage.name,
            ),
        )
        .order_by(Process.id.asc())
    )
    total_stmt = select(func.count(Process.id))
    if keyword:
        like_pattern = f"%{keyword}%"
        stmt = stmt.where(Process.name.ilike(like_pattern))
        total_stmt = total_stmt.where(Process.name.ilike(like_pattern))

    total_stmt = total_stmt.select_from(Process)
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    paged_stmt = stmt.offset(offset).limit(page_size)
    processes = db.execute(paged_stmt).scalars().all()
    return total, processes


def get_process_by_id(db: Session, process_id: int) -> Process | None:
    stmt = select(Process).where(Process.id == process_id).options(selectinload(Process.stage))
    return db.execute(stmt).scalars().first()


def get_process_by_code(db: Session, code: str) -> Process | None:
    stmt = select(Process).where(Process.code == code).options(selectinload(Process.stage))
    return db.execute(stmt).scalars().first()


def get_processes_by_codes(db: Session, codes: list[str]) -> tuple[list[Process], list[str]]:
    unique_codes = sorted({code for code in codes if code})
    if not unique_codes:
        return [], []

    stmt = select(Process).where(Process.code.in_(unique_codes)).options(selectinload(Process.stage))
    processes = db.execute(stmt).scalars().all()
    existing_codes = {process.code for process in processes}
    missing_codes = [code for code in unique_codes if code not in existing_codes]
    return processes, missing_codes


def _default_stage_id(db: Session) -> int | None:
    row = (
        db.execute(
            select(ProcessStage)
            .where(ProcessStage.is_enabled.is_(True))
            .order_by(ProcessStage.sort_order.asc(), ProcessStage.id.asc())
        )
        .scalars()
        .first()
    )
    return row.id if row else None


def create_process(db: Session, payload: ProcessCreate) -> Process:
    stage_id = payload.stage_id if payload.stage_id is not None else _default_stage_id(db)
    if stage_id is None:
        raise ValueError("Stage not found")
    stage = get_stage_for_process_write(db, stage_id=stage_id)
    normalized_code = validate_process_code_matches_stage(code=payload.code, stage=stage)
    ensure_process_code_unique(db, code=normalized_code)
    process = Process(code=normalized_code, name=payload.name, stage_id=stage.id, is_enabled=True)
    db.add(process)
    db.commit()
    db.refresh(process)
    return process


def update_process(db: Session, process: Process, payload: ProcessUpdate) -> Process:
    next_stage_id = payload.stage_id if payload.stage_id is not None else process.stage_id
    if next_stage_id is None:
        raise ValueError("Stage not found")
    stage = get_stage_for_process_write(db, stage_id=next_stage_id)
    normalized_code = validate_process_code_matches_stage(code=payload.code, stage=stage)
    if normalized_code != process.code:
        ensure_process_code_unique(db, code=normalized_code, exclude_process_id=process.id)
    process.code = normalized_code
    process.name = payload.name
    process.stage_id = stage.id
    if payload.is_enabled is not None:
        process.is_enabled = payload.is_enabled
    db.commit()
    db.refresh(process)
    return process

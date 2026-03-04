from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.schemas.process import ProcessCreate, ProcessUpdate


def list_processes(db: Session, page: int, page_size: int, keyword: str | None) -> tuple[int, list[Process]]:
    stmt = select(Process).options(selectinload(Process.stage)).order_by(Process.id.asc())
    if keyword:
        like_pattern = f"%{keyword}%"
        stmt = stmt.where(Process.name.ilike(like_pattern))

    total_stmt = select(func.count()).select_from(stmt.subquery())
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
    process = Process(code=payload.code, name=payload.name, stage_id=stage_id, is_enabled=True)
    db.add(process)
    db.commit()
    db.refresh(process)
    return process


def update_process(db: Session, process: Process, payload: ProcessUpdate) -> Process:
    process.name = payload.name
    if payload.stage_id is not None:
        process.stage_id = payload.stage_id
    if payload.is_enabled is not None:
        process.is_enabled = payload.is_enabled
    db.commit()
    db.refresh(process)
    return process

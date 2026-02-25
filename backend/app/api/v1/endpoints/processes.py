from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.process import Process
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.process import ProcessCreate, ProcessItem, ProcessListResult, ProcessUpdate
from app.services.process_service import (
    create_process,
    get_process_by_code,
    get_process_by_id,
    list_processes,
    update_process,
)


router = APIRouter()


def to_process_item(process: Process) -> ProcessItem:
    return ProcessItem(
        id=process.id,
        code=process.code,
        name=process.name,
        created_at=process.created_at,
        updated_at=process.updated_at,
    )


@router.get("", response_model=ApiResponse[ProcessListResult])
def get_processes(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("process:read")),
) -> ApiResponse[ProcessListResult]:
    total, processes = list_processes(db, page, page_size, keyword)
    result = ProcessListResult(
        total=total,
        items=[to_process_item(process) for process in processes],
    )
    return success_response(result)


@router.post("", response_model=ApiResponse[ProcessItem], status_code=status.HTTP_201_CREATED)
def create_process_api(
    payload: ProcessCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("process:write")),
) -> ApiResponse[ProcessItem]:
    existing = get_process_by_code(db, payload.code)
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Process code already exists")
    process = create_process(db, payload)
    return success_response(to_process_item(process), message="created")


@router.put("/{process_id}", response_model=ApiResponse[ProcessItem])
def update_process_api(
    process_id: int,
    payload: ProcessUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("process:write")),
) -> ApiResponse[ProcessItem]:
    process = get_process_by_id(db, process_id)
    if not process:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Process not found")
    updated = update_process(db, process, payload)
    return success_response(to_process_item(updated))


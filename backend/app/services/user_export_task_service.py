from __future__ import annotations

import csv
import io
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models.user import User
from app.models.user_export_task import UserExportTask
from app.schemas.user import UserDeleteResult, UserItem
from app.services.audit_service import write_audit_log
from app.services.session_service import list_online_user_ids
from app.services.user_service import (
    DELETED_SCOPE_ACTIVE,
    DELETED_SCOPE_DELETED,
    query_users,
)

USER_EXPORT_STATUS_PENDING = "pending"
USER_EXPORT_STATUS_PROCESSING = "processing"
USER_EXPORT_STATUS_SUCCEEDED = "succeeded"
USER_EXPORT_STATUS_FAILED = "failed"
USER_EXPORT_STATUS_EXPIRED = "expired"
USER_EXPORT_PROCESSING_TIMEOUT_MINUTES = 30
USER_EXPORT_RETENTION_DAYS = 7
USER_EXPORT_TASK_LIST_LIMIT = 20
RUNTIME_EXPORT_DIR = (
    Path(__file__).resolve().parents[2] / "runtime_exports" / "user"
)


def _now_utc() -> datetime:
    return datetime.now(UTC)


def ensure_user_export_runtime_dir() -> Path:
    RUNTIME_EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    return RUNTIME_EXPORT_DIR


def _sanitize_filename_segment(value: str | None) -> str:
    if value is None:
        return ""
    normalized = "".join(
        ch if ch.isalnum() or ch in {"-", "_"} else "_"
        for ch in value.strip().lower()
    )
    return normalized.strip("_")


def build_user_export_filename(
    *,
    deleted_scope: str,
    format: str,
    role_code: str | None,
    now: datetime,
) -> str:
    scope_segment = _sanitize_filename_segment(deleted_scope) or DELETED_SCOPE_ACTIVE
    role_segment = _sanitize_filename_segment(role_code)
    timestamp = now.strftime("%Y%m%d_%H%M%S")
    extension = "xlsx" if format == "excel" else "csv"
    base_name = f"users_{scope_segment}"
    if role_segment:
        base_name = f"{base_name}_{role_segment}"
    return f"{base_name}_{timestamp}.{extension}"


def _build_export_rows(users: list[User], online_user_ids: set[int]) -> list[list[str]]:
    rows: list[list[str]] = []
    for user in users:
        rows.append(
            [
                str(user.id),
                user.username,
                next(iter(sorted(role.name for role in user.roles)), "/"),
                user.stage.name if user.stage else "/",
                "在线" if user.id in online_user_ids else "离线",
                "启用" if user.is_active else "停用",
                "是" if user.is_deleted else "否",
                "是" if user.must_change_password else "否",
                user.created_at.isoformat() if user.created_at else "",
                user.last_login_at.isoformat() if user.last_login_at else "",
                user.deleted_at.isoformat() if user.deleted_at else "",
                user.remark or "",
            ]
        )
    return rows


def _build_csv_bytes(rows: list[list[str]]) -> bytes:
    buffer = io.StringIO()
    buffer.write("\ufeff")
    writer = csv.writer(buffer)
    writer.writerow(
        [
            "id",
            "用户名",
            "角色",
            "工段",
            "在线状态",
            "账号状态",
            "是否已删除",
            "首次登录需改密",
            "创建时间",
            "最近登录时间",
            "删除时间",
            "备注",
        ]
    )
    writer.writerows(rows)
    return buffer.getvalue().encode("utf-8")


def _build_excel_bytes(rows: list[list[str]]) -> bytes:
    try:
        import openpyxl
    except ImportError as exc:
        raise RuntimeError("Excel 导出不可用：缺少 openpyxl") from exc

    workbook = openpyxl.Workbook()
    worksheet = workbook.active
    assert worksheet is not None
    worksheet.title = "用户列表"
    worksheet.append(
        [
            "id",
            "用户名",
            "角色",
            "工段",
            "在线状态",
            "账号状态",
            "是否已删除",
            "首次登录需改密",
            "创建时间",
            "最近登录时间",
            "删除时间",
            "备注",
        ]
    )
    for row in rows:
        worksheet.append(row)
    buffer = io.BytesIO()
    workbook.save(buffer)
    return buffer.getvalue()


def cleanup_user_export_tasks(db: Session) -> None:
    now = _now_utc()
    changed = False
    ensure_user_export_runtime_dir()
    tasks = db.execute(select(UserExportTask)).scalars().all()
    for task in tasks:
        if (
            task.status == USER_EXPORT_STATUS_PROCESSING
            and task.started_at is not None
            and now - task.started_at > timedelta(minutes=USER_EXPORT_PROCESSING_TIMEOUT_MINUTES)
        ):
            task.status = USER_EXPORT_STATUS_FAILED
            task.failure_reason = "任务执行中断，请重新导出"
            task.finished_at = now
            changed = True
        if (
            task.status == USER_EXPORT_STATUS_SUCCEEDED
            and task.expires_at is not None
            and task.expires_at <= now
        ):
            if task.storage_path:
                file_path = Path(task.storage_path)
                if file_path.exists():
                    file_path.unlink(missing_ok=True)
            task.status = USER_EXPORT_STATUS_EXPIRED
            changed = True
    if changed:
        db.commit()


def create_user_export_task(
    db: Session,
    *,
    created_by_user_id: int,
    format: str,
    deleted_scope: str,
    keyword: str | None,
    role_code: str | None,
    is_active: bool | None,
) -> UserExportTask:
    cleanup_user_export_tasks(db)
    task = UserExportTask(
        task_code=uuid4().hex,
        created_by_user_id=created_by_user_id,
        status=USER_EXPORT_STATUS_PENDING,
        format=format,
        deleted_scope=deleted_scope,
        keyword=keyword.strip() if keyword and keyword.strip() else None,
        role_code=role_code.strip() if role_code and role_code.strip() else None,
        is_active=is_active,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def list_user_export_tasks(
    db: Session,
    *,
    created_by_user_id: int,
    limit: int = USER_EXPORT_TASK_LIST_LIMIT,
) -> list[UserExportTask]:
    cleanup_user_export_tasks(db)
    stmt = (
        select(UserExportTask)
        .where(UserExportTask.created_by_user_id == created_by_user_id)
        .order_by(UserExportTask.requested_at.desc(), UserExportTask.id.desc())
        .limit(limit)
    )
    return db.execute(stmt).scalars().all()


def get_user_export_task(
    db: Session,
    *,
    task_id: int,
    created_by_user_id: int,
) -> UserExportTask | None:
    cleanup_user_export_tasks(db)
    stmt = select(UserExportTask).where(
        UserExportTask.id == task_id,
        UserExportTask.created_by_user_id == created_by_user_id,
    )
    return db.execute(stmt).scalars().first()


def run_user_export_task(task_id: int) -> None:
    db = SessionLocal()
    try:
        task = db.get(UserExportTask, task_id)
        if task is None:
            return
        now = _now_utc()
        task.status = USER_EXPORT_STATUS_PROCESSING
        task.started_at = now
        task.finished_at = None
        task.failure_reason = None
        task.record_count = 0
        db.commit()

        online_user_ids_for_filter = None
        if task.deleted_scope != DELETED_SCOPE_DELETED:
            online_user_ids_for_filter = list_online_user_ids(db)

        stmt = query_users(
            keyword=task.keyword,
            role_code=task.role_code,
            is_active=task.is_active,
            deleted_scope=task.deleted_scope,
        )
        users = db.execute(stmt).scalars().all()
        candidate_user_ids = [int(user.id) for user in users]
        online_user_ids = (
            list_online_user_ids(db, candidate_user_ids=candidate_user_ids)
            if candidate_user_ids
            else set()
        )
        rows = _build_export_rows(users, online_user_ids)
        file_name = build_user_export_filename(
            deleted_scope=task.deleted_scope,
            format=task.format,
            role_code=task.role_code,
            now=now,
        )
        runtime_dir = ensure_user_export_runtime_dir()
        file_path = runtime_dir / file_name
        if task.format == "excel":
            content_bytes = _build_excel_bytes(rows)
            mime_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        else:
            content_bytes = _build_csv_bytes(rows)
            mime_type = "text/csv"
        file_path.write_bytes(content_bytes)

        task.status = USER_EXPORT_STATUS_SUCCEEDED
        task.record_count = len(rows)
        task.file_name = file_name
        task.mime_type = mime_type
        task.storage_path = str(file_path.resolve())
        task.finished_at = _now_utc()
        task.expires_at = task.finished_at + timedelta(days=USER_EXPORT_RETENTION_DAYS)
        db.commit()

        operator = db.get(User, task.created_by_user_id)
        if operator is not None:
            write_audit_log(
                db,
                action_code="user.export.complete",
                action_name="用户导出任务完成",
                target_type="user_export_task",
                target_id=str(task.id),
                target_name=task.file_name,
                operator=operator,
                after_data={
                    "status": task.status,
                    "record_count": task.record_count,
                    "file_name": task.file_name,
                },
            )
            db.commit()
    except Exception as exc:  # noqa: BLE001
        db.rollback()
        task = db.get(UserExportTask, task_id)
        if task is not None:
            task.status = USER_EXPORT_STATUS_FAILED
            task.failure_reason = str(exc)
            task.finished_at = _now_utc()
            db.commit()
            operator = db.get(User, task.created_by_user_id)
            if operator is not None:
                write_audit_log(
                    db,
                    action_code="user.export.fail",
                    action_name="用户导出任务失败",
                    target_type="user_export_task",
                    target_id=str(task.id),
                    target_name=task.file_name or task.task_code,
                    operator=operator,
                    after_data={
                        "status": task.status,
                        "failure_reason": task.failure_reason,
                    },
                )
                db.commit()
    finally:
        db.close()

import base64
import csv
import io

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, require_permission
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.user import (
    UserCreate,
    UserExportResult,
    UserItem,
    UserListResult,
    UserOnlineStatusResult,
    UserResetPasswordRequest,
    UserUpdate,
)
from app.services.audit_service import write_audit_log
from app.services.message_service import create_message_for_users
from app.services.session_service import list_online_user_ids
from app.services.user_service import (
    create_user,
    delete_user,
    get_user_by_id,
    list_users,
    reset_user_password,
    set_user_active,
    update_user,
)


router = APIRouter()


def _resolve_online_user_ids_for_users(
    db: Session,
    users: list[User],
    *,
    preloaded_online_user_ids: set[int] | None = None,
) -> set[int]:
    if not users:
        return set()
    current_page_user_ids = {user.id for user in users}
    if preloaded_online_user_ids is not None:
        return {
            user_id
            for user_id in preloaded_online_user_ids
            if user_id in current_page_user_ids
        }
    return list_online_user_ids(db, candidate_user_ids=list(current_page_user_ids))


def to_user_item(user: User, *, online_user_ids: set[int] | None = None) -> UserItem:
    is_online = user.id in (online_user_ids or set())
    stage_name = user.stage.name if user.stage else None
    primary_role = sorted(user.roles, key=lambda role: role.code)[0] if user.roles else None
    return UserItem(
        id=user.id,
        username=user.username,
        full_name=user.full_name,
        remark=user.remark,
        is_online=is_online,
        is_active=user.is_active,
        is_deleted=user.is_deleted,
        must_change_password=user.must_change_password,
        last_seen_at=user.last_login_at,
        stage_id=user.stage_id,
        stage_name=stage_name,
        role_code=primary_role.code if primary_role else None,
        role_name=primary_role.name if primary_role else None,
        last_login_at=user.last_login_at,
        last_login_ip=user.last_login_ip,
        password_changed_at=user.password_changed_at,
        created_at=user.created_at,
        updated_at=user.updated_at,
    )


def _build_csv_export(users: list[User], online_user_ids: set[int]) -> str:
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(
        [
            "id",
            "用户名",
            "角色",
            "工段",
            "在线状态",
            "账号状态",
            "首次登录需改密",
            "创建时间",
            "最近登录时间",
        ]
    )
    for user in users:
        writer.writerow(
            [
                user.id,
                user.username,
                next(iter(sorted(role.name for role in user.roles)), "/"),
                user.stage.name if user.stage else "/",
                "在线" if user.id in online_user_ids else "离线",
                "启用" if user.is_active else "停用",
                "是" if user.must_change_password else "否",
                user.created_at.isoformat(),
                user.last_login_at.isoformat() if user.last_login_at else "",
            ]
        )
    return base64.b64encode(buffer.getvalue().encode("utf-8-sig")).decode("ascii")


def _build_excel_export(users: list[User], online_user_ids: set[int]) -> str:
    try:
        import openpyxl
    except ImportError:
        return ""
    wb = openpyxl.Workbook()
    ws = wb.active
    assert ws is not None
    ws.title = "用户列表"
    headers = ["id", "用户名", "角色", "工段", "在线状态", "账号状态", "首次登录需改密", "创建时间", "最近登录时间"]
    ws.append(headers)
    for user in users:
        ws.append([
            user.id,
            user.username,
            next(iter(sorted(role.name for role in user.roles)), "/"),
            user.stage.name if user.stage else "/",
            "在线" if user.id in online_user_ids else "离线",
            "启用" if user.is_active else "停用",
            "是" if user.must_change_password else "否",
            user.created_at.isoformat(),
            user.last_login_at.isoformat() if user.last_login_at else "",
        ])
    buffer = io.BytesIO()
    wb.save(buffer)
    return base64.b64encode(buffer.getvalue()).decode("ascii")


@router.get("", response_model=ApiResponse[UserListResult])
def get_users(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    keyword: str | None = Query(default=None),
    role_code: str | None = Query(default=None),
    stage_id: int | None = Query(default=None, ge=1),
    is_active: bool | None = Query(default=None),
    is_online: bool | None = Query(default=None),
    include_deleted: bool = Query(default=False),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.users.list")),
) -> ApiResponse[UserListResult]:
    online_user_ids_for_filter = (
        list_online_user_ids(db) if is_online is not None else None
    )
    total, users = list_users(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        role_code=role_code,
        stage_id=stage_id,
        is_online=is_online,
        online_user_ids=online_user_ids_for_filter,
        is_active=is_active,
        include_deleted=include_deleted,
    )
    online_user_ids = _resolve_online_user_ids_for_users(
        db,
        users,
        preloaded_online_user_ids=online_user_ids_for_filter,
    )
    result = UserListResult(
        total=total,
        items=[to_user_item(user, online_user_ids=online_user_ids) for user in users],
    )
    return success_response(result)


@router.get("/export", response_model=ApiResponse[UserExportResult])
def export_users(
    keyword: str | None = Query(default=None),
    role_code: str | None = Query(default=None),
    stage_id: int | None = Query(default=None, ge=1),
    is_active: bool | None = Query(default=None),
    is_online: bool | None = Query(default=None),
    format: str = Query(default="csv", pattern="^(csv|excel)$"),
    db: Session = Depends(get_db),
    permission_user: User = Depends(require_permission("user.users.export")),
) -> ApiResponse[UserExportResult]:
    _ = permission_user
    online_user_ids_for_filter = (
        list_online_user_ids(db) if is_online is not None else None
    )
    total, users = list_users(
        db,
        page=1,
        page_size=5000,
        keyword=keyword,
        role_code=role_code,
        stage_id=stage_id,
        is_online=is_online,
        online_user_ids=online_user_ids_for_filter,
        is_active=is_active,
        include_deleted=False,
    )
    online_user_ids = _resolve_online_user_ids_for_users(
        db,
        users,
        preloaded_online_user_ids=online_user_ids_for_filter,
    )
    _ = total
    if format == "excel":
        content_base64 = _build_excel_export(users, online_user_ids)
        if not content_base64:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Excel export not available (openpyxl not installed)")
        return success_response(
            UserExportResult(
                filename="users_export.xlsx",
                content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                content_base64=content_base64,
            )
        )
    content_base64 = _build_csv_export(users, online_user_ids)
    return success_response(
        UserExportResult(
            filename="users_export.csv",
            content_type="text/csv",
            content_base64=content_base64,
        )
    )


@router.post("", response_model=ApiResponse[UserItem], status_code=status.HTTP_201_CREATED)
def create_user_api(
    payload: UserCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.users.create")),
) -> ApiResponse[UserItem]:
    user, error_message = create_user(db, payload)
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not user:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to create user")

    write_audit_log(
        db,
        action_code="user.create",
        action_name="新建用户",
        target_type="user",
        target_id=str(user.id),
        target_name=user.username,
        operator=current_user,
        after_data={
            "username": user.username,
            "role_code": user.roles[0].code if user.roles else None,
            "stage_id": user.stage_id,
        },
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    db.commit()
    return success_response(
        to_user_item(
            user,
            online_user_ids=list_online_user_ids(
                db,
                candidate_user_ids=[user.id],
            ),
        ),
        message="created",
    )


@router.get("/online-status", response_model=ApiResponse[UserOnlineStatusResult])
def get_users_online_status(
    user_id: list[int] = Query(default=[]),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.users.list")),
) -> ApiResponse[UserOnlineStatusResult]:
    requested_user_ids = sorted({value for value in user_id if value > 0})
    if not requested_user_ids:
        return success_response(UserOnlineStatusResult(user_ids=[]))
    online_user_ids = sorted(
        list_online_user_ids(db, candidate_user_ids=requested_user_ids)
    )
    return success_response(UserOnlineStatusResult(user_ids=online_user_ids))


@router.get("/{user_id}", response_model=ApiResponse[UserItem])
def get_user_detail(
    user_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("user.users.detail")),
) -> ApiResponse[UserItem]:
    user = get_user_by_id(db, user_id, include_deleted=True)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return success_response(
        to_user_item(
            user,
            online_user_ids=list_online_user_ids(
                db,
                candidate_user_ids=[user.id],
            ),
        )
    )


@router.put("/{user_id}", response_model=ApiResponse[UserItem])
def update_user_api(
    user_id: int,
    payload: UserUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.users.update")),
) -> ApiResponse[UserItem]:
    user = get_user_by_id(db, user_id, include_deleted=True)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    before_data = {
        "username": user.username,
        "full_name": user.full_name,
        "is_active": user.is_active,
        "role_code": user.roles[0].code if user.roles else None,
        "stage_id": user.stage_id,
    }
    updated, error_message = update_user(
        db,
        user=user,
        payload=payload,
        operator=current_user,
    )
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not updated:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update user")

    write_audit_log(
        db,
        action_code="user.update",
        action_name="编辑用户",
        target_type="user",
        target_id=str(updated.id),
        target_name=updated.username,
        operator=current_user,
        before_data=before_data,
        after_data={
            "username": updated.username,
            "full_name": updated.full_name,
            "is_active": updated.is_active,
            "role_code": updated.roles[0].code if updated.roles else None,
            "stage_id": updated.stage_id,
        },
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    db.commit()
    return success_response(
        to_user_item(
            updated,
            online_user_ids=list_online_user_ids(
                db,
                candidate_user_ids=[updated.id],
            ),
        )
    )


@router.post("/{user_id}/enable", response_model=ApiResponse[UserItem])
def enable_user_api(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.users.enable")),
) -> ApiResponse[UserItem]:
    user = get_user_by_id(db, user_id, include_deleted=True)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    updated, error_message = set_user_active(db, user=user, active=True)
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not updated:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to enable user")
    write_audit_log(
        db,
        action_code="user.enable",
        action_name="启用用户",
        target_type="user",
        target_id=str(updated.id),
        target_name=updated.username,
        operator=current_user,
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    db.commit()
    return success_response(
        to_user_item(
            updated,
            online_user_ids=list_online_user_ids(
                db,
                candidate_user_ids=[updated.id],
            ),
        )
    )


@router.post("/{user_id}/disable", response_model=ApiResponse[UserItem])
def disable_user_api(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.users.disable")),
) -> ApiResponse[UserItem]:
    user = get_user_by_id(db, user_id, include_deleted=True)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    updated, error_message = set_user_active(db, user=user, active=False)
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not updated:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to disable user")
    write_audit_log(
        db,
        action_code="user.disable",
        action_name="停用用户",
        target_type="user",
        target_id=str(updated.id),
        target_name=updated.username,
        operator=current_user,
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    db.commit()
    create_message_for_users(
        db,
        message_type="notice",
        priority="important",
        title="账号已被停用",
        summary=f"账号 {updated.username} 已被管理员停用，如需恢复请联系系统管理员。",
        content=(
            f"您的账号 {updated.username} 已被管理员 {current_user.username} 停用。"
            "如该操作与预期不符，请联系系统管理员核实。"
        ),
        source_module="user",
        source_type="user_disable",
        source_id=str(updated.id),
        source_code=updated.username,
        target_page_code="user",
        target_tab_code="account_settings",
        recipient_user_ids=[updated.id],
        dedupe_key=f"user_disabled_{updated.id}_{int(updated.updated_at.timestamp()) if updated.updated_at else 'now'}",
        created_by_user_id=current_user.id,
    )
    return success_response(
        to_user_item(
            updated,
            online_user_ids=list_online_user_ids(
                db,
                candidate_user_ids=[updated.id],
            ),
        )
    )


@router.post("/{user_id}/reset-password", response_model=ApiResponse[UserItem])
def reset_password_api(
    user_id: int,
    request: Request,
    payload: UserResetPasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.users.reset_password")),
) -> ApiResponse[UserItem]:
    user = get_user_by_id(db, user_id, include_deleted=True)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    updated, error_message = reset_user_password(db, user=user, new_password=payload.password)
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not updated:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to reset password")
    write_audit_log(
        db,
        action_code="user.reset_password",
        action_name="重置密码",
        target_type="user",
        target_id=str(updated.id),
        target_name=updated.username,
        operator=current_user,
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    db.commit()
    return success_response(
        to_user_item(
            updated,
            online_user_ids=list_online_user_ids(
                db,
                candidate_user_ids=[updated.id],
            ),
        )
    )


@router.delete("/{user_id}", response_model=ApiResponse[dict[str, bool]])
def delete_user_api(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("user.users.delete")),
) -> ApiResponse[dict[str, bool]]:
    if user_id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete current login user")

    user = get_user_by_id(db, user_id, include_deleted=True)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    deleted, error_message = delete_user(db, user=user)
    if error_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error_message)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to delete user")

    write_audit_log(
        db,
        action_code="user.delete",
        action_name="逻辑删除用户",
        target_type="user",
        target_id=str(user.id),
        target_name=user.username,
        operator=current_user,
        after_data={"is_deleted": True, "is_active": False},
        ip_address=request.client.host if request and request.client else None,
        terminal_info=request.headers.get("user-agent") if request else None,
    )
    db.commit()
    return success_response({"deleted": True}, message="deleted")

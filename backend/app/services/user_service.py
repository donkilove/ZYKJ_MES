from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session, load_only, selectinload

from app.core.authz_catalog import (
    PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE,
    PERM_PAGE_FUNCTION_PERMISSION_CONFIG_VIEW,
)
from app.core.rbac import (
    ROLE_MAINTENANCE_STAFF,
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.core.security import get_password_hash, verify_password
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.registration_request import RegistrationRequest
from app.models.role import Role
from app.models.user import User
from app.models.user_session import UserSession
from app.schemas.user import UserCreate, UserUpdate
from app.services.authz_service import get_permission_codes_for_role_codes
from app.services.online_status_service import clear_user, get_user_online_snapshot
from app.services.role_service import (
    get_role_by_code_case_insensitive,
    get_roles_by_codes,
)
from app.services.session_service import force_offline_sessions


REG_STATUS_PENDING = "pending"
REG_STATUS_APPROVED = "approved"
REG_STATUS_REJECTED = "rejected"


def validate_password(password: str) -> str | None:
    """校验密码规则，返回错误信息或 None。"""
    if len(password) < 6:
        return "密码长度不能少于6位"
    # 不得连续4位相同字符
    for i in range(len(password) - 3):
        if password[i] == password[i + 1] == password[i + 2] == password[i + 3]:
            return "密码不得包含连续4位相同字符"
    return None


def _now_utc() -> datetime:
    return datetime.now(UTC)


def normalize_username(username: str) -> str:
    return username.strip()


def _normalize_codes(codes: list[str]) -> list[str]:
    return sorted({code.strip() for code in codes if code and code.strip()})


ROLE_PRIORITY = [
    ROLE_SYSTEM_ADMIN,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_MAINTENANCE_STAFF,
    ROLE_OPERATOR,
]
ROLE_PRIORITY_INDEX = {code: index for index, code in enumerate(ROLE_PRIORITY)}
DELETED_SCOPE_ACTIVE = "active"
DELETED_SCOPE_DELETED = "deleted"
DELETED_SCOPE_ALL = "all"
VALID_DELETED_SCOPES = {
    DELETED_SCOPE_ACTIVE,
    DELETED_SCOPE_DELETED,
    DELETED_SCOPE_ALL,
}


def normalize_deleted_scope(
    *,
    deleted_scope: str | None = None,
    include_deleted: bool = False,
) -> str:
    normalized = (deleted_scope or "").strip().lower()
    if normalized in VALID_DELETED_SCOPES:
        return normalized
    if include_deleted:
        return DELETED_SCOPE_ALL
    return DELETED_SCOPE_ACTIVE


def _build_user_filter_conditions(
    *,
    keyword: str | None,
    role_code: str | None,
    stage_id: int | None,
    is_online: bool | None,
    online_user_ids: set[int] | None,
    is_active: bool | None,
    deleted_scope: str,
) -> tuple[list[object], bool]:
    conditions: list[object] = []
    requires_role_join = False
    if deleted_scope == DELETED_SCOPE_ACTIVE:
        conditions.append(User.is_deleted.is_(False))
    elif deleted_scope == DELETED_SCOPE_DELETED:
        conditions.append(User.is_deleted.is_(True))
    if keyword:
        conditions.append(User.username.ilike(f"%{keyword}%"))
    if role_code:
        requires_role_join = True
        conditions.append(Role.code == role_code)
    if stage_id is not None:
        conditions.append(User.stage_id == stage_id)
    if is_online is not None:
        effective_online_user_ids = online_user_ids or set()
        if is_online:
            if not effective_online_user_ids:
                conditions.append(User.id == -1)
            else:
                conditions.append(User.id.in_(effective_online_user_ids))
        elif effective_online_user_ids:
            conditions.append(~User.id.in_(effective_online_user_ids))
    if is_active is not None:
        conditions.append(User.is_active.is_(is_active))
    return conditions, requires_role_join


def query_users(
    *,
    keyword: str | None,
    role_code: str | None = None,
    stage_id: int | None = None,
    is_online: bool | None = None,
    online_user_ids: set[int] | None = None,
    is_active: bool | None = None,
    deleted_scope: str = DELETED_SCOPE_ACTIVE,
    include_deleted: bool = False,
) -> Select[tuple[User]]:
    effective_deleted_scope = normalize_deleted_scope(
        deleted_scope=deleted_scope,
        include_deleted=include_deleted,
    )
    conditions, requires_role_join = _build_user_filter_conditions(
        keyword=keyword,
        role_code=role_code,
        stage_id=stage_id,
        is_online=is_online,
        online_user_ids=online_user_ids,
        is_active=is_active,
        deleted_scope=effective_deleted_scope,
    )
    stmt = (
        select(User)
        .options(
            selectinload(User.roles),
            selectinload(User.stage),
        )
        .order_by(User.id.asc())
    )
    if requires_role_join:
        stmt = stmt.join(User.roles)
    if conditions:
        stmt = stmt.where(*conditions)
    return stmt


def get_user_by_id(
    db: Session,
    user_id: int,
    *,
    include_deleted: bool = False,
    load_roles: bool = True,
    load_processes: bool = True,
    load_stage: bool = True,
) -> User | None:
    stmt = select(User).where(User.id == user_id)
    loader_options = []
    if load_roles:
        loader_options.append(selectinload(User.roles))
    if load_processes:
        loader_options.append(selectinload(User.processes).selectinload(Process.stage))
    if load_stage:
        loader_options.append(selectinload(User.stage))
    if loader_options:
        stmt = stmt.options(*loader_options)
    if not include_deleted:
        stmt = stmt.where(User.is_deleted.is_(False))
    return db.execute(stmt).scalars().first()


def get_user_for_auth(
    db: Session,
    user_id: int,
    *,
    include_deleted: bool = False,
) -> User | None:
    """鉴权读链专用：仅加载鉴权与公共用户信息所需字段。"""
    stmt = (
        select(User)
        .options(
            load_only(
                User.id,
                User.username,
                User.full_name,
                User.is_active,
                User.is_deleted,
                User.stage_id,
                User.created_at,
                User.last_login_at,
                User.last_login_ip,
                User.password_changed_at,
            ),
            selectinload(User.roles).load_only(
                Role.id,
                Role.code,
                Role.name,
                Role.is_enabled,
            ),
        )
        .where(User.id == user_id)
    )
    if not include_deleted:
        stmt = stmt.where(User.is_deleted.is_(False))
    return db.execute(stmt).scalars().first()


def get_active_user_ids_by_role(db: Session, role_code: str) -> list[int]:
    """返回拥有指定角色且处于激活状态的用户 ID 列表"""
    rows = (
        db.execute(
            select(User.id)
            .join(User.roles)
            .where(
                Role.code == role_code,
                User.is_active.is_(True),
                User.is_deleted.is_(False),
            )
        )
        .scalars()
        .all()
    )
    return list(rows)


def get_user_by_username(
    db: Session,
    username: str,
    *,
    include_deleted: bool = False,
    case_insensitive: bool = True,
    load_roles: bool = True,
    load_processes: bool = True,
    load_stage: bool = True,
) -> User | None:
    normalized = normalize_username(username)
    if not normalized:
        return None
    stmt = select(User)
    loader_options = []
    if load_roles:
        loader_options.append(selectinload(User.roles))
    if load_processes:
        loader_options.append(selectinload(User.processes).selectinload(Process.stage))
    if load_stage:
        loader_options.append(selectinload(User.stage))
    if loader_options:
        stmt = stmt.options(*loader_options)
    if case_insensitive:
        stmt = stmt.where(func.lower(User.username) == normalized.lower())
    else:
        stmt = stmt.where(User.username == normalized)
    if not include_deleted:
        stmt = stmt.where(User.is_deleted.is_(False))
    return db.execute(stmt).scalars().first()


def list_all_usernames(db: Session) -> list[str]:
    stmt = (
        select(User.username)
        .where(User.is_deleted.is_(False))
        .order_by(User.username.asc())
    )
    usernames = db.execute(stmt).scalars().all()
    return sorted({username for username in usernames if username})


def list_users(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None,
    role_code: str | None = None,
    stage_id: int | None = None,
    is_online: bool | None = None,
    online_user_ids: set[int] | None = None,
    is_active: bool | None = None,
    deleted_scope: str = DELETED_SCOPE_ACTIVE,
    include_deleted: bool = False,
) -> tuple[int, list[User]]:
    effective_deleted_scope = normalize_deleted_scope(
        deleted_scope=deleted_scope,
        include_deleted=include_deleted,
    )
    conditions, requires_role_join = _build_user_filter_conditions(
        keyword=keyword,
        role_code=role_code,
        stage_id=stage_id,
        is_online=is_online,
        online_user_ids=online_user_ids,
        is_active=is_active,
        deleted_scope=effective_deleted_scope,
    )
    count_expr = (
        func.count(func.distinct(User.id))
        if requires_role_join
        else func.count(User.id)
    )
    total_stmt = select(count_expr).select_from(User)
    if requires_role_join:
        total_stmt = total_stmt.join(User.roles)
    if conditions:
        total_stmt = total_stmt.where(*conditions)
    total = int(db.execute(total_stmt).scalar_one())

    base_stmt = query_users(
        keyword=keyword,
        role_code=role_code,
        stage_id=stage_id,
        is_online=is_online,
        online_user_ids=online_user_ids,
        is_active=is_active,
        deleted_scope=effective_deleted_scope,
    )

    offset = (page - 1) * page_size
    stmt = base_stmt.offset(offset).limit(page_size)
    users = db.execute(stmt).scalars().all()
    return total, users


def _resolve_role(db: Session, role_code: str | None) -> tuple[Role | None, str | None]:
    normalized_code = (role_code or "").strip()
    if not normalized_code:
        return None, "Role is required"
    role = get_role_by_code_case_insensitive(db, normalized_code)
    if role is None:
        return None, f"Role code not found: {normalized_code}"
    if not role.is_enabled:
        return None, "Role is disabled"
    return role, None


def _can_assign_stage(role: Role | None) -> bool:
    if role is None:
        return False
    if role.code == ROLE_OPERATOR:
        return True
    if role.code == ROLE_MAINTENANCE_STAFF:
        return False
    return role.role_type == "custom" or not role.is_builtin


def _resolve_stage(
    db: Session,
    *,
    role: Role | None,
    stage_id: int | None,
) -> tuple[ProcessStage | None, str | None]:
    can_assign_stage = _can_assign_stage(role)
    is_operator = role is not None and role.code == ROLE_OPERATOR

    if not can_assign_stage:
        if stage_id is not None:
            return None, "Only operator or custom role can be assigned stage"
        return None, None

    if is_operator and stage_id is None:
        return None, "Operator role must be assigned a stage"
    if stage_id is None:
        return None, None
    stage = (
        db.execute(select(ProcessStage).where(ProcessStage.id == stage_id))
        .scalars()
        .first()
    )
    if stage is None:
        return None, "Stage not found"
    if not stage.is_enabled:
        return None, "Stage is disabled"
    return stage, None


def _resolve_processes(
    db: Session,
    *,
    role: Role | None,
    stage: ProcessStage | None,
) -> tuple[list[Process] | None, str | None]:
    is_operator = role is not None and role.code == ROLE_OPERATOR

    if not is_operator:
        return [], None

    if stage is None:
        return None, "Operator role must be assigned a stage"

    stmt = (
        select(Process)
        .where(
            Process.stage_id == stage.id,
            Process.is_enabled.is_(True),
        )
        .order_by(Process.id.asc())
    )
    processes = db.execute(stmt).scalars().all()
    return processes, None


_SYSTEM_ADMIN_GUARDRAIL_PERMISSION_CODES = {
    PERM_PAGE_FUNCTION_PERMISSION_CONFIG_VIEW,
    PERM_AUTHZ_ROLE_PERMISSIONS_UPDATE,
}


@dataclass(frozen=True)
class UserLifecycleChange:
    forced_offline_session_count: int
    cleared_online_status: bool


@dataclass(frozen=True)
class UserPasswordResetChange:
    forced_offline_session_count: int
    cleared_online_status: bool
    must_change_password: bool


def count_active_permission_admin_users(
    db: Session,
    *,
    exclude_user_id: int | None = None,
) -> int:
    effective_codes = get_permission_codes_for_role_codes(
        db,
        role_codes=[ROLE_SYSTEM_ADMIN],
        module_code="system",
    )
    if not _SYSTEM_ADMIN_GUARDRAIL_PERMISSION_CODES.issubset(effective_codes):
        return 0
    return count_active_system_admin_users(db, exclude_user_id=exclude_user_id)


def _pick_highest_priority_role(roles: list[Role]) -> Role | None:
    if not roles:
        return None
    return min(
        roles,
        key=lambda role: (
            ROLE_PRIORITY_INDEX.get(role.code, len(ROLE_PRIORITY_INDEX)),
            role.code,
        ),
    )


def count_active_system_admin_users(
    db: Session, *, exclude_user_id: int | None = None
) -> int:
    stmt = (
        select(func.count(User.id))
        .select_from(User)
        .join(User.roles)
        .where(
            User.is_deleted.is_(False),
            User.is_active.is_(True),
            Role.code == ROLE_SYSTEM_ADMIN,
        )
    )
    if exclude_user_id is not None:
        stmt = stmt.where(User.id != exclude_user_id)
    return int(db.execute(stmt).scalar_one())


def ensure_can_deactivate_user(db: Session, user: User) -> tuple[bool, str | None]:
    role_codes = {role.code for role in user.roles}
    if ROLE_SYSTEM_ADMIN not in role_codes:
        return True, None
    remaining = count_active_permission_admin_users(db, exclude_user_id=user.id)
    if remaining < 1:
        return False, "必须至少保留一个可进入功能权限配置页面的系统管理员账号"
    return True, None


def _apply_user_active_state(
    db: Session,
    *,
    user: User,
    active: bool,
) -> tuple[UserLifecycleChange | None, str | None]:
    if user.is_deleted and active:
        return None, "Deleted user cannot be enabled"
    if user.is_active == active:
        return UserLifecycleChange(
            forced_offline_session_count=0,
            cleared_online_status=False,
        ), None
    if not active:
        can_deactivate, message = ensure_can_deactivate_user(db, user)
        if not can_deactivate:
            return None, message

    forced_offline_session_count = 0
    cleared_online_status = False
    if not active:
        active_session_token_ids = db.execute(
            select(UserSession.session_token_id).where(
                UserSession.user_id == user.id,
                UserSession.status == "active",
            )
        ).scalars().all()
        if active_session_token_ids:
            forced_offline_session_count = force_offline_sessions(
                db,
                session_token_ids=list(active_session_token_ids),
            )
        is_online, _ = get_user_online_snapshot(user.id)
        clear_user(user.id)
        cleared_online_status = is_online

    user.is_active = active
    db.flush()
    return UserLifecycleChange(
        forced_offline_session_count=forced_offline_session_count,
        cleared_online_status=cleared_online_status,
    ), None


def normalize_users_to_single_role(db: Session) -> int:
    stmt = (
        select(User)
        .options(
            selectinload(User.roles),
            selectinload(User.processes),
            selectinload(User.stage),
        )
        .order_by(User.id.asc())
    )
    users = db.execute(stmt).scalars().all()
    normalized_users_count = 0
    changed = False

    for user in users:
        user_changed = False

        if len(user.roles) > 1:
            primary_role = _pick_highest_priority_role(list(user.roles))
            if primary_role is not None:
                user.roles = [primary_role]
                user_changed = True

        role_codes = [role.code for role in user.roles]
        is_operator = ROLE_OPERATOR in role_codes

        if not is_operator:
            if user.processes:
                user.processes = []
                user_changed = True
            if user.stage_id is not None:
                user.stage_id = None
                user_changed = True
        elif user.stage_id is None and user.processes:
            first_stage_id = user.processes[0].stage_id
            if first_stage_id is not None:
                user.stage_id = first_stage_id
                user_changed = True

        if user_changed:
            normalized_users_count += 1
            changed = True

    if changed:
        db.commit()

    return normalized_users_count


def ensure_admin_account(
    db: Session,
    password: str,
    repair_role: bool = True,
) -> tuple[User, bool, bool]:
    roles, missing_role_codes = get_roles_by_codes(db, [ROLE_SYSTEM_ADMIN])
    if missing_role_codes or not roles:
        raise ValueError("System admin role is not initialized")
    system_admin_role = roles[0]

    created = False
    role_repaired = False
    should_commit = False

    admin_user = get_user_by_username(db, "admin", include_deleted=True)
    if not admin_user:
        admin_user = User(
            username="admin",
            full_name="system admin",
            password_hash=get_password_hash(password),
            is_active=True,
            is_superuser=False,
            is_deleted=False,
            must_change_password=False,
            password_changed_at=_now_utc(),
        )
        admin_user.roles = [system_admin_role]
        admin_user.processes = []
        admin_user.stage_id = None
        db.add(admin_user)
        created = True
        should_commit = True
    elif repair_role:
        role_map = {role.code: role for role in admin_user.roles}
        if ROLE_SYSTEM_ADMIN not in role_map:
            role_map[ROLE_SYSTEM_ADMIN] = system_admin_role
            admin_user.roles = list(role_map.values())
            role_repaired = True
            should_commit = True
        if admin_user.is_deleted:
            admin_user.is_deleted = False
            admin_user.deleted_at = None
            admin_user.is_active = True
            should_commit = True

    if should_commit:
        db.commit()
        db.refresh(admin_user)

    return admin_user, created, role_repaired


def create_user(db: Session, payload: UserCreate) -> tuple[User | None, str | None]:
    account_name = normalize_username(payload.username)
    if not account_name:
        return None, "Username is required"
    existing = get_user_by_username(db, account_name)
    if existing:
        return None, "Username already exists"

    pwd_error = validate_password(payload.password)
    if pwd_error:
        return None, pwd_error

    role, role_error = _resolve_role(db, payload.role_code)
    if role_error:
        return None, role_error

    stage, stage_error = _resolve_stage(db, role=role, stage_id=payload.stage_id)
    if stage_error:
        return None, stage_error
    processes, processes_error = _resolve_processes(
        db,
        role=role,
        stage=stage,
    )
    if processes_error:
        return None, processes_error

    user = User(
        username=account_name,
        full_name=payload.full_name if payload.full_name else account_name,
        remark=payload.remark.strip() if payload.remark else None,
        password_hash=get_password_hash(payload.password),
        is_active=payload.is_active,
        is_superuser=False,
        is_deleted=False,
        must_change_password=True,
        stage_id=stage.id if stage else None,
    )
    user.roles = [role] if role else []
    user.processes = processes or []
    db.add(user)
    db.flush()
    db.refresh(user)
    return user, None


def get_registration_request_by_id(
    db: Session, request_id: int
) -> RegistrationRequest | None:
    stmt = select(RegistrationRequest).where(RegistrationRequest.id == request_id)
    return db.execute(stmt).scalars().first()


def get_registration_request_by_account(
    db: Session,
    account: str,
    *,
    pending_only: bool = False,
) -> RegistrationRequest | None:
    normalized = normalize_username(account)
    stmt = select(RegistrationRequest).where(
        func.lower(RegistrationRequest.account) == normalized.lower()
    )
    if pending_only:
        stmt = stmt.where(RegistrationRequest.status == REG_STATUS_PENDING)
    stmt = stmt.order_by(RegistrationRequest.id.desc())
    return db.execute(stmt).scalars().first()


def list_registration_requests(
    db: Session,
    *,
    page: int,
    page_size: int,
    keyword: str | None = None,
    status: str | None = None,
) -> tuple[int, list[RegistrationRequest]]:
    stmt = select(RegistrationRequest).order_by(RegistrationRequest.id.asc())
    filters: list[object] = []
    if keyword:
        filters.append(RegistrationRequest.account.ilike(f"%{keyword}%"))
    if status:
        filters.append(RegistrationRequest.status == status.strip())
    if filters:
        stmt = stmt.where(*filters)

    total_stmt = select(func.count(RegistrationRequest.id))
    if filters:
        total_stmt = total_stmt.where(*filters)
    total = int(db.execute(total_stmt).scalar_one())

    offset = (page - 1) * page_size
    paged_stmt = stmt.offset(offset).limit(page_size)
    requests = db.execute(paged_stmt).scalars().all()
    return total, requests


def submit_registration_request(
    db: Session,
    *,
    account: str,
    password: str,
) -> tuple[RegistrationRequest | None, str | None]:
    account_name = normalize_username(account)
    if not account_name:
        return None, "Account is required"

    pwd_error = validate_password(password)
    if pwd_error:
        return None, pwd_error

    existing = get_user_by_username(db, account_name)
    if existing:
        return None, "Username already exists"

    pending = get_registration_request_by_account(db, account_name, pending_only=True)
    if pending:
        return None, "Registration request is pending approval"

    request = RegistrationRequest(
        account=account_name,
        password_hash=get_password_hash(password),
        status=REG_STATUS_PENDING,
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return request, None


def approve_registration_request(
    db: Session,
    *,
    request: RegistrationRequest,
    account: str,
    password: str,
    role_code: str,
    stage_id: int | None,
    reviewer: User | None,
) -> tuple[User | None, str | None]:
    if request.status != REG_STATUS_PENDING:
        return None, "Registration request is not pending"

    if not password:
        return None, "初始密码不能为空"

    password_error = validate_password(password)
    if password_error:
        return None, password_error

    account_name = normalize_username(account)
    if not account_name:
        return None, "Account is required"

    existing = get_user_by_username(db, account_name)
    if existing:
        return None, "Username already exists"

    role, role_error = _resolve_role(db, role_code)
    if role_error:
        return None, role_error

    stage, stage_error = _resolve_stage(db, role=role, stage_id=stage_id)
    if stage_error:
        return None, stage_error
    processes, processes_error = _resolve_processes(
        db,
        role=role,
        stage=stage,
    )
    if processes_error:
        return None, processes_error

    password_hash = get_password_hash(password)
    user = User(
        username=account_name,
        full_name=account_name,
        password_hash=password_hash,
        is_active=True,
        is_superuser=False,
        is_deleted=False,
        must_change_password=True,
        stage_id=stage.id if stage else None,
    )
    user.roles = [role] if role else []
    user.processes = processes or []
    db.add(user)

    request.status = REG_STATUS_APPROVED
    request.rejected_reason = None
    request.reviewed_by_user_id = reviewer.id if reviewer else None
    request.reviewed_at = _now_utc()

    db.commit()
    db.refresh(user)
    db.refresh(request)
    return user, None


def reject_registration_request(
    db: Session,
    *,
    request: RegistrationRequest,
    reason: str | None,
    reviewer: User | None,
) -> tuple[RegistrationRequest | None, str | None]:
    if request.status != REG_STATUS_PENDING:
        return None, "Registration request is not pending"

    request.status = REG_STATUS_REJECTED
    request.rejected_reason = reason.strip() if reason else None
    request.reviewed_by_user_id = reviewer.id if reviewer else None
    request.reviewed_at = _now_utc()
    db.commit()
    db.refresh(request)
    return request, None


def update_user(
    db: Session,
    *,
    user: User,
    payload: UserUpdate,
    operator: User | None = None,
) -> tuple[User | None, str | None]:
    primary_role_before = _pick_highest_priority_role(list(user.roles))
    role_code_before = primary_role_before.code if primary_role_before else None
    was_active = user.is_active

    if payload.username is not None:
        account_name = normalize_username(payload.username)
        if not account_name:
            return None, "Username is required"
        if account_name.lower() != user.username.lower():
            operator_role_codes = (
                {role.code for role in operator.roles} if operator else set()
            )
            if ROLE_SYSTEM_ADMIN not in operator_role_codes:
                return None, "Only system administrator can modify username"
            existing = get_user_by_username(db, account_name)
            if existing and existing.id != user.id:
                return None, "Username already exists"
            user.username = account_name
        if payload.full_name is None:
            user.full_name = user.username

    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.remark is not None:
        user.remark = payload.remark.strip() if payload.remark else None
    if payload.must_change_password is not None:
        user.must_change_password = payload.must_change_password

    if payload.role_code is not None:
        role, role_error = _resolve_role(db, payload.role_code)
        if role_error:
            return None, role_error
        user.roles = [role] if role else []

    current_role = _pick_highest_priority_role(list(user.roles))
    current_role_code = current_role.code if current_role else None
    if current_role_code is None:
        return None, "User role is required"
    stage_id_for_resolve = payload.stage_id
    if stage_id_for_resolve is None and _can_assign_stage(current_role):
        stage_id_for_resolve = user.stage_id
    stage, stage_error = _resolve_stage(
        db,
        role=current_role,
        stage_id=stage_id_for_resolve,
    )
    if stage_error:
        return None, stage_error
    processes, processes_error = _resolve_processes(
        db,
        role=current_role,
        stage=stage,
    )
    if processes_error:
        return None, processes_error
    user.processes = processes or []
    user.stage_id = stage.id if stage else None

    if payload.is_active is not None:
        lifecycle_change, message = _apply_user_active_state(
            db,
            user=user,
            active=payload.is_active,
        )
        if message:
            return None, message
        _ = lifecycle_change

    role_code_after = current_role_code
    if (
        role_code_before == ROLE_SYSTEM_ADMIN
        and role_code_after != ROLE_SYSTEM_ADMIN
        and was_active
        and user.is_active
    ):
        remaining = count_active_permission_admin_users(db, exclude_user_id=user.id)
        if remaining < 1:
            return None, "必须至少保留一个可进入功能权限配置页面的系统管理员账号"

    db.commit()
    db.refresh(user)
    return user, None


def set_user_active(
    db: Session,
    *,
    user: User,
    active: bool,
) -> tuple[tuple[User, UserLifecycleChange] | None, str | None]:
    lifecycle_change, message = _apply_user_active_state(
        db,
        user=user,
        active=active,
    )
    if message:
        return None, message
    assert lifecycle_change is not None
    db.commit()
    db.refresh(user)
    return (user, lifecycle_change), None


def reset_user_password(
    db: Session,
    *,
    user: User,
    new_password: str,
) -> tuple[tuple[User, UserPasswordResetChange] | None, str | None]:
    pwd_error = validate_password(new_password)
    if pwd_error:
        return None, pwd_error
    if verify_password(new_password, user.password_hash):
        return None, "新密码不能与当前密码相同"
    now = _now_utc()
    is_online, _ = get_user_online_snapshot(user.id)
    active_session_token_ids = (
        db.execute(
            select(UserSession.session_token_id).where(
                UserSession.user_id == user.id,
                UserSession.status == "active",
            )
        )
        .scalars()
        .all()
    )
    forced_offline_session_count = 0
    if active_session_token_ids:
        forced_offline_session_count = force_offline_sessions(
            db,
            session_token_ids=list(active_session_token_ids),
        )
    clear_user(user.id)
    user.password_hash = get_password_hash(new_password)
    user.must_change_password = True
    user.password_changed_at = now
    db.commit()
    db.refresh(user)
    return (
        user,
        UserPasswordResetChange(
            forced_offline_session_count=forced_offline_session_count,
            cleared_online_status=is_online,
            must_change_password=user.must_change_password,
        ),
    ), None


def change_user_password(
    db: Session,
    *,
    user: User,
    old_password: str,
    new_password: str,
    confirm_password: str,
) -> tuple[bool, str | None]:
    if not verify_password(old_password, user.password_hash):
        return False, "原密码不正确"
    if new_password != confirm_password:
        return False, "新密码与确认密码不一致"
    if old_password == new_password:
        return False, "新密码不能与原密码相同"
    pwd_error = validate_password(new_password)
    if pwd_error:
        return False, pwd_error
    user.password_hash = get_password_hash(new_password)
    user.must_change_password = False
    user.password_changed_at = _now_utc()
    db.commit()
    return True, None


def delete_user(
    db: Session,
    *,
    user: User,
) -> tuple[tuple[User, UserLifecycleChange] | None, str | None]:
    if user.is_deleted:
        return (
            user,
            UserLifecycleChange(
                forced_offline_session_count=0,
                cleared_online_status=False,
            ),
        ), None
    lifecycle_change, message = _apply_user_active_state(
        db,
        user=user,
        active=False,
    )
    if message:
        return None, message
    assert lifecycle_change is not None
    user.is_deleted = True
    user.deleted_at = _now_utc()
    db.commit()
    db.refresh(user)
    return (user, lifecycle_change), None


def restore_user(
    db: Session,
    *,
    user: User,
) -> tuple[tuple[User, UserLifecycleChange] | None, str | None]:
    if not user.is_deleted:
        return (
            user,
            UserLifecycleChange(
                forced_offline_session_count=0,
                cleared_online_status=False,
            ),
        ), None
    user.is_deleted = False
    user.deleted_at = None
    user.is_active = False
    db.commit()
    db.refresh(user)
    return (
        user,
        UserLifecycleChange(
            forced_offline_session_count=0,
            cleared_online_status=False,
        ),
    ), None

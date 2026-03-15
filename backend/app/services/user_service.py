from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session, selectinload

from app.core.rbac import (
    ROLE_MAINTENANCE_STAFF,
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
    VALID_ROLE_CODES,
)
from app.core.security import get_password_hash, verify_password
from app.models.process import Process
from app.models.process_stage import ProcessStage
from app.models.registration_request import RegistrationRequest
from app.models.role import Role
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.services.process_service import get_processes_by_codes
from app.services.role_service import get_roles_by_codes


REG_STATUS_PENDING = "pending"
REG_STATUS_APPROVED = "approved"
REG_STATUS_REJECTED = "rejected"


def validate_password(password: str, db: Session | None = None, exclude_user_id: int | None = None) -> str | None:
    """校验密码规则，返回错误信息或 None。"""
    if len(password) < 6:
        return "密码长度不能少于6位"
    # 不得连续4位相同字符
    for i in range(len(password) - 3):
        if password[i] == password[i + 1] == password[i + 2] == password[i + 3]:
            return "密码不得包含连续4位相同字符"
    # 不支持与已有用户相同密码
    if db is not None:
        stmt = select(User).where(User.is_deleted.is_(False))
        if exclude_user_id is not None:
            stmt = stmt.where(User.id != exclude_user_id)
        users = db.execute(stmt).scalars().all()
        for u in users:
            if verify_password(password, u.password_hash):
                return "密码不能与系统中已有用户的密码相同"
    return None


def _now_utc() -> datetime:
    return datetime.now(UTC)


def normalize_username(username: str) -> str:
    return username.strip()


def _normalize_codes(codes: list[str]) -> list[str]:
    return sorted({code.strip() for code in codes if code and code.strip()})


def _validate_role_codes(role_codes: list[str]) -> tuple[list[str], list[str]]:
    normalized_codes = _normalize_codes(role_codes)
    invalid_codes = [code for code in normalized_codes if code not in VALID_ROLE_CODES]
    return normalized_codes, invalid_codes


ROLE_PRIORITY = [
    ROLE_SYSTEM_ADMIN,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_MAINTENANCE_STAFF,
    ROLE_OPERATOR,
]
ROLE_PRIORITY_INDEX = {code: index for index, code in enumerate(ROLE_PRIORITY)}


def query_users(
    *,
    keyword: str | None,
    role_code: str | None = None,
    stage_id: int | None = None,
    is_online: bool | None = None,
    online_user_ids: set[int] | None = None,
    is_active: bool | None = None,
    include_deleted: bool = False,
) -> Select[tuple[User]]:
    stmt = (
        select(User)
        .options(
            selectinload(User.roles),
            selectinload(User.processes).selectinload(Process.stage),
            selectinload(User.stage),
        )
        .order_by(User.id.asc())
    )
    if not include_deleted:
        stmt = stmt.where(User.is_deleted.is_(False))
    if keyword:
        like_pattern = f"%{keyword}%"
        stmt = stmt.where(User.username.ilike(like_pattern))
    if role_code:
        stmt = stmt.join(User.roles).where(Role.code == role_code)
    if stage_id is not None:
        stmt = stmt.where(User.stage_id == stage_id)
    if is_online is not None:
        effective_online_user_ids = online_user_ids or set()
        if is_online:
            if not effective_online_user_ids:
                stmt = stmt.where(User.id == -1)
            else:
                stmt = stmt.where(User.id.in_(effective_online_user_ids))
        elif effective_online_user_ids:
            stmt = stmt.where(~User.id.in_(effective_online_user_ids))
    if is_active is not None:
        stmt = stmt.where(User.is_active.is_(is_active))
    return stmt


def get_user_by_id(db: Session, user_id: int, *, include_deleted: bool = False) -> User | None:
    stmt = (
        select(User)
        .options(
            selectinload(User.roles),
            selectinload(User.processes).selectinload(Process.stage),
            selectinload(User.stage),
        )
        .where(User.id == user_id)
    )
    if not include_deleted:
        stmt = stmt.where(User.is_deleted.is_(False))
    return db.execute(stmt).scalars().first()


def get_active_user_ids_by_role(db: Session, role_code: str) -> list[int]:
    """返回拥有指定角色且处于激活状态的用户 ID 列表"""
    rows = db.execute(
        select(User.id)
        .join(User.roles)
        .where(
            Role.code == role_code,
            User.is_active.is_(True),
            User.is_deleted.is_(False),
        )
    ).scalars().all()
    return list(rows)


def get_user_by_username(
    db: Session,
    username: str,
    *,
    include_deleted: bool = False,
    case_insensitive: bool = True,
) -> User | None:
    normalized = normalize_username(username)
    if not normalized:
        return None
    stmt = (
        select(User)
        .options(
            selectinload(User.roles),
            selectinload(User.processes).selectinload(Process.stage),
            selectinload(User.stage),
        )
    )
    if case_insensitive:
        stmt = stmt.where(func.lower(User.username) == normalized.lower())
    else:
        stmt = stmt.where(User.username == normalized)
    if not include_deleted:
        stmt = stmt.where(User.is_deleted.is_(False))
    return db.execute(stmt).scalars().first()


def list_all_usernames(db: Session) -> list[str]:
    stmt = select(User.username).where(User.is_deleted.is_(False)).order_by(User.username.asc())
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
    include_deleted: bool = False,
) -> tuple[int, list[User]]:
    base_stmt = query_users(
        keyword=keyword,
        role_code=role_code,
        stage_id=stage_id,
        is_online=is_online,
        online_user_ids=online_user_ids,
        is_active=is_active,
        include_deleted=include_deleted,
    )
    total_stmt = select(func.count()).select_from(base_stmt.subquery())
    total = int(db.execute(total_stmt).scalar_one())

    offset = (page - 1) * page_size
    stmt = base_stmt.offset(offset).limit(page_size)
    users = db.execute(stmt).scalars().all()
    return total, users


def _resolve_roles(db: Session, role_codes: list[str]) -> tuple[list[Role] | None, str | None]:
    normalized_codes, invalid_codes = _validate_role_codes(role_codes)
    if invalid_codes:
        return None, f"Invalid role codes: {', '.join(invalid_codes)}"
    if len(normalized_codes) != 1:
        return None, "Exactly one role is required"

    roles, missing_role_codes = get_roles_by_codes(db, normalized_codes)
    if missing_role_codes:
        return None, f"Role codes not found: {', '.join(missing_role_codes)}"
    role = roles[0]
    if not role.is_enabled:
        return None, "Role is disabled"
    return roles, None


def _resolve_stage(
    db: Session,
    *,
    role_codes: list[str],
    stage_id: int | None,
) -> tuple[ProcessStage | None, str | None]:
    is_operator = ROLE_OPERATOR in role_codes
    if not is_operator:
        if stage_id is not None:
            return None, "Only operator role can be assigned stage"
        return None, None

    if stage_id is None:
        return None, "Operator role must be assigned a stage"
    stage = db.execute(select(ProcessStage).where(ProcessStage.id == stage_id)).scalars().first()
    if stage is None:
        return None, "Stage not found"
    if not stage.is_enabled:
        return None, "Stage is disabled"
    return stage, None


def _resolve_processes(
    db: Session,
    *,
    role_codes: list[str],
    stage: ProcessStage | None,
    process_codes: list[str],
) -> tuple[list[Process] | None, str | None]:
    normalized_process_codes = _normalize_codes(process_codes)
    is_operator = ROLE_OPERATOR in role_codes

    if not is_operator:
        if normalized_process_codes:
            return None, "Only operator role can be assigned processes"
        return [], None

    if normalized_process_codes:
        processes, missing_process_codes = get_processes_by_codes(db, normalized_process_codes)
        if missing_process_codes:
            return None, f"Process codes not found: {', '.join(missing_process_codes)}"
        if stage is not None:
            out_of_stage = [process.code for process in processes if process.stage_id != stage.id]
            if out_of_stage:
                return None, f"Process not in selected stage: {', '.join(out_of_stage)}"
        return processes, None

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
    if not processes:
        return None, "Selected stage has no enabled processes"
    return processes, None


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


def count_active_system_admin_users(db: Session, *, exclude_user_id: int | None = None) -> int:
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
    remaining = count_active_system_admin_users(db, exclude_user_id=user.id)
    if remaining < 1:
        return False, "At least one active system administrator account must be retained"
    return True, None


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

    pwd_error = validate_password(payload.password, db=db)
    if pwd_error:
        return None, pwd_error

    roles, roles_error = _resolve_roles(db, payload.role_codes)
    if roles_error:
        return None, roles_error

    role_codes = [role.code for role in roles or []]
    stage, stage_error = _resolve_stage(db, role_codes=role_codes, stage_id=payload.stage_id)
    if stage_error:
        return None, stage_error
    processes, processes_error = _resolve_processes(
        db,
        role_codes=role_codes,
        stage=stage,
        process_codes=payload.process_codes,
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
    user.roles = roles or []
    user.processes = processes or []
    db.add(user)
    db.commit()
    db.refresh(user)
    return user, None


def get_registration_request_by_id(db: Session, request_id: int) -> RegistrationRequest | None:
    stmt = select(RegistrationRequest).where(RegistrationRequest.id == request_id)
    return db.execute(stmt).scalars().first()


def get_registration_request_by_account(
    db: Session,
    account: str,
    *,
    pending_only: bool = False,
) -> RegistrationRequest | None:
    normalized = normalize_username(account)
    stmt = select(RegistrationRequest).where(func.lower(RegistrationRequest.account) == normalized.lower())
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
    if keyword:
        stmt = stmt.where(RegistrationRequest.account.ilike(f"%{keyword}%"))
    if status:
        stmt = stmt.where(RegistrationRequest.status == status.strip())

    total_stmt = select(func.count()).select_from(stmt.subquery())
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
    role_codes: list[str],
    process_codes: list[str],
    stage_id: int | None,
    reviewer: User | None,
) -> tuple[User | None, str | None]:
    if request.status != REG_STATUS_PENDING:
        return None, "Registration request is not pending"

    if not password or len(password.strip()) < 6:
        return None, "Initial password is required and must be at least 6 characters"

    password_error = validate_password(password, db=db)
    if password_error:
        return None, password_error

    account_name = normalize_username(account)
    if not account_name:
        return None, "Account is required"

    existing = get_user_by_username(db, account_name)
    if existing:
        return None, "Username already exists"

    roles, roles_error = _resolve_roles(db, role_codes)
    if roles_error:
        return None, roles_error

    resolved_role_codes = [role.code for role in roles or []]
    stage, stage_error = _resolve_stage(db, role_codes=resolved_role_codes, stage_id=stage_id)
    if stage_error:
        return None, stage_error
    processes, processes_error = _resolve_processes(
        db,
        role_codes=resolved_role_codes,
        stage=stage,
        process_codes=process_codes,
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
    user.roles = roles or []
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
) -> RegistrationRequest:
    request.status = REG_STATUS_REJECTED
    request.rejected_reason = reason.strip() if reason else None
    request.reviewed_by_user_id = reviewer.id if reviewer else None
    request.reviewed_at = _now_utc()
    db.commit()
    db.refresh(request)
    return request


def update_user(
    db: Session,
    *,
    user: User,
    payload: UserUpdate,
    operator: User | None = None,
) -> tuple[User | None, str | None]:
    role_codes_before = {role.code for role in user.roles}
    was_active = user.is_active

    if payload.username is not None:
        account_name = normalize_username(payload.username)
        if not account_name:
            return None, "Username is required"
        if account_name.lower() != user.username.lower():
            operator_role_codes = {role.code for role in operator.roles} if operator else set()
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
    if payload.password:
        pwd_error = validate_password(payload.password, db=db, exclude_user_id=user.id)
        if pwd_error:
            return None, pwd_error
        user.password_hash = get_password_hash(payload.password)
        user.must_change_password = bool(payload.must_change_password) if payload.must_change_password is not None else True
        user.password_changed_at = _now_utc()
    elif payload.must_change_password is not None:
        user.must_change_password = payload.must_change_password

    if payload.role_codes is not None:
        roles, roles_error = _resolve_roles(db, payload.role_codes)
        if roles_error:
            return None, roles_error
        user.roles = roles or []

    current_role_codes = [role.code for role in user.roles]
    stage_id_for_resolve = payload.stage_id
    if stage_id_for_resolve is None and ROLE_OPERATOR in current_role_codes:
        stage_id_for_resolve = user.stage_id
    stage, stage_error = _resolve_stage(
        db,
        role_codes=current_role_codes,
        stage_id=stage_id_for_resolve,
    )
    if stage_error:
        return None, stage_error
    requested_process_codes = (
        payload.process_codes if payload.process_codes is not None else [process.code for process in user.processes]
    )
    processes, processes_error = _resolve_processes(
        db,
        role_codes=current_role_codes,
        stage=stage,
        process_codes=requested_process_codes,
    )
    if processes_error:
        return None, processes_error
    user.processes = processes or []
    user.stage_id = stage.id if stage else None

    if payload.is_active is not None:
        if not payload.is_active and user.is_active:
            can_deactivate, message = ensure_can_deactivate_user(db, user)
            if not can_deactivate:
                return None, message
        user.is_active = payload.is_active

    role_codes_after = {role.code for role in user.roles}
    if ROLE_SYSTEM_ADMIN in role_codes_before and ROLE_SYSTEM_ADMIN not in role_codes_after and was_active and user.is_active:
        remaining = count_active_system_admin_users(db, exclude_user_id=user.id)
        if remaining < 1:
            return None, "At least one active system administrator account must be retained"

    db.commit()
    db.refresh(user)
    return user, None


def set_user_active(
    db: Session,
    *,
    user: User,
    active: bool,
) -> tuple[User | None, str | None]:
    if user.is_deleted:
        return None, "Deleted user cannot be enabled"
    if user.is_active == active:
        return user, None
    if not active:
        can_deactivate, message = ensure_can_deactivate_user(db, user)
        if not can_deactivate:
            return None, message
    user.is_active = active
    db.commit()
    db.refresh(user)
    return user, None


def reset_user_password(
    db: Session,
    *,
    user: User,
    new_password: str,
) -> tuple[User | None, str | None]:
    pwd_error = validate_password(new_password, db=db, exclude_user_id=user.id)
    if pwd_error:
        return None, pwd_error
    user.password_hash = get_password_hash(new_password)
    user.must_change_password = True
    user.password_changed_at = _now_utc()
    db.commit()
    db.refresh(user)
    return user, None


def change_user_password(
    db: Session,
    *,
    user: User,
    old_password: str,
    new_password: str,
    confirm_password: str,
) -> tuple[bool, str | None]:
    if not verify_password(old_password, user.password_hash):
        return False, "Original password is incorrect"
    if new_password != confirm_password:
        return False, "New password and confirm password do not match"
    if old_password == new_password:
        return False, "New password cannot be the same as original password"
    pwd_error = validate_password(new_password, db=db, exclude_user_id=user.id)
    if pwd_error:
        return False, pwd_error
    user.password_hash = get_password_hash(new_password)
    user.must_change_password = False
    user.password_changed_at = _now_utc()
    db.commit()
    return True, None


def delete_user(db: Session, *, user: User) -> tuple[bool, str | None]:
    if user.is_deleted:
        return True, None
    can_deactivate, message = ensure_can_deactivate_user(db, user)
    if not can_deactivate:
        return False, message
    user.is_deleted = True
    user.deleted_at = _now_utc()
    user.is_active = False
    db.commit()
    return True, None

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session, selectinload

from app.core.rbac import (
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
    VALID_ROLE_CODES,
)
from app.core.security import get_password_hash
from app.models.process import Process
from app.models.registration_request import RegistrationRequest
from app.models.role import Role
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.services.process_service import get_processes_by_codes
from app.services.role_service import get_roles_by_codes


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
    ROLE_OPERATOR,
]
ROLE_PRIORITY_INDEX = {code: index for index, code in enumerate(ROLE_PRIORITY)}


def query_users(keyword: str | None) -> Select[tuple[User]]:
    stmt = (
        select(User)
        .options(
            selectinload(User.roles),
            selectinload(User.processes),
        )
        .order_by(User.id.asc())
    )
    if keyword:
        like_pattern = f"%{keyword}%"
        stmt = stmt.where(User.username.ilike(like_pattern))
    return stmt


def get_user_by_id(db: Session, user_id: int) -> User | None:
    stmt = (
        select(User)
        .options(
            selectinload(User.roles),
            selectinload(User.processes),
        )
        .where(User.id == user_id)
    )
    return db.execute(stmt).scalars().first()


def get_user_by_username(db: Session, username: str) -> User | None:
    stmt = (
        select(User)
        .options(
            selectinload(User.roles),
            selectinload(User.processes),
        )
        .where(User.username == username)
    )
    return db.execute(stmt).scalars().first()


def list_all_usernames(db: Session) -> list[str]:
    stmt = select(User.username).order_by(User.username.asc())
    usernames = db.execute(stmt).scalars().all()
    return sorted({username for username in usernames if username})


def list_users(db: Session, page: int, page_size: int, keyword: str | None) -> tuple[int, list[User]]:
    base_stmt = query_users(keyword)
    total_stmt = select(func.count()).select_from(base_stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

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
    return roles, None


def _resolve_processes(
    db: Session,
    role_codes: list[str],
    process_codes: list[str],
) -> tuple[list[Process] | None, str | None]:
    normalized_process_codes = _normalize_codes(process_codes)
    is_operator = ROLE_OPERATOR in role_codes

    if is_operator and len(normalized_process_codes) != 1:
        return None, "Operator role must be assigned exactly one process"

    if not is_operator:
        if normalized_process_codes:
            return None, "Only operator role can be assigned processes"
        return [], None

    processes, missing_process_codes = get_processes_by_codes(db, normalized_process_codes)
    if missing_process_codes:
        return None, f"Process codes not found: {', '.join(missing_process_codes)}"
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


def normalize_users_to_single_role(db: Session) -> int:
    stmt = (
        select(User)
        .options(
            selectinload(User.roles),
            selectinload(User.processes),
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

        if not is_operator and user.processes:
            user.processes = []
            user_changed = True

        if is_operator and len(user.processes) > 1:
            preferred_process = min(user.processes, key=lambda process: (process.code, process.id))
            user.processes = [preferred_process]
            user_changed = True

        if user_changed:
            normalized_users_count += 1
            changed = True

    if changed:
        db.commit()

    return normalized_users_count


def ensure_admin_account(
    db: Session,
    password: str = "123456",
    repair_role: bool = True,
) -> tuple[User, bool, bool]:
    roles, missing_role_codes = get_roles_by_codes(db, [ROLE_SYSTEM_ADMIN])
    if missing_role_codes or not roles:
        raise ValueError("System admin role is not initialized")
    system_admin_role = roles[0]

    created = False
    role_repaired = False
    should_commit = False

    admin_user = get_user_by_username(db, "admin")
    if not admin_user:
        admin_user = User(
            username="admin",
            full_name="system admin",
            password_hash=get_password_hash(password),
            is_active=True,
            is_superuser=False,
        )
        admin_user.roles = [system_admin_role]
        admin_user.processes = []
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

    if should_commit:
        db.commit()
        db.refresh(admin_user)

    return admin_user, created, role_repaired


def create_user(db: Session, payload: UserCreate) -> tuple[User | None, str | None]:
    roles, roles_error = _resolve_roles(db, payload.role_codes)
    if roles_error:
        return None, roles_error

    role_codes = [role.code for role in roles or []]
    processes, processes_error = _resolve_processes(db, role_codes, payload.process_codes)
    if processes_error:
        return None, processes_error

    user = User(
        username=payload.username,
        full_name=payload.full_name if payload.full_name else payload.username,
        password_hash=get_password_hash(payload.password),
        is_active=True,
        is_superuser=False,
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


def get_registration_request_by_account(db: Session, account: str) -> RegistrationRequest | None:
    stmt = select(RegistrationRequest).where(RegistrationRequest.account == account)
    return db.execute(stmt).scalars().first()


def list_registration_requests(
    db: Session,
    page: int,
    page_size: int,
    keyword: str | None = None,
) -> tuple[int, list[RegistrationRequest]]:
    stmt = select(RegistrationRequest).order_by(RegistrationRequest.created_at.asc())
    if keyword:
        stmt = stmt.where(RegistrationRequest.account.ilike(f"%{keyword}%"))

    total_stmt = select(func.count()).select_from(stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    paged_stmt = stmt.offset(offset).limit(page_size)
    requests = db.execute(paged_stmt).scalars().all()
    return total, requests


def submit_registration_request(
    db: Session,
    account: str,
    password: str,
) -> tuple[RegistrationRequest | None, str | None]:
    account_name = account.strip()
    if not account_name:
        return None, "Account is required"

    existing = get_user_by_username(db, account_name)
    if existing:
        return None, "Username already exists"

    pending = get_registration_request_by_account(db, account_name)
    if pending:
        return None, "Registration request is pending approval"

    request = RegistrationRequest(
        account=account_name,
        password_hash=get_password_hash(password),
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return request, None


def approve_registration_request(
    db: Session,
    request: RegistrationRequest,
    account: str,
    role_codes: list[str],
    process_codes: list[str],
) -> tuple[User | None, str | None]:
    account_name = account.strip()
    if not account_name:
        return None, "Account is required"

    existing = get_user_by_username(db, account_name)
    if existing:
        return None, "Username already exists"

    pending_request = get_registration_request_by_account(db, account_name)
    if pending_request and pending_request.id != request.id:
        return None, "Account already exists in pending registration requests"

    roles, roles_error = _resolve_roles(db, role_codes)
    if roles_error:
        return None, roles_error

    resolved_role_codes = [role.code for role in roles or []]
    processes, processes_error = _resolve_processes(db, resolved_role_codes, process_codes)
    if processes_error:
        return None, processes_error

    user = User(
        username=account_name,
        full_name=account_name,
        password_hash=request.password_hash,
        is_active=True,
        is_superuser=False,
    )
    user.roles = roles or []
    user.processes = processes or []
    db.add(user)
    db.delete(request)
    db.commit()
    db.refresh(user)
    return user, None


def reject_registration_request(db: Session, request: RegistrationRequest) -> None:
    db.delete(request)
    db.commit()


def update_user(db: Session, user: User, payload: UserUpdate) -> tuple[User | None, str | None]:
    if payload.username is not None:
        account_name = payload.username.strip()
        if not account_name:
            return None, "Username is required"
        existing = get_user_by_username(db, account_name)
        if existing and existing.id != user.id:
            return None, "Username already exists"
        user.username = account_name
        if payload.full_name is None:
            user.full_name = account_name

    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.password:
        user.password_hash = get_password_hash(payload.password)

    if payload.role_codes is not None:
        roles, roles_error = _resolve_roles(db, payload.role_codes)
        if roles_error:
            return None, roles_error
        user.roles = roles or []

    current_role_codes = [role.code for role in user.roles]
    requested_process_codes = (
        payload.process_codes
        if payload.process_codes is not None
        else [process.code for process in user.processes]
    )
    processes, processes_error = _resolve_processes(db, current_role_codes, requested_process_codes)
    if processes_error:
        return None, processes_error
    user.processes = processes or []

    db.commit()
    db.refresh(user)
    return user, None


def delete_user(db: Session, user: User) -> None:
    db.delete(user)
    db.commit()

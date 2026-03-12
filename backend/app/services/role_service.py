from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.rbac import ROLE_DEFINITIONS
from app.models.associations import user_roles
from app.models.role import Role
from app.schemas.role import RoleCreate, RoleUpdate


BUILTIN_ROLE_CODES = {str(item["code"]) for item in ROLE_DEFINITIONS}


def query_roles(keyword: str | None):
    stmt = select(Role).options(selectinload(Role.users)).order_by(Role.id.asc())
    if keyword:
        like_pattern = f"%{keyword}%"
        stmt = stmt.where(
            Role.code.ilike(like_pattern) | Role.name.ilike(like_pattern)
        )
    return stmt


def get_role_by_id(db: Session, role_id: int) -> Role | None:
    stmt = select(Role).options(selectinload(Role.users)).where(Role.id == role_id)
    return db.execute(stmt).scalars().first()


def get_role_by_code(db: Session, code: str) -> Role | None:
    stmt = select(Role).options(selectinload(Role.users)).where(Role.code == code)
    return db.execute(stmt).scalars().first()


def get_role_by_code_case_insensitive(db: Session, code: str) -> Role | None:
    normalized = code.strip().lower()
    if not normalized:
        return None
    stmt = select(Role).options(selectinload(Role.users)).where(func.lower(Role.code) == normalized)
    return db.execute(stmt).scalars().first()


def get_roles_by_codes(db: Session, codes: list[str]) -> tuple[list[Role], list[str]]:
    unique_codes = sorted({code for code in codes if code})
    if not unique_codes:
        return [], []

    stmt = select(Role).where(Role.code.in_(unique_codes))
    roles = db.execute(stmt).scalars().all()
    existing_codes = {role.code for role in roles}
    missing_codes = [code for code in unique_codes if code not in existing_codes]
    return roles, missing_codes


def list_roles(db: Session, page: int, page_size: int, keyword: str | None) -> tuple[int, list[Role]]:
    base_stmt = query_roles(keyword)
    total_stmt = select(func.count()).select_from(base_stmt.subquery())
    total = db.execute(total_stmt).scalar_one()

    offset = (page - 1) * page_size
    stmt = base_stmt.offset(offset).limit(page_size)
    roles = db.execute(stmt).scalars().all()
    return total, roles


def create_role(db: Session, payload: RoleCreate) -> tuple[Role | None, list[str]]:
    existing = get_role_by_code_case_insensitive(db, payload.code)
    if existing:
        return None, [f"Role code already exists: {payload.code}"]

    role_type = "builtin" if payload.code in BUILTIN_ROLE_CODES else "custom"
    role = Role(
        code=payload.code.strip(),
        name=payload.name.strip(),
        description=payload.description.strip() if payload.description else None,
        role_type=role_type,
        is_builtin=payload.code in BUILTIN_ROLE_CODES,
        is_enabled=True,
    )
    db.add(role)
    db.commit()
    db.refresh(role)
    return role, []


def update_role(db: Session, role: Role, payload: RoleUpdate) -> tuple[Role | None, list[str]]:
    errors: list[str] = []
    role_is_builtin = role.is_builtin or role.code in BUILTIN_ROLE_CODES

    if payload.code is not None:
        next_code = payload.code.strip()
        if not next_code:
            errors.append("Role code is required")
        elif role_is_builtin and next_code != role.code:
            errors.append("Built-in role code cannot be changed")
        elif next_code.lower() != role.code.lower():
            existing = get_role_by_code_case_insensitive(db, next_code)
            if existing and existing.id != role.id:
                errors.append(f"Role code already exists: {next_code}")
            else:
                role.code = next_code

    if payload.name is not None:
        next_name = payload.name.strip()
        if role_is_builtin and next_name != role.name:
            errors.append("Built-in role name cannot be changed")
        else:
            role.name = next_name
    if payload.description is not None:
        role.description = payload.description.strip() if payload.description else None
    if payload.is_enabled is not None:
        role.is_enabled = payload.is_enabled

    if errors:
        db.rollback()
        return None, errors

    db.commit()
    db.refresh(role)
    return role, []


def count_active_users_for_role(db: Session, role_id: int) -> int:
    from app.models.user import User

    stmt = (
        select(func.count(User.id))
        .select_from(User)
        .join(user_roles, user_roles.c.user_id == User.id)
        .where(
            user_roles.c.role_id == role_id,
            User.is_deleted.is_(False),
        )
    )
    return int(db.execute(stmt).scalar_one())


def delete_role(db: Session, role: Role) -> tuple[bool, str | None]:
    role_is_builtin = role.is_builtin or role.code in BUILTIN_ROLE_CODES
    if role_is_builtin:
        return False, "Built-in role cannot be deleted"

    active_users_count = count_active_users_for_role(db, role.id)
    if active_users_count > 0:
        return False, "Role has bound users and cannot be deleted"

    db.delete(role)
    db.commit()
    return True, None

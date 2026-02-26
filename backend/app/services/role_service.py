from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.role import Role
from app.schemas.role import RoleCreate, RoleUpdate


def query_roles(keyword: str | None):
    stmt = select(Role).order_by(Role.id.asc())
    if keyword:
        like_pattern = f"%{keyword}%"
        stmt = stmt.where(Role.code.ilike(like_pattern))
    return stmt


def get_role_by_id(db: Session, role_id: int) -> Role | None:
    stmt = select(Role).where(Role.id == role_id)
    return db.execute(stmt).scalars().first()


def get_role_by_code(db: Session, code: str) -> Role | None:
    stmt = select(Role).where(Role.code == code)
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
    role = Role(
        code=payload.code,
        name=payload.name,
    )
    db.add(role)
    db.commit()
    db.refresh(role)
    return role, []


def update_role(db: Session, role: Role, payload: RoleUpdate) -> tuple[Role | None, list[str]]:
    if payload.name is not None:
        role.name = payload.name

    db.commit()
    db.refresh(role)
    return role, []

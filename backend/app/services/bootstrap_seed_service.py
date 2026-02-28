from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.rbac import DEFAULT_PROCESS_DEFINITIONS, ROLE_DEFINITIONS, ROLE_SYSTEM_ADMIN
from app.core.security import get_password_hash
from app.models.process import Process
from app.models.role import Role
from app.models.user import User


@dataclass(slots=True)
class SeedResult:
    admin_username: str
    admin_created: bool
    role_repaired: bool


def _ensure_roles(db: Session) -> dict[str, Role]:
    roles = db.execute(select(Role)).scalars().all()
    roles_by_code: dict[str, Role] = {role.code: role for role in roles}

    legacy_admin_role = roles_by_code.get("admin")
    system_admin_role = roles_by_code.get(ROLE_SYSTEM_ADMIN)
    if legacy_admin_role and not system_admin_role:
        legacy_admin_role.code = ROLE_SYSTEM_ADMIN
        roles_by_code.pop("admin", None)
        roles_by_code[ROLE_SYSTEM_ADMIN] = legacy_admin_role

    for item in ROLE_DEFINITIONS:
        code = item["code"]
        name = item["name"]
        role = roles_by_code.get(code)
        if not role:
            role = Role(code=code, name=name)
            db.add(role)
            db.flush()
            roles_by_code[code] = role
        else:
            role.name = name

    return roles_by_code


def _ensure_processes(db: Session) -> None:
    for item in DEFAULT_PROCESS_DEFINITIONS:
        code = item["code"]
        name = item["name"]
        process = db.execute(select(Process).where(Process.code == code)).scalars().first()
        if not process:
            process = Process(code=code, name=name)
            db.add(process)
            db.flush()
        else:
            process.name = name


def _ensure_admin_user(
    db: Session,
    roles_by_code: dict[str, Role],
    admin_username: str,
    admin_password: str,
) -> tuple[User, bool, bool]:
    admin_user = db.execute(select(User).where(User.username == admin_username)).scalars().first()
    admin_created = False
    role_repaired = False

    if not admin_user:
        admin_user = User(
            username=admin_username,
            full_name="system admin",
            password_hash=get_password_hash(admin_password),
            is_active=True,
            is_superuser=False,
        )
        db.add(admin_user)
        db.flush()
        admin_created = True
    else:
        admin_user.full_name = "system admin"
        admin_user.password_hash = get_password_hash(admin_password)
        admin_user.is_active = True
        admin_user.is_superuser = False

    expected_role = roles_by_code[ROLE_SYSTEM_ADMIN]
    if len(admin_user.roles) != 1 or admin_user.roles[0].code != ROLE_SYSTEM_ADMIN:
        role_repaired = True
    admin_user.roles = [expected_role]
    admin_user.processes = []

    return admin_user, admin_created, role_repaired


def seed_initial_data(
    db: Session,
    *,
    admin_username: str,
    admin_password: str,
) -> SeedResult:
    roles_by_code = _ensure_roles(db)
    _ensure_processes(db)
    admin_user, admin_created, role_repaired = _ensure_admin_user(
        db,
        roles_by_code,
        admin_username=admin_username,
        admin_password=admin_password,
    )
    db.commit()
    db.refresh(admin_user)
    return SeedResult(
        admin_username=admin_user.username,
        admin_created=admin_created,
        role_repaired=role_repaired,
    )

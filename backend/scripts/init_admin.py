from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.rbac import DEFAULT_PROCESS_DEFINITIONS, ROLE_DEFINITIONS, ROLE_SYSTEM_ADMIN
from app.core.security import get_password_hash
from app.db.session import SessionLocal
from app.models.process import Process
from app.models.role import Role
from app.models.user import User


def _ensure_roles(db: Session) -> dict[str, Role]:
    roles = db.execute(select(Role)).scalars().all()
    roles_by_code: dict[str, Role] = {role.code: role for role in roles}

    legacy_admin_role = roles_by_code.get('admin')
    system_admin_role = roles_by_code.get(ROLE_SYSTEM_ADMIN)
    if legacy_admin_role and not system_admin_role:
        legacy_admin_role.code = ROLE_SYSTEM_ADMIN
        roles_by_code.pop('admin', None)
        roles_by_code[ROLE_SYSTEM_ADMIN] = legacy_admin_role

    for item in ROLE_DEFINITIONS:
        code = item['code']
        name = item['name']
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
        code = item['code']
        name = item['name']
        process = db.execute(select(Process).where(Process.code == code)).scalars().first()
        if not process:
            process = Process(code=code, name=name)
            db.add(process)
            db.flush()
        else:
            process.name = name


def _ensure_admin_user(db: Session, roles_by_code: dict[str, Role]) -> None:
    admin_user = db.execute(select(User).where(User.username == 'admin')).scalars().first()
    if not admin_user:
        admin_user = User(
            username='admin',
            full_name='系统管理员',
            password_hash=get_password_hash('Admin@123456'),
            is_active=True,
            is_superuser=False,
        )
        db.add(admin_user)
        db.flush()
    else:
        admin_user.full_name = '系统管理员'
        admin_user.password_hash = get_password_hash('Admin@123456')
        admin_user.is_active = True
        admin_user.is_superuser = False

    admin_user.roles = [roles_by_code[ROLE_SYSTEM_ADMIN]]
    admin_user.processes = []


def main() -> None:
    db = SessionLocal()
    try:
        roles_by_code = _ensure_roles(db)
        _ensure_processes(db)
        _ensure_admin_user(db, roles_by_code)

        db.commit()
        print('Initialized roles/processes/admin. admin password: Admin@123456')
    finally:
        db.close()


if __name__ == '__main__':
    main()

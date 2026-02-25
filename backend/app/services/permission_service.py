from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.permission import Permission


def list_permissions(db: Session) -> list[Permission]:
    stmt = select(Permission).order_by(Permission.code.asc())
    return db.execute(stmt).scalars().all()


def get_permissions_by_codes(db: Session, codes: list[str]) -> tuple[list[Permission], list[str]]:
    unique_codes = sorted({code for code in codes if code})
    if not unique_codes:
        return [], []

    stmt = select(Permission).where(Permission.code.in_(unique_codes))
    permissions = db.execute(stmt).scalars().all()
    existing_codes = {permission.code for permission in permissions}
    missing_codes = [code for code in unique_codes if code not in existing_codes]
    return permissions, missing_codes


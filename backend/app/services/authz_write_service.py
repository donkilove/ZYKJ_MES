from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.authz_change_log import AuthzChangeLog, AuthzChangeLogItem
from app.models.role_permission_grant import RolePermissionGrant


def _apply_role_permission_changes(
    db: Session,
    *,
    role_code: str,
    changed_codes: list[str],
    after_granted_codes: set[str],
) -> int:
    if not changed_codes:
        return 0
    grant_rows = (
        db.execute(
            select(RolePermissionGrant).where(
                RolePermissionGrant.role_code == role_code,
                RolePermissionGrant.permission_code.in_(changed_codes),
            )
        )
        .scalars()
        .all()
    )
    row_by_permission = {row.permission_code: row for row in grant_rows}
    updated_count = 0
    for permission_code in changed_codes:
        should_grant = permission_code in after_granted_codes
        row = row_by_permission.get(permission_code)
        if row is None:
            db.add(
                RolePermissionGrant(
                    role_code=role_code,
                    permission_code=permission_code,
                    granted=should_grant,
                )
            )
            updated_count += 1
            continue
        if bool(row.granted) != should_grant:
            row.granted = should_grant
            updated_count += 1
    return updated_count


def _serialize_capability_pack_role_result(
    item: dict[str, object],
) -> dict[str, object]:
    return {
        "role_code": str(item["role_code"]),
        "role_name": str(item["role_name"]),
        "readonly": bool(item["readonly"]),
        "ignored_input": bool(item["ignored_input"]),
        "module_code": str(item["module_code"]),
        "before_capability_codes": [
            str(code) for code in item["before_capability_codes"]
        ],
        "after_capability_codes": [
            str(code) for code in item["after_capability_codes"]
        ],
        "added_capability_codes": [
            str(code) for code in item["added_capability_codes"]
        ],
        "removed_capability_codes": [
            str(code) for code in item["removed_capability_codes"]
        ],
        "auto_linked_dependencies": [
            str(code) for code in item["auto_linked_dependencies"]
        ],
        "effective_capability_codes": [
            str(code) for code in item["effective_capability_codes"]
        ],
        "effective_page_permission_codes": [
            str(code) for code in item["effective_page_permission_codes"]
        ],
        "updated_count": int(item["updated_count"]),
    }


def _record_capability_pack_change_log(
    db: Session,
    *,
    module_code: str,
    revision: int,
    operator,
    remark: str | None,
    change_type: str,
    rollback_of_change_log_id: int | None,
    role_results: list[dict[str, object]],
    snapshot: list[dict[str, object]],
) -> AuthzChangeLog:
    log_row = AuthzChangeLog(
        module_code=module_code,
        revision=revision,
        change_type=change_type,
        remark=remark,
        operator_user_id=operator.id if operator is not None else None,
        operator_username=operator.username if operator is not None else None,
        rollback_of_change_log_id=rollback_of_change_log_id,
        snapshot_json=snapshot,
    )
    db.add(log_row)
    db.flush()
    for item in role_results:
        serialized = _serialize_capability_pack_role_result(item)
        db.add(
            AuthzChangeLogItem(
                change_log_id=log_row.id,
                role_code=str(serialized["role_code"]),
                role_name=str(serialized["role_name"]),
                readonly=bool(serialized["readonly"]),
                before_capability_codes=list(serialized["before_capability_codes"]),
                after_capability_codes=list(serialized["after_capability_codes"]),
                added_capability_codes=list(serialized["added_capability_codes"]),
                removed_capability_codes=list(serialized["removed_capability_codes"]),
                auto_linked_dependencies=list(serialized["auto_linked_dependencies"]),
                effective_capability_codes=list(
                    serialized["effective_capability_codes"]
                ),
                effective_page_permission_codes=list(
                    serialized["effective_page_permission_codes"]
                ),
                updated_count=int(serialized["updated_count"]),
            )
        )
    db.flush()
    return log_row

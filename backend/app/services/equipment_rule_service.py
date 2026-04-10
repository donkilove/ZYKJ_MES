from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session
from typing import Any, cast

from app.models.equipment import Equipment
from app.models.equipment_rule import EquipmentRule
from app.models.equipment_runtime_parameter import EquipmentRuntimeParameter
from app.schemas.equipment_rule import (
    EquipmentRuleItem,
    EquipmentRuleListResult,
    EquipmentRuleUpsertRequest,
    EquipmentRuntimeParameterItem,
    EquipmentRuntimeParameterListResult,
    EquipmentRuntimeParameterUpsertRequest,
)


_EQUIPMENT_RULE_LIST_COLUMNS = (
    EquipmentRule.id,
    EquipmentRule.equipment_id,
    EquipmentRule.equipment_type,
    EquipmentRule.equipment_code,
    EquipmentRule.equipment_name,
    EquipmentRule.rule_code,
    EquipmentRule.rule_name,
    EquipmentRule.rule_type,
    EquipmentRule.condition_desc,
    EquipmentRule.is_enabled,
    EquipmentRule.effective_at,
    EquipmentRule.remark,
    EquipmentRule.created_at,
    EquipmentRule.updated_at,
)
_EQUIPMENT_RUNTIME_PARAMETER_LIST_COLUMNS = (
    EquipmentRuntimeParameter.id,
    EquipmentRuntimeParameter.equipment_id,
    EquipmentRuntimeParameter.equipment_type,
    EquipmentRuntimeParameter.equipment_code,
    EquipmentRuntimeParameter.equipment_name,
    EquipmentRuntimeParameter.param_code,
    EquipmentRuntimeParameter.param_name,
    EquipmentRuntimeParameter.unit,
    EquipmentRuntimeParameter.standard_value,
    EquipmentRuntimeParameter.upper_limit,
    EquipmentRuntimeParameter.lower_limit,
    EquipmentRuntimeParameter.effective_at,
    EquipmentRuntimeParameter.is_enabled,
    EquipmentRuntimeParameter.remark,
    EquipmentRuntimeParameter.created_at,
    EquipmentRuntimeParameter.updated_at,
)


def _to_rule_item(row: Any) -> EquipmentRuleItem:
    return EquipmentRuleItem(
        id=row.id if hasattr(row, "id") else row["id"],
        equipment_id=row.equipment_id if hasattr(row, "equipment_id") else row["equipment_id"],
        equipment_type=row.equipment_type if hasattr(row, "equipment_type") else row["equipment_type"],
        equipment_code=row.equipment_code if hasattr(row, "equipment_code") else row["equipment_code"],
        equipment_name=row.equipment_name if hasattr(row, "equipment_name") else row["equipment_name"],
        rule_code=row.rule_code if hasattr(row, "rule_code") else row["rule_code"],
        rule_name=row.rule_name if hasattr(row, "rule_name") else row["rule_name"],
        rule_type=row.rule_type if hasattr(row, "rule_type") else row["rule_type"],
        condition_desc=row.condition_desc if hasattr(row, "condition_desc") else row["condition_desc"],
        is_enabled=row.is_enabled if hasattr(row, "is_enabled") else row["is_enabled"],
        effective_at=row.effective_at if hasattr(row, "effective_at") else row["effective_at"],  # type: ignore
        remark=row.remark if hasattr(row, "remark") else row["remark"],
        created_at=row.created_at if hasattr(row, "created_at") else row["created_at"],
        updated_at=row.updated_at if hasattr(row, "updated_at") else row["updated_at"],
    )


def _to_param_item(row: Any) -> EquipmentRuntimeParameterItem:
    return EquipmentRuntimeParameterItem(
        id=row.id if hasattr(row, "id") else row["id"],
        equipment_id=row.equipment_id if hasattr(row, "equipment_id") else row["equipment_id"],
        equipment_type=row.equipment_type if hasattr(row, "equipment_type") else row["equipment_type"],
        equipment_code=row.equipment_code if hasattr(row, "equipment_code") else row["equipment_code"],
        equipment_name=row.equipment_name if hasattr(row, "equipment_name") else row["equipment_name"],
        param_code=row.param_code if hasattr(row, "param_code") else row["param_code"],
        param_name=row.param_name if hasattr(row, "param_name") else row["param_name"],
        unit=row.unit if hasattr(row, "unit") else row["unit"],
        standard_value=row.standard_value if hasattr(row, "standard_value") else row["standard_value"],  # type: ignore
        upper_limit=row.upper_limit if hasattr(row, "upper_limit") else row["upper_limit"],  # type: ignore
        lower_limit=row.lower_limit if hasattr(row, "lower_limit") else row["lower_limit"],  # type: ignore
        effective_at=row.effective_at if hasattr(row, "effective_at") else row["effective_at"],  # type: ignore
        is_enabled=row.is_enabled if hasattr(row, "is_enabled") else row["is_enabled"],
        remark=row.remark if hasattr(row, "remark") else row["remark"],
        created_at=row.created_at if hasattr(row, "created_at") else row["created_at"],
        updated_at=row.updated_at if hasattr(row, "updated_at") else row["updated_at"],
    )


def _resolve_equipment_fields(
    db: Session, equipment_id: int | None
) -> tuple[str | None, str | None]:
    if equipment_id is None:
        return None, None
    eq = db.get(Equipment, equipment_id)
    if eq is None:
        raise ValueError("Equipment not found")
    return (
        str(eq.code) if eq.code is not None else None,
        str(eq.name) if eq.name is not None else None,
    )


def _normalize_required_text(value: str, *, field_name: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{field_name} is required")
    return normalized


def _validate_parameter_limits(
    *,
    standard_value,
    upper_limit,
    lower_limit,
) -> None:
    _ = standard_value
    if (
        upper_limit is not None
        and lower_limit is not None
        and lower_limit > upper_limit
    ):
        raise ValueError("lower_limit cannot be greater than upper_limit")


def _normalize_equipment_scope(
    db: Session,
    *,
    equipment_id: int | None,
    equipment_type: str | None,
) -> tuple[int | None, str | None, str | None, str | None]:
    normalized_type = (equipment_type or "").strip() or None
    if equipment_id is None and normalized_type is None:
        raise ValueError("Equipment scope is required")
    code, name = _resolve_equipment_fields(db, equipment_id)
    return equipment_id, normalized_type, code, name


# ── 设备规则 ──────────────────────────────────────────────────────────────────


def list_equipment_rules(
    db: Session,
    *,
    equipment_id: int | None = None,
    keyword: str | None = None,
    is_enabled: bool | None = None,
    page: int = 1,
    page_size: int = 20,
) -> EquipmentRuleListResult:
    filters = []
    if equipment_id is not None:
        filters.append(EquipmentRule.equipment_id == equipment_id)
    if is_enabled is not None:
        filters.append(EquipmentRule.is_enabled == is_enabled)
    if keyword:
        like = f"%{keyword.strip()}%"
        filters.append(cast(Any, EquipmentRule.rule_name).ilike(like))
    stmt = select(*_EQUIPMENT_RULE_LIST_COLUMNS).where(*filters)
    total = db.scalar(select(func.count(EquipmentRule.id)).where(*filters)) or 0
    rows = (
        db.execute(
            stmt.order_by(EquipmentRule.id.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        .mappings()
        .all()
    )
    return EquipmentRuleListResult(
        total=total,
        items=[_to_rule_item(row) for row in rows],
    )


def create_equipment_rule(
    db: Session, *, payload: EquipmentRuleUpsertRequest
) -> EquipmentRule:
    equipment_id, equipment_type, code, name = _normalize_equipment_scope(
        db,
        equipment_id=payload.equipment_id,
        equipment_type=payload.equipment_type,
    )
    existing_rule = (
        db.execute(
            select(EquipmentRule).where(
                EquipmentRule.rule_code == payload.rule_code.strip()
            )
        )
        .scalars()
        .first()
    )
    if existing_rule is not None:
        raise ValueError("Equipment rule code already exists")
    row = EquipmentRule(
        equipment_id=equipment_id,
        equipment_type=equipment_type,
        equipment_code=code,
        equipment_name=name,
        rule_code=_normalize_required_text(payload.rule_code, field_name="Rule code"),
        rule_name=_normalize_required_text(payload.rule_name, field_name="Rule name"),
        rule_type=payload.rule_type.strip(),
        condition_desc=payload.condition_desc.strip(),
        is_enabled=payload.is_enabled,
        effective_at=payload.effective_at,
        remark=payload.remark.strip(),
    )
    db.add(row)
    db.flush()
    return row


def update_equipment_rule(
    db: Session, *, row: EquipmentRule, payload: EquipmentRuleUpsertRequest
) -> EquipmentRule:
    equipment_id, equipment_type, code, name = _normalize_equipment_scope(
        db,
        equipment_id=payload.equipment_id,
        equipment_type=payload.equipment_type,
    )
    existing_rule = (
        db.execute(
            select(EquipmentRule).where(
                EquipmentRule.rule_code == payload.rule_code.strip(),
                EquipmentRule.id != row.id,
            )
        )
        .scalars()
        .first()
    )
    if existing_rule is not None:
        raise ValueError("Equipment rule code already exists")
    row.equipment_id = equipment_id
    row.equipment_type = equipment_type
    row.equipment_code = code
    row.equipment_name = name
    row.rule_code = _normalize_required_text(payload.rule_code, field_name="Rule code")
    row.rule_name = _normalize_required_text(payload.rule_name, field_name="Rule name")
    row.rule_type = payload.rule_type.strip()
    row.condition_desc = payload.condition_desc.strip()
    row.is_enabled = payload.is_enabled
    row.effective_at = payload.effective_at
    row.remark = payload.remark.strip()
    db.flush()
    return row


def toggle_equipment_rule(
    db: Session, *, row: EquipmentRule, enabled: bool
) -> EquipmentRule:
    row.is_enabled = enabled
    db.flush()
    return row


def delete_equipment_rule(db: Session, *, row: EquipmentRule) -> None:
    db.delete(row)
    db.flush()


# ── 运行参数 ──────────────────────────────────────────────────────────────────


def list_runtime_parameters(
    db: Session,
    *,
    equipment_id: int | None = None,
    equipment_type: str | None = None,
    keyword: str | None = None,
    is_enabled: bool | None = None,
    page: int = 1,
    page_size: int = 20,
) -> EquipmentRuntimeParameterListResult:
    filters = []
    if equipment_id is not None:
        filters.append(EquipmentRuntimeParameter.equipment_id == equipment_id)
    if equipment_type and equipment_type.strip():
        filters.append(
            EquipmentRuntimeParameter.equipment_type == equipment_type.strip()
        )
    if is_enabled is not None:
        filters.append(EquipmentRuntimeParameter.is_enabled == is_enabled)
    if keyword:
        like = f"%{keyword.strip()}%"
        filters.append(
            cast(Any, EquipmentRuntimeParameter.param_name).ilike(like)
            | cast(Any, EquipmentRuntimeParameter.param_code).ilike(like)
        )
    stmt = select(*_EQUIPMENT_RUNTIME_PARAMETER_LIST_COLUMNS).where(*filters)
    total = (
        db.scalar(select(func.count(EquipmentRuntimeParameter.id)).where(*filters)) or 0
    )
    rows = (
        db.execute(
            stmt.order_by(EquipmentRuntimeParameter.id.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        .mappings()
        .all()
    )
    return EquipmentRuntimeParameterListResult(
        total=total,
        items=[_to_param_item(row) for row in rows],
    )


def create_runtime_parameter(
    db: Session, *, payload: EquipmentRuntimeParameterUpsertRequest
) -> EquipmentRuntimeParameter:
    equipment_id, equipment_type, code, name = _normalize_equipment_scope(
        db,
        equipment_id=payload.equipment_id,
        equipment_type=payload.equipment_type,
    )
    _validate_parameter_limits(
        standard_value=payload.standard_value,
        upper_limit=payload.upper_limit,
        lower_limit=payload.lower_limit,
    )
    row = EquipmentRuntimeParameter(
        equipment_id=equipment_id,
        equipment_type=equipment_type,
        equipment_code=code,
        equipment_name=name,
        param_code=_normalize_required_text(
            payload.param_code, field_name="Parameter code"
        ),
        param_name=_normalize_required_text(
            payload.param_name, field_name="Parameter name"
        ),
        unit=payload.unit.strip(),
        standard_value=payload.standard_value,
        upper_limit=payload.upper_limit,
        lower_limit=payload.lower_limit,
        effective_at=payload.effective_at,
        is_enabled=payload.is_enabled,
        remark=payload.remark.strip(),
    )
    db.add(row)
    db.flush()
    return row


def update_runtime_parameter(
    db: Session,
    *,
    row: EquipmentRuntimeParameter,
    payload: EquipmentRuntimeParameterUpsertRequest,
) -> EquipmentRuntimeParameter:
    equipment_id, equipment_type, code, name = _normalize_equipment_scope(
        db,
        equipment_id=payload.equipment_id,
        equipment_type=payload.equipment_type,
    )
    _validate_parameter_limits(
        standard_value=payload.standard_value,
        upper_limit=payload.upper_limit,
        lower_limit=payload.lower_limit,
    )
    row.equipment_id = equipment_id
    row.equipment_type = equipment_type
    row.equipment_code = code
    row.equipment_name = name
    row.param_code = _normalize_required_text(
        payload.param_code, field_name="Parameter code"
    )
    row.param_name = _normalize_required_text(
        payload.param_name, field_name="Parameter name"
    )
    row.unit = payload.unit.strip()
    row.standard_value = payload.standard_value
    row.upper_limit = payload.upper_limit
    row.lower_limit = payload.lower_limit
    row.effective_at = payload.effective_at
    row.is_enabled = payload.is_enabled
    row.remark = payload.remark.strip()
    db.flush()
    return row


def delete_runtime_parameter(db: Session, *, row: EquipmentRuntimeParameter) -> None:
    db.delete(row)
    db.flush()


def toggle_runtime_parameter(
    db: Session,
    *,
    row: EquipmentRuntimeParameter,
    enabled: bool,
) -> EquipmentRuntimeParameter:
    row.is_enabled = enabled
    db.flush()
    return row

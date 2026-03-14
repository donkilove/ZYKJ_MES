from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session

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


def _to_rule_item(row: EquipmentRule) -> EquipmentRuleItem:
    return EquipmentRuleItem(
        id=row.id,
        equipment_id=row.equipment_id,
        equipment_code=row.equipment_code,
        equipment_name=row.equipment_name,
        rule_name=row.rule_name,
        rule_type=row.rule_type,
        condition_desc=row.condition_desc,
        is_enabled=row.is_enabled,
        effective_at=row.effective_at,
        remark=row.remark,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_param_item(row: EquipmentRuntimeParameter) -> EquipmentRuntimeParameterItem:
    return EquipmentRuntimeParameterItem(
        id=row.id,
        equipment_id=row.equipment_id,
        equipment_code=row.equipment_code,
        equipment_name=row.equipment_name,
        param_code=row.param_code,
        param_name=row.param_name,
        unit=row.unit,
        standard_value=row.standard_value,
        upper_limit=row.upper_limit,
        lower_limit=row.lower_limit,
        effective_at=row.effective_at,
        remark=row.remark,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _resolve_equipment_fields(
    db: Session, equipment_id: int | None
) -> tuple[str | None, str | None]:
    if equipment_id is None:
        return None, None
    eq = db.get(Equipment, equipment_id)
    if eq is None:
        return None, None
    return eq.code, eq.name


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
    stmt = select(EquipmentRule)
    if equipment_id is not None:
        stmt = stmt.where(EquipmentRule.equipment_id == equipment_id)
    if is_enabled is not None:
        stmt = stmt.where(EquipmentRule.is_enabled == is_enabled)
    if keyword:
        like = f"%{keyword.strip()}%"
        stmt = stmt.where(EquipmentRule.rule_name.ilike(like))
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.execute(
        stmt.order_by(EquipmentRule.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).scalars().all()
    return EquipmentRuleListResult(total=total, items=[_to_rule_item(r) for r in rows])


def create_equipment_rule(
    db: Session, *, payload: EquipmentRuleUpsertRequest
) -> EquipmentRule:
    code, name = _resolve_equipment_fields(db, payload.equipment_id)
    row = EquipmentRule(
        equipment_id=payload.equipment_id,
        equipment_code=code,
        equipment_name=name,
        rule_name=payload.rule_name.strip(),
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
    code, name = _resolve_equipment_fields(db, payload.equipment_id)
    row.equipment_id = payload.equipment_id
    row.equipment_code = code
    row.equipment_name = name
    row.rule_name = payload.rule_name.strip()
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
    keyword: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> EquipmentRuntimeParameterListResult:
    stmt = select(EquipmentRuntimeParameter)
    if equipment_id is not None:
        stmt = stmt.where(EquipmentRuntimeParameter.equipment_id == equipment_id)
    if keyword:
        like = f"%{keyword.strip()}%"
        stmt = stmt.where(
            EquipmentRuntimeParameter.param_name.ilike(like)
            | EquipmentRuntimeParameter.param_code.ilike(like)
        )
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.execute(
        stmt.order_by(EquipmentRuntimeParameter.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).scalars().all()
    return EquipmentRuntimeParameterListResult(
        total=total, items=[_to_param_item(r) for r in rows]
    )


def create_runtime_parameter(
    db: Session, *, payload: EquipmentRuntimeParameterUpsertRequest
) -> EquipmentRuntimeParameter:
    code, name = _resolve_equipment_fields(db, payload.equipment_id)
    row = EquipmentRuntimeParameter(
        equipment_id=payload.equipment_id,
        equipment_code=code,
        equipment_name=name,
        param_code=payload.param_code.strip(),
        param_name=payload.param_name.strip(),
        unit=payload.unit.strip(),
        standard_value=payload.standard_value,
        upper_limit=payload.upper_limit,
        lower_limit=payload.lower_limit,
        effective_at=payload.effective_at,
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
    code, name = _resolve_equipment_fields(db, payload.equipment_id)
    row.equipment_id = payload.equipment_id
    row.equipment_code = code
    row.equipment_name = name
    row.param_code = payload.param_code.strip()
    row.param_name = payload.param_name.strip()
    row.unit = payload.unit.strip()
    row.standard_value = payload.standard_value
    row.upper_limit = payload.upper_limit
    row.lower_limit = payload.lower_limit
    row.effective_at = payload.effective_at
    row.remark = payload.remark.strip()
    db.flush()
    return row


def delete_runtime_parameter(
    db: Session, *, row: EquipmentRuntimeParameter
) -> None:
    db.delete(row)
    db.flush()

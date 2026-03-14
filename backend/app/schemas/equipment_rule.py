from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class EquipmentRuleUpsertRequest(BaseModel):
    equipment_id: int | None = None
    rule_name: str
    rule_type: str = ""
    condition_desc: str = ""
    is_enabled: bool = True
    effective_at: datetime | None = None
    remark: str = ""


class EquipmentRuleItem(BaseModel):
    id: int
    equipment_id: int | None
    equipment_code: str | None
    equipment_name: str | None
    rule_name: str
    rule_type: str
    condition_desc: str
    is_enabled: bool
    effective_at: datetime | None
    remark: str
    created_at: datetime
    updated_at: datetime


class EquipmentRuleListResult(BaseModel):
    total: int
    items: list[EquipmentRuleItem]


class EquipmentRuntimeParameterUpsertRequest(BaseModel):
    equipment_id: int | None = None
    param_code: str
    param_name: str
    unit: str = ""
    standard_value: Decimal | None = None
    upper_limit: Decimal | None = None
    lower_limit: Decimal | None = None
    effective_at: datetime | None = None
    remark: str = ""


class EquipmentRuntimeParameterItem(BaseModel):
    id: int
    equipment_id: int | None
    equipment_code: str | None
    equipment_name: str | None
    param_code: str
    param_name: str
    unit: str
    standard_value: Decimal | None
    upper_limit: Decimal | None
    lower_limit: Decimal | None
    effective_at: datetime | None
    remark: str
    created_at: datetime
    updated_at: datetime


class EquipmentRuntimeParameterListResult(BaseModel):
    total: int
    items: list[EquipmentRuntimeParameterItem]

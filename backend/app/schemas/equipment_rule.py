from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, model_validator


class EquipmentRuleUpsertRequest(BaseModel):
    equipment_id: int | None = None
    equipment_type: str | None = Field(default=None, max_length=64)
    rule_code: str = Field(min_length=1, max_length=64)
    rule_name: str = Field(min_length=1, max_length=128)
    rule_type: str = Field(default="", max_length=64)
    condition_desc: str = Field(default="", max_length=2000)
    is_enabled: bool = True
    effective_at: datetime | None = None
    remark: str = Field(default="", max_length=2000)


class EquipmentRuleItem(BaseModel):
    id: int
    equipment_id: int | None
    equipment_type: str | None
    equipment_code: str | None
    equipment_name: str | None
    rule_code: str
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
    equipment_type: str | None = Field(default=None, max_length=64)
    param_code: str = Field(min_length=1, max_length=64)
    param_name: str = Field(min_length=1, max_length=128)
    unit: str = Field(default="", max_length=32)
    standard_value: Decimal | None = None
    upper_limit: Decimal | None = None
    lower_limit: Decimal | None = None
    effective_at: datetime | None = None
    is_enabled: bool = True
    remark: str = Field(default="", max_length=2000)

    @model_validator(mode="after")
    def validate_limits(self) -> "EquipmentRuntimeParameterUpsertRequest":
        if (
            self.upper_limit is not None
            and self.lower_limit is not None
            and self.lower_limit > self.upper_limit
        ):
            raise ValueError("lower_limit cannot be greater than upper_limit")
        return self


class EquipmentRuntimeParameterItem(BaseModel):
    id: int
    equipment_id: int | None
    equipment_type: str | None
    equipment_code: str | None
    equipment_name: str | None
    param_code: str
    param_name: str
    unit: str
    standard_value: Decimal | None
    upper_limit: Decimal | None
    lower_limit: Decimal | None
    effective_at: datetime | None
    is_enabled: bool
    remark: str
    created_at: datetime
    updated_at: datetime


class EquipmentRuntimeParameterListResult(BaseModel):
    total: int
    items: list[EquipmentRuntimeParameterItem]

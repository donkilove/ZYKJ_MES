from __future__ import annotations

from dataclasses import dataclass


PROCESS_CODE_LASER_MARKING = "laser_marking"
PROCESS_CODE_PRODUCT_TESTING = "product_testing"
PROCESS_CODE_PRODUCT_ASSEMBLY = "product_assembly"
PROCESS_CODE_PRODUCT_PACKAGING = "product_packaging"

PROCESS_NAME_LASER_MARKING = "激光打标"
PROCESS_NAME_PRODUCT_TESTING = "产品测试"
PROCESS_NAME_PRODUCT_ASSEMBLY = "产品组装"
PROCESS_NAME_PRODUCT_PACKAGING = "产品包装"


@dataclass(frozen=True)
class EquipmentProcessOption:
    code: str
    name: str


EQUIPMENT_PROCESS_OPTIONS = [
    EquipmentProcessOption(
        code=PROCESS_CODE_LASER_MARKING,
        name=PROCESS_NAME_LASER_MARKING,
    ),
    EquipmentProcessOption(
        code=PROCESS_CODE_PRODUCT_TESTING,
        name=PROCESS_NAME_PRODUCT_TESTING,
    ),
    EquipmentProcessOption(
        code=PROCESS_CODE_PRODUCT_ASSEMBLY,
        name=PROCESS_NAME_PRODUCT_ASSEMBLY,
    ),
    EquipmentProcessOption(
        code=PROCESS_CODE_PRODUCT_PACKAGING,
        name=PROCESS_NAME_PRODUCT_PACKAGING,
    ),
]

EQUIPMENT_PROCESS_CODE_TO_NAME = {item.code: item.name for item in EQUIPMENT_PROCESS_OPTIONS}
EQUIPMENT_PROCESS_NAME_TO_CODE = {item.name: item.code for item in EQUIPMENT_PROCESS_OPTIONS}
EQUIPMENT_PROCESS_CODES = set(EQUIPMENT_PROCESS_CODE_TO_NAME.keys())


def is_valid_equipment_process_code(code: str) -> bool:
    return code in EQUIPMENT_PROCESS_CODES


def get_equipment_process_name(code: str) -> str:
    return EQUIPMENT_PROCESS_CODE_TO_NAME.get(code, code)


def map_location_to_process_code(location: str | None) -> str:
    normalized = (location or "").strip()
    return EQUIPMENT_PROCESS_NAME_TO_CODE.get(normalized, PROCESS_CODE_LASER_MARKING)

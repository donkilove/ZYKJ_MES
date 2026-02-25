ROLE_SYSTEM_ADMIN = "system_admin"
ROLE_PRODUCTION_ADMIN = "production_admin"
ROLE_QUALITY_ADMIN = "quality_admin"
ROLE_OPERATOR = "operator"

ROLE_DEFINITIONS = [
    {"code": ROLE_SYSTEM_ADMIN, "name": "系统管理员角色"},
    {"code": ROLE_PRODUCTION_ADMIN, "name": "生产管理员角色"},
    {"code": ROLE_QUALITY_ADMIN, "name": "品质管理员角色"},
    {"code": ROLE_OPERATOR, "name": "操作员角色"},
]

VALID_ROLE_CODES = {item["code"] for item in ROLE_DEFINITIONS}

DEFAULT_PROCESS_DEFINITIONS = [
    {"code": "laser_marking", "name": "激光打标"},
    {"code": "product_testing", "name": "产品测试"},
    {"code": "product_assembly", "name": "产品组装"},
    {"code": "product_packaging", "name": "产品包装"},
]


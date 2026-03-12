ROLE_SYSTEM_ADMIN = "system_admin"
ROLE_PRODUCTION_ADMIN = "production_admin"
ROLE_QUALITY_ADMIN = "quality_admin"
ROLE_OPERATOR = "operator"
ROLE_MAINTENANCE_STAFF = "maintenance_staff"

ROLE_DEFINITIONS = [
    {"code": ROLE_SYSTEM_ADMIN, "name": "系统管理员"},
    {"code": ROLE_PRODUCTION_ADMIN, "name": "生产管理员"},
    {"code": ROLE_QUALITY_ADMIN, "name": "品质管理员"},
    {"code": ROLE_OPERATOR, "name": "操作员"},
    {"code": ROLE_MAINTENANCE_STAFF, "name": "维修员"},
]

VALID_ROLE_CODES = {item["code"] for item in ROLE_DEFINITIONS}

DEFAULT_PROCESS_DEFINITIONS = [
    {
        "stage_code": "laser_marking",
        "stage_name": "激光打标",
        "code": "laser_marking_fiber",
        "name": "光纤打标",
    },
    {
        "stage_code": "laser_marking",
        "stage_name": "激光打标",
        "code": "laser_marking_uv",
        "name": "紫光打标",
    },
    {
        "stage_code": "laser_marking",
        "stage_name": "激光打标",
        "code": "laser_marking_auto_fiber",
        "name": "自动光纤打标",
    },
    {
        "stage_code": "product_testing",
        "stage_name": "产品测试",
        "code": "product_testing_general",
        "name": "通用测试",
    },
    {
        "stage_code": "product_assembly",
        "stage_name": "产品组装",
        "code": "product_assembly_general",
        "name": "通用组装",
    },
    {
        "stage_code": "product_packaging",
        "stage_name": "产品包装",
        "code": "product_packaging_general",
        "name": "通用包装",
    },
]

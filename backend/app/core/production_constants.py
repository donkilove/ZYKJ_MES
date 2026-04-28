ORDER_STATUS_PENDING = "pending"
ORDER_STATUS_IN_PROGRESS = "in_progress"
ORDER_STATUS_COMPLETED = "completed"

PROCESS_STATUS_PENDING = "pending"
PROCESS_STATUS_IN_PROGRESS = "in_progress"
PROCESS_STATUS_PARTIAL = "partial"
PROCESS_STATUS_COMPLETED = "completed"

SUB_ORDER_STATUS_PENDING = "pending"
SUB_ORDER_STATUS_IN_PROGRESS = "in_progress"

RECORD_TYPE_FIRST_ARTICLE = "first_article"
RECORD_TYPE_PRODUCTION = "production"

REPAIR_STATUS_IN_REPAIR = "in_repair"
REPAIR_STATUS_COMPLETED = "completed"
REPAIR_STATUS_ALL = {
    REPAIR_STATUS_IN_REPAIR,
    REPAIR_STATUS_COMPLETED,
}

SCRAP_PROGRESS_PENDING_APPLY = "pending_apply"
SCRAP_PROGRESS_APPLIED = "applied"
SCRAP_PROGRESS_ALL = {
    SCRAP_PROGRESS_PENDING_APPLY,
    SCRAP_PROGRESS_APPLIED,
}

ORDER_STATUS_ALL = {
    ORDER_STATUS_PENDING,
    ORDER_STATUS_IN_PROGRESS,
    ORDER_STATUS_COMPLETED,
}
PROCESS_STATUS_ALL = {
    PROCESS_STATUS_PENDING,
    PROCESS_STATUS_IN_PROGRESS,
    PROCESS_STATUS_PARTIAL,
    PROCESS_STATUS_COMPLETED,
}
SUB_ORDER_STATUS_ALL = {
    SUB_ORDER_STATUS_PENDING,
    SUB_ORDER_STATUS_IN_PROGRESS,
}


def order_status_label(status: str) -> str:
    return {
        ORDER_STATUS_PENDING: "待生产",
        ORDER_STATUS_IN_PROGRESS: "生产中",
        ORDER_STATUS_COMPLETED: "生产完成",
    }.get(status, status)


def process_status_label(status: str) -> str:
    return {
        PROCESS_STATUS_PENDING: "待生产",
        PROCESS_STATUS_IN_PROGRESS: "进行中",
        PROCESS_STATUS_PARTIAL: "部分完成",
        PROCESS_STATUS_COMPLETED: "生产完成",
    }.get(status, status)


def sub_order_status_label(status: str) -> str:
    return {
        SUB_ORDER_STATUS_PENDING: "待执行",
        SUB_ORDER_STATUS_IN_PROGRESS: "执行中",
    }.get(status, status)


def pipeline_mode_label(enabled: bool) -> str:
    return "开启" if enabled else "关闭"

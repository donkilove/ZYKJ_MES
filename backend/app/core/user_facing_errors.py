from __future__ import annotations

import re
from collections.abc import Iterable


_FIELD_LABELS = {
    "account": "账号",
    "cause_items": "原因明细",
    "current user": "当前用户",
    "current session": "当前会话",
    "default executor user": "默认执行人",
    "equipment": "设备",
    "equipment code": "设备编码",
    "equipment rule code": "设备规则编码",
    "equipment scope": "设备范围",
    "execution process": "执行工序",
    "first article template": "首件模板",
    "helper user": "代班人",
    "inactive_reason": "停用原因",
    "maintenance item": "保养项目",
    "maintenance item name": "保养项目名称",
    "maintenance plan": "保养计划",
    "module_code": "模块编码",
    "online session": "在线会话",
    "order": "工单",
    "order code": "工单编号",
    "order process": "工单工序",
    "parameter": "参数",
    "participant users": "参与人员",
    "permission_codes": "权限编码",
    "phenomenon": "不良现象",
    "process": "工序",
    "process code": "工序编码",
    "process name": "工序名称",
    "product": "产品",
    "product name": "产品名称",
    "product version": "产品版本",
    "reason": "原因",
    "registration request": "注册申请",
    "repair order": "返修工单",
    "review session": "复核会话",
    "role": "角色",
    "role code": "角色编码",
    "role_code": "角色编码",
    "stage": "工段",
    "stage code": "工段编码",
    "stage name": "工段名称",
    "target operator": "目标操作员",
    "template": "模板",
    "template name": "模板名称",
    "template version": "模板版本",
    "target version": "目标版本",
    "user": "用户",
    "username": "账号",
    "version": "版本",
}

_FULL_TEXT_REPLACEMENTS = {
    "Access denied": "无权限访问",
    "Account is disabled": "账号已停用",
    "Account is pending approval": "账号正在审批中",
    "Deleted user cannot be enabled": "已删除用户不能启用",
    "Active assist authorization already exists": "已存在生效中的代班授权",
    "Current stage operator does not require assist authorization": "本工段操作员无需发起代班",
    "Current process pipeline instance already exists for requested sequence": "请求的工序序号已存在对应的流水线实例",
    "Current session not found": "当前会话不存在",
    "Excel export not available (openpyxl not installed)": "Excel 导出不可用：未安装 openpyxl",
    "Field required": "字段不能为空",
    "Incorrect username or password": "账号或密码错误",
    "Invalid authentication credentials": "登录态无效或已过期",
    "Maintenance plan already exists for this equipment and item": "该设备与保养项目的保养计划已存在",
    "Not Found": "请求的资源不存在",
    "Online session not found": "在线会话不存在",
    "Process name already exists in this stage": "当前工段下工序名称已存在",
    "Registration request not found": "注册申请不存在",
    "Registration request is pending approval": "注册申请正在审批中",
    "Registration request was rejected": "注册申请已驳回",
    "System master template already exists": "系统主模板已存在",
    "System master template not found": "系统主模板不存在",
    "Target operator not found or inactive": "目标操作员不存在或已停用",
    "Template name already exists under selected product": "所选产品下模板名称已存在",
    "Template name already exists under target product": "目标产品下模板名称已存在",
    "Template name already exists under this product": "当前产品下模板名称已存在",
    "User not found": "用户不存在",
}


def _label_to_cn(label: str) -> str:
    normalized = label.strip()
    normalized_key = normalized.lower()
    return _FIELD_LABELS.get(normalized_key, normalized)


def localize_user_facing_message(message: str) -> str:
    normalized = (message or "").strip()
    if not normalized:
        return normalized

    if normalized in _FULL_TEXT_REPLACEMENTS:
        return _FULL_TEXT_REPLACEMENTS[normalized]

    rejected_match = re.fullmatch(
        r"Registration request was rejected:\s*(.+)", normalized
    )
    if rejected_match:
        return f"注册申请已驳回：{rejected_match.group(1).strip()}"

    role_exists_match = re.fullmatch(r"Role code already exists:\s*(.+)", normalized)
    if role_exists_match:
        return f"角色编码已存在：{role_exists_match.group(1).strip()}"

    not_found_with_value_match = re.fullmatch(r"(.+?) not found:\s*(.+)", normalized)
    if not_found_with_value_match:
        label = _label_to_cn(not_found_with_value_match.group(1))
        return f"{label}不存在：{not_found_with_value_match.group(2).strip()}"

    not_found_match = re.fullmatch(r"(.+?) not found", normalized)
    if not_found_match:
        label = _label_to_cn(not_found_match.group(1))
        return f"{label}不存在"

    not_found_or_inactive_match = re.fullmatch(
        r"(.+?) not found or inactive", normalized
    )
    if not_found_or_inactive_match:
        label = _label_to_cn(not_found_or_inactive_match.group(1))
        return f"{label}不存在或已停用"

    already_exists_match = re.fullmatch(r"(.+?) already exists", normalized)
    if already_exists_match:
        label = _label_to_cn(already_exists_match.group(1))
        return f"{label}已存在"

    required_match = re.fullmatch(r"(.+?) is required", normalized)
    if required_match:
        label = _label_to_cn(required_match.group(1))
        return f"{label}不能为空"

    disabled_match = re.fullmatch(r"(.+?) is disabled", normalized)
    if disabled_match:
        label = _label_to_cn(disabled_match.group(1))
        return f"{label}已停用"

    version_not_found_match = re.fullmatch(r"Version not found:\s*(.+)", normalized)
    if version_not_found_match:
        return f"版本不存在：{version_not_found_match.group(1).strip()}"

    target_version_not_found_match = re.fullmatch(
        r"Target version not found", normalized
    )
    if target_version_not_found_match:
        return "目标版本不存在"

    impact_confirmation_match = re.fullmatch(
        r"Impact confirmation required before (.+)", normalized
    )
    if impact_confirmation_match:
        action = impact_confirmation_match.group(1).strip()
        action_map = {
            "activation": "生效",
            "rollback": "回滚",
            "changing lifecycle": "变更生命周期",
            "applying order sync": "应用工单同步",
        }
        action_cn = action_map.get(action, action)
        return f"{action_cn}前需要先确认影响范围"

    exact_replacements = (
        ("Assist authorization is required for cross-user operation", "跨用户操作时必须提供代班授权"),
        ("At least one process step is required", "至少需要一道工序步骤"),
        ("At least one process is required", "至少需要选择一道工序"),
        (
            "At least two valid process codes are required when enabling pipeline mode",
            "启用流水线模式时，至少需要两个有效工序编码",
        ),
        ("Cannot delete current login user", "不能删除当前登录用户"),
        ("Failed to approve registration request", "审批注册申请失败"),
        ("Failed to bootstrap admin", "初始化管理员失败"),
        ("Failed to create role", "创建角色失败"),
        ("Failed to create user", "创建用户失败"),
        ("Failed to delete user", "删除用户失败"),
        ("Failed to disable role", "停用角色失败"),
        ("Failed to disable user", "停用用户失败"),
        ("Failed to enable role", "启用角色失败"),
        ("Failed to enable user", "启用用户失败"),
        ("Failed to reject registration request", "驳回注册申请失败"),
        ("Failed to reset password", "重置密码失败"),
        ("Failed to restore user", "恢复用户失败"),
        ("Failed to submit registration request", "提交注册申请失败"),
        ("Failed to update role", "更新角色失败"),
        ("Failed to update user", "更新用户失败"),
        ("First article result must be passed or failed", "首件结果只能是通过或不通过"),
        ("proxy_operator_user_id is required for proxy view", "代理查看时代理操作员不能为空"),
        ("Review result must be passed or failed", "复核结果只能是通过或不通过"),
    )
    for english, chinese in exact_replacements:
        if normalized == english:
            return chinese

    inactive_reason_match = re.fullmatch(
        r"inactive_reason is required when target_status is inactive", normalized
    )
    if inactive_reason_match:
        return "目标状态为停用时，停用原因不能为空"

    if normalized.startswith("Value error, "):
        return localize_user_facing_message(normalized[len("Value error, ") :].strip())

    already_completed_match = re.fullmatch(r"(.+?) already completed", normalized)
    if already_completed_match:
        label = _label_to_cn(already_completed_match.group(1))
        return f"{label}已完成"

    cannot_be_greater_match = re.fullmatch(
        r"(.+?) cannot be greater than (.+)", normalized
    )
    if cannot_be_greater_match:
        left = _label_to_cn(cannot_be_greater_match.group(1))
        right = _label_to_cn(cannot_be_greater_match.group(2))
        return f"{left}不能大于{right}"

    return normalized


def localize_user_facing_detail(detail: object) -> object:
    if isinstance(detail, str):
        return localize_user_facing_message(detail)
    if isinstance(detail, list):
        return [localize_user_facing_detail(item) for item in detail]
    if isinstance(detail, dict):
        localized = dict(detail)
        message = localized.get("msg")
        if isinstance(message, str):
            localized["msg"] = localize_user_facing_message(message)
        return localized
    return detail


def localize_error_messages(messages: Iterable[str]) -> list[str]:
    return [localize_user_facing_message(message) for message in messages]

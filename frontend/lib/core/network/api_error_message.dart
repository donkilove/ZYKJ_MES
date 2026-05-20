String normalizeApiErrorMessage(String message, {int? statusCode}) {
  final normalized = message.trim();
  if (normalized.isEmpty) {
    return normalized;
  }

  const exactReplacements = <String, String>{
    'Access denied': '无权限访问',
    'Account is disabled': '账号已停用',
    'Account is pending approval': '账号正在审批中',
    'Account is rejected, please resubmit registration': '账号注册申请已驳回，请重新提交注册申请',
    'Deleted user cannot be enabled': '已删除用户不能启用',
    'Active assist authorization already exists': '已存在生效中的代班授权',
    'Current stage operator does not require assist authorization': '本工段操作员无需发起代班',
    'Current process pipeline instance already exists for requested sequence':
        '请求的工序序号已存在对应的流水线实例',
    'Current session not found': '当前会话不存在',
    'Excel export not available (openpyxl not installed)':
        'Excel 导出不可用：未安装 openpyxl',
    'Field required': '字段不能为空',
    'Incorrect username or password': '账号或密码错误',
    'Invalid authentication credentials': '登录态无效或已过期',
    'Maintenance plan already exists for this equipment and item':
        '该设备与保养项目的保养计划已存在',
    'Not Found': '请求的资源不存在',
    'not found': '请求的资源不存在',
    'Online session not found': '在线会话不存在',
    'Process name already exists in this stage': '当前工段下工序名称已存在',
    'Registration request not found': '注册申请不存在',
    'Registration request is pending approval': '注册申请正在审批中',
    'Registration request was rejected': '注册申请已驳回',
    'System master template already exists': '系统主模板已存在',
    'System master template not found': '系统主模板不存在',
    'Target operator not found or inactive': '目标操作员不存在或已停用',
    'Template name already exists under selected product': '所选产品下模板名称已存在',
    'Template name already exists under target product': '目标产品下模板名称已存在',
    'Template name already exists under this product': '当前产品下模板名称已存在',
    'User not found': '用户不存在',
  };
  final exactMatch = exactReplacements[normalized];
  if (exactMatch != null) {
    return exactMatch;
  }

  final rejectedMatch = RegExp(
    r'^Registration request was rejected:\s*(.+)$',
  ).firstMatch(normalized);
  if (rejectedMatch != null) {
    return '注册申请已驳回：${rejectedMatch.group(1)!.trim()}';
  }

  final roleExistsMatch = RegExp(
    r'^Role code already exists:\s*(.+)$',
  ).firstMatch(normalized);
  if (roleExistsMatch != null) {
    return '角色编码已存在：${roleExistsMatch.group(1)!.trim()}';
  }

  final notFoundWithValueMatch = RegExp(
    r'^(.+?) not found:\s*(.+)$',
  ).firstMatch(normalized);
  if (notFoundWithValueMatch != null) {
    final label = _fieldLabel(notFoundWithValueMatch.group(1)!);
    return '$label不存在：${notFoundWithValueMatch.group(2)!.trim()}';
  }

  final notFoundMatch = RegExp(r'^(.+?) not found$').firstMatch(normalized);
  if (notFoundMatch != null) {
    final label = _fieldLabel(notFoundMatch.group(1)!);
    return '$label不存在';
  }

  final notFoundOrInactiveMatch = RegExp(
    r'^(.+?) not found or inactive$',
  ).firstMatch(normalized);
  if (notFoundOrInactiveMatch != null) {
    final label = _fieldLabel(notFoundOrInactiveMatch.group(1)!);
    return '$label不存在或已停用';
  }

  final alreadyExistsMatch = RegExp(r'^(.+?) already exists$').firstMatch(
    normalized,
  );
  if (alreadyExistsMatch != null) {
    final label = _fieldLabel(alreadyExistsMatch.group(1)!);
    return '$label已存在';
  }

  final requiredMatch = RegExp(r'^(.+?) is required$').firstMatch(normalized);
  if (requiredMatch != null) {
    final label = _fieldLabel(requiredMatch.group(1)!);
    return '$label不能为空';
  }

  final disabledMatch = RegExp(r'^(.+?) is disabled$').firstMatch(normalized);
  if (disabledMatch != null) {
    final label = _fieldLabel(disabledMatch.group(1)!);
    return '$label已停用';
  }

  final impactConfirmationMatch = RegExp(
    r'^Impact confirmation required before (.+)$',
  ).firstMatch(normalized);
  if (impactConfirmationMatch != null) {
    final action = switch (impactConfirmationMatch.group(1)!.trim()) {
      'activation' => '生效',
      'rollback' => '回滚',
      'changing lifecycle' => '变更生命周期',
      'applying order sync' => '应用工单同步',
      final other => other,
    };
    return '$action前需要先确认影响范围';
  }

  if (normalized.startsWith('Value error, ')) {
    return normalizeApiErrorMessage(
      normalized.substring('Value error, '.length).trim(),
      statusCode: statusCode,
    );
  }

  if (normalized == 'At least one process step is required') {
    return '至少需要一道工序步骤';
  }
  if (normalized == 'At least one process is required') {
    return '至少需要选择一道工序';
  }
  if (normalized ==
      'At least two valid process codes are required when enabling pipeline mode') {
    return '启用流水线模式时，至少需要两个有效工序编码';
  }
  if (normalized ==
      'inactive_reason is required when target_status is inactive') {
    return '目标状态为停用时，停用原因不能为空';
  }
  if (normalized == 'Assist authorization is required for cross-user operation') {
    return '跨用户操作时必须提供代班授权';
  }
  if (normalized == 'proxy_operator_user_id is required for proxy view') {
    return '代理查看时代理操作员不能为空';
  }
  if (normalized == 'Review result must be passed or failed') {
    return '复核结果只能是通过或不通过';
  }
  if (normalized == 'First article result must be passed or failed') {
    return '首件结果只能是通过或不通过';
  }

  final inProgressRepairOrdersMatch = RegExp(
    r'^Order has in-progress repair orders that must be completed first:\s*(.+)$',
  ).firstMatch(normalized);
  if (inProgressRepairOrdersMatch != null) {
    return '该订单仍有维修中的维修单，请先完成维修单后再手工完工：'
        '${inProgressRepairOrdersMatch.group(1)!.trim()}';
  }

  final alreadyCompletedMatch = RegExp(
    r'^(.+?) already completed$',
  ).firstMatch(normalized);
  if (alreadyCompletedMatch != null) {
    final label = _fieldLabel(alreadyCompletedMatch.group(1)!);
    return '$label已完成';
  }

  final cannotBeGreaterMatch = RegExp(
    r'^(.+?) cannot be greater than (.+)$',
  ).firstMatch(normalized);
  if (cannotBeGreaterMatch != null) {
    final left = _fieldLabel(cannotBeGreaterMatch.group(1)!);
    final right = _fieldLabel(cannotBeGreaterMatch.group(2)!);
    return '$left不能大于$right';
  }

  if (statusCode != null && statusCode >= 500 && !_containsChinese(normalized)) {
    return '系统处理失败，请稍后重试。';
  }
  return normalized;
}

String extractApiErrorMessage(Map<String, dynamic> body, int statusCode) {
  final detail = body['detail'];
  if (detail is String && detail.trim().isNotEmpty) {
    return normalizeApiErrorMessage(detail, statusCode: statusCode);
  }
  if (detail is List) {
    final validationMessage = _extractValidationDetailMessage(detail);
    if (validationMessage != null) {
      return validationMessage;
    }
  }
  final message = body['message'];
  if (message is String && message.trim().isNotEmpty) {
    return normalizeApiErrorMessage(message, statusCode: statusCode);
  }
  return '请求失败，状态码 $statusCode';
}

bool isImpactConfirmationRequiredMessage(String message) {
  final normalized = normalizeApiErrorMessage(message);
  return normalized.contains('确认影响范围');
}

String? _extractValidationDetailMessage(List<dynamic> detail) {
  if (detail.isEmpty) {
    return null;
  }
  final messages = <String>[];
  for (final item in detail.take(3)) {
    if (item is! Map) {
      continue;
    }
    final mapped = item.cast<dynamic, dynamic>();
    final msg = normalizeApiErrorMessage(
      (mapped['msg'] as String? ?? '').trim(),
    );
    if (msg.isEmpty) {
      continue;
    }
    final loc = mapped['loc'];
    if (loc is List && loc.isNotEmpty) {
      final locParts = loc
          .map((entry) => entry.toString())
          .where((entry) => entry.isNotEmpty && entry != 'body')
          .toList();
      if (locParts.isNotEmpty) {
        final field = locParts.last;
        messages.add('${_fieldLabel(field)}：$msg');
        continue;
      }
    }
    messages.add(msg);
  }
  if (messages.isEmpty) {
    return null;
  }
  return messages.join('；');
}

String _fieldLabel(String field) {
  switch (field.trim().toLowerCase()) {
    case 'account':
      return '账号';
    case 'cause_items':
      return '原因明细';
    case 'current user':
      return '当前用户';
    case 'current session':
      return '当前会话';
    case 'default executor user':
      return '默认执行人';
    case 'equipment':
      return '设备';
    case 'equipment code':
      return '设备编码';
    case 'equipment rule code':
      return '设备规则编码';
    case 'equipment scope':
      return '设备范围';
    case 'execution process':
      return '执行工序';
    case 'helper user':
      return '代班人';
    case 'inactive_reason':
      return '停用原因';
    case 'maintenance item':
      return '保养项目';
    case 'maintenance item name':
      return '保养项目名称';
    case 'maintenance plan':
      return '保养计划';
    case 'module_code':
      return '模块编码';
    case 'new_template_name':
      return '新模板名称';
    case 'online session':
      return '在线会话';
    case 'order':
      return '工单';
    case 'order code':
    case 'order_code':
      return '工单编号';
    case 'order process':
    case 'order_process_id':
      return '工单工序';
    case 'permission_codes':
      return '权限编码';
    case 'phenomenon':
      return '不良现象';
    case 'process':
      return '工序';
    case 'process code':
    case 'process_code':
      return '工序编码';
    case 'process name':
      return '工序名称';
    case 'product':
      return '产品';
    case 'product name':
      return '产品名称';
    case 'product version':
      return '产品版本';
    case 'product_id':
      return '产品';
    case 'quantity':
      return '数量';
    case 'reason':
      return '原因';
    case 'registration request':
      return '注册申请';
    case 'repair order':
      return '返修工单';
    case 'review session':
      return '复核会话';
    case 'role':
      return '角色';
    case 'role code':
    case 'role_code':
      return '角色编码';
    case 'stage':
      return '工段';
    case 'stage code':
    case 'stage_code':
      return '工段编码';
    case 'stage name':
      return '工段名称';
    case 'stage_id':
      return '工段';
    case 'supplier_id':
      return '供应商';
    case 'target operator':
      return '目标操作员';
    case 'target_operator_user_id':
      return '目标操作员';
    case 'template':
      return '模板';
    case 'template name':
      return '模板名称';
    case 'template version':
      return '模板版本';
    case 'template_id':
      return '模板';
    case 'user':
      return '用户';
    case 'username':
      return '账号';
    case 'version':
      return '版本';
    default:
      return field;
  }
}

bool _containsChinese(String value) {
  return RegExp(r'[\u4e00-\u9fff]').hasMatch(value);
}

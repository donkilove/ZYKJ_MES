DateTime? _parseDateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

class UserItem {
  UserItem({
    required this.id,
    required this.username,
    required this.fullName,
    required this.remark,
    required this.isOnline,
    required this.isActive,
    required this.isDeleted,
    required this.mustChangePassword,
    required this.lastSeenAt,
    required this.stageId,
    required this.stageName,
    required this.roleCode,
    required this.roleName,
    required this.lastLoginAt,
    required this.lastLoginIp,
    required this.passwordChangedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String username;
  final String? fullName;
  final String? remark;
  final bool isOnline;
  final bool isActive;
  final bool isDeleted;
  final bool mustChangePassword;
  final DateTime? lastSeenAt;
  final int? stageId;
  final String? stageName;
  final String? roleCode;
  final String? roleName;
  final DateTime? lastLoginAt;
  final String? lastLoginIp;
  final DateTime? passwordChangedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: (json['id'] as int?) ?? 0,
      username: (json['username'] as String?) ?? '',
      fullName: json['full_name'] as String?,
      remark: json['remark'] as String?,
      isOnline: (json['is_online'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      isDeleted: (json['is_deleted'] as bool?) ?? false,
      mustChangePassword: (json['must_change_password'] as bool?) ?? false,
      lastSeenAt: _parseDateTimeOrNull(json['last_seen_at']),
      stageId: json['stage_id'] as int?,
      stageName: json['stage_name'] as String?,
      roleCode: json['role_code'] as String?,
      roleName: json['role_name'] as String?,
      lastLoginAt: _parseDateTimeOrNull(json['last_login_at']),
      lastLoginIp: json['last_login_ip'] as String?,
      passwordChangedAt: _parseDateTimeOrNull(json['password_changed_at']),
      createdAt: _parseDateTimeOrNull(json['created_at']),
      updatedAt: _parseDateTimeOrNull(json['updated_at']),
    );
  }

  UserItem copyWith({
    int? id,
    String? username,
    String? fullName,
    String? remark,
    bool? isOnline,
    bool? isActive,
    bool? isDeleted,
    bool? mustChangePassword,
    DateTime? lastSeenAt,
    int? stageId,
    String? stageName,
    String? roleCode,
    String? roleName,
    DateTime? lastLoginAt,
    String? lastLoginIp,
    DateTime? passwordChangedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserItem(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      remark: remark ?? this.remark,
      isOnline: isOnline ?? this.isOnline,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      stageId: stageId ?? this.stageId,
      stageName: stageName ?? this.stageName,
      roleCode: roleCode ?? this.roleCode,
      roleName: roleName ?? this.roleName,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLoginIp: lastLoginIp ?? this.lastLoginIp,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RoleItem {
  RoleItem({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.roleType,
    required this.isBuiltin,
    required this.isEnabled,
    required this.userCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final String roleType;
  final bool isBuiltin;
  final bool isEnabled;
  final int userCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RoleItem.fromJson(Map<String, dynamic> json) {
    return RoleItem(
      id: (json['id'] as int?) ?? 0,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      roleType: (json['role_type'] as String?) ?? '',
      isBuiltin: (json['is_builtin'] as bool?) ?? false,
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      userCount: (json['user_count'] as int?) ?? 0,
      createdAt: _parseDateTimeOrNull(json['created_at']),
      updatedAt: _parseDateTimeOrNull(json['updated_at']),
    );
  }
}

class ProcessItem {
  ProcessItem({
    required this.id,
    required this.code,
    required this.name,
    required this.stageId,
    required this.stageCode,
    required this.stageName,
  });

  final int id;
  final String code;
  final String name;
  final int? stageId;
  final String? stageCode;
  final String? stageName;

  factory ProcessItem.fromJson(Map<String, dynamic> json) {
    return ProcessItem(
      id: (json['id'] as int?) ?? 0,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      stageId: json['stage_id'] as int?,
      stageCode: json['stage_code'] as String?,
      stageName: json['stage_name'] as String?,
    );
  }
}

class UserListResult {
  UserListResult({required this.total, required this.items});

  final int total;
  final List<UserItem> items;
}

class RoleListResult {
  RoleListResult({required this.total, required this.items});

  final int total;
  final List<RoleItem> items;
}

class ProcessListResult {
  ProcessListResult({required this.total, required this.items});

  final int total;
  final List<ProcessItem> items;
}

class RegistrationRequestItem {
  RegistrationRequestItem({
    required this.id,
    required this.account,
    required this.status,
    required this.rejectedReason,
    required this.reviewedByUserId,
    required this.reviewedAt,
    required this.createdAt,
  });

  final int id;
  final String account;
  final String status;
  final String? rejectedReason;
  final int? reviewedByUserId;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory RegistrationRequestItem.fromJson(Map<String, dynamic> json) {
    return RegistrationRequestItem(
      id: (json['id'] as int?) ?? 0,
      account: (json['account'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      rejectedReason: json['rejected_reason'] as String?,
      reviewedByUserId: json['reviewed_by_user_id'] as int?,
      reviewedAt: _parseDateTimeOrNull(json['reviewed_at']),
      createdAt:
          _parseDateTimeOrNull(json['created_at']) ?? DateTime(1970, 1, 1),
    );
  }
}

class RegistrationRequestListResult {
  RegistrationRequestListResult({required this.total, required this.items});

  final int total;
  final List<RegistrationRequestItem> items;
}

class UserExportResult {
  UserExportResult({
    required this.filename,
    required this.contentType,
    required this.contentBase64,
  });

  final String filename;
  final String contentType;
  final String contentBase64;

  factory UserExportResult.fromJson(Map<String, dynamic> json) {
    return UserExportResult(
      filename: (json['filename'] as String?) ?? 'users_export.csv',
      contentType: (json['content_type'] as String?) ?? 'text/csv',
      contentBase64: (json['content_base64'] as String?) ?? '',
    );
  }
}

class UserLifecycleResult {
  UserLifecycleResult({
    required this.user,
    required this.forcedOfflineSessionCount,
    required this.clearedOnlineStatus,
  });

  final UserItem user;
  final int forcedOfflineSessionCount;
  final bool clearedOnlineStatus;

  factory UserLifecycleResult.fromJson(Map<String, dynamic> json) {
    return UserLifecycleResult(
      user: UserItem.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      forcedOfflineSessionCount:
          (json['forced_offline_session_count'] as int?) ?? 0,
      clearedOnlineStatus: (json['cleared_online_status'] as bool?) ?? false,
    );
  }
}

class UserExportTaskItem {
  UserExportTaskItem({
    required this.id,
    required this.taskCode,
    required this.status,
    required this.format,
    required this.deletedScope,
    required this.keyword,
    required this.roleCode,
    required this.isActive,
    required this.recordCount,
    required this.fileName,
    required this.mimeType,
    required this.failureReason,
    required this.requestedAt,
    required this.startedAt,
    required this.finishedAt,
    required this.expiresAt,
  });

  final int id;
  final String taskCode;
  final String status;
  final String format;
  final String deletedScope;
  final String? keyword;
  final String? roleCode;
  final bool? isActive;
  final int recordCount;
  final String? fileName;
  final String? mimeType;
  final String? failureReason;
  final DateTime? requestedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? expiresAt;

  factory UserExportTaskItem.fromJson(Map<String, dynamic> json) {
    return UserExportTaskItem(
      id: (json['id'] as int?) ?? 0,
      taskCode: (json['task_code'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      format: (json['format'] as String?) ?? 'csv',
      deletedScope: (json['deleted_scope'] as String?) ?? 'active',
      keyword: json['keyword'] as String?,
      roleCode: json['role_code'] as String?,
      isActive: json['is_active'] as bool?,
      recordCount: (json['record_count'] as int?) ?? 0,
      fileName: json['file_name'] as String?,
      mimeType: json['mime_type'] as String?,
      failureReason: json['failure_reason'] as String?,
      requestedAt: _parseDateTimeOrNull(json['requested_at']),
      startedAt: _parseDateTimeOrNull(json['started_at']),
      finishedAt: _parseDateTimeOrNull(json['finished_at']),
      expiresAt: _parseDateTimeOrNull(json['expires_at']),
    );
  }
}

class UserExportTaskListResult {
  UserExportTaskListResult({required this.total, required this.items});

  final int total;
  final List<UserExportTaskItem> items;
}

class UserExportDownloadResult {
  UserExportDownloadResult({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  final String filename;
  final String mimeType;
  final List<int> bytes;
}

class UserDeleteResult {
  UserDeleteResult({
    required this.user,
    required this.forcedOfflineSessionCount,
    required this.clearedOnlineStatus,
    required this.deleted,
  });

  final UserItem user;
  final int forcedOfflineSessionCount;
  final bool clearedOnlineStatus;
  final bool deleted;

  factory UserDeleteResult.fromJson(Map<String, dynamic> json) {
    return UserDeleteResult(
      user: UserItem.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      forcedOfflineSessionCount:
          (json['forced_offline_session_count'] as int?) ?? 0,
      clearedOnlineStatus: (json['cleared_online_status'] as bool?) ?? false,
      deleted: (json['deleted'] as bool?) ?? false,
    );
  }
}

class UserPasswordResetResult {
  UserPasswordResetResult({
    required this.user,
    required this.forcedOfflineSessionCount,
    required this.mustChangePassword,
    required this.clearedOnlineStatus,
  });

  final UserItem user;
  final int forcedOfflineSessionCount;
  final bool mustChangePassword;
  final bool clearedOnlineStatus;

  factory UserPasswordResetResult.fromJson(Map<String, dynamic> json) {
    return UserPasswordResetResult(
      user: UserItem.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      forcedOfflineSessionCount:
          (json['forced_offline_session_count'] as int?) ?? 0,
      mustChangePassword: (json['must_change_password'] as bool?) ?? true,
      clearedOnlineStatus: (json['cleared_online_status'] as bool?) ?? false,
    );
  }
}

class AuditLogItem {
  AuditLogItem({
    required this.id,
    required this.occurredAt,
    required this.operatorUserId,
    required this.operatorUsername,
    required this.actionCode,
    required this.actionName,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.result,
    required this.beforeData,
    required this.afterData,
    required this.ipAddress,
    required this.terminalInfo,
    required this.remark,
  });

  final int id;
  final DateTime? occurredAt;
  final int? operatorUserId;
  final String? operatorUsername;
  final String actionCode;
  final String actionName;
  final String targetType;
  final String? targetId;
  final String? targetName;
  final String result;
  final Map<String, dynamic>? beforeData;
  final Map<String, dynamic>? afterData;
  final String? ipAddress;
  final String? terminalInfo;
  final String? remark;

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: (json['id'] as int?) ?? 0,
      occurredAt: _parseDateTimeOrNull(json['occurred_at']),
      operatorUserId: json['operator_user_id'] as int?,
      operatorUsername: json['operator_username'] as String?,
      actionCode: (json['action_code'] as String?) ?? '',
      actionName: (json['action_name'] as String?) ?? '',
      targetType: (json['target_type'] as String?) ?? '',
      targetId: json['target_id'] as String?,
      targetName: json['target_name'] as String?,
      result: (json['result'] as String?) ?? '',
      beforeData: (json['before_data'] as Map<String, dynamic>?),
      afterData: (json['after_data'] as Map<String, dynamic>?),
      ipAddress: json['ip_address'] as String?,
      terminalInfo: json['terminal_info'] as String?,
      remark: json['remark'] as String?,
    );
  }
}

class AuditLogListResult {
  AuditLogListResult({required this.total, required this.items});

  final int total;
  final List<AuditLogItem> items;
}

class ProfileResult {
  ProfileResult({
    required this.id,
    required this.username,
    required this.fullName,
    required this.roleCode,
    required this.roleName,
    required this.stageId,
    required this.stageName,
    required this.isActive,
    required this.createdAt,
    required this.lastLoginAt,
    required this.lastLoginIp,
    required this.passwordChangedAt,
  });

  final int id;
  final String username;
  final String? fullName;
  final String? roleCode;
  final String? roleName;
  final int? stageId;
  final String? stageName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final String? lastLoginIp;
  final DateTime? passwordChangedAt;

  factory ProfileResult.fromJson(Map<String, dynamic> json) {
    return ProfileResult(
      id: (json['id'] as int?) ?? 0,
      username: (json['username'] as String?) ?? '',
      fullName: json['full_name'] as String?,
      roleCode: json['role_code'] as String?,
      roleName: json['role_name'] as String?,
      stageId: json['stage_id'] as int?,
      stageName: json['stage_name'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: _parseDateTimeOrNull(json['created_at']),
      lastLoginAt: _parseDateTimeOrNull(json['last_login_at']),
      lastLoginIp: json['last_login_ip'] as String?,
      passwordChangedAt: _parseDateTimeOrNull(json['password_changed_at']),
    );
  }
}

class CurrentSessionResult {
  CurrentSessionResult({
    required this.sessionTokenId,
    required this.loginTime,
    required this.lastActiveAt,
    required this.expiresAt,
    required this.status,
    required this.remainingSeconds,
  });

  final String sessionTokenId;
  final DateTime? loginTime;
  final DateTime? lastActiveAt;
  final DateTime? expiresAt;
  final String status;
  final int remainingSeconds;

  factory CurrentSessionResult.fromJson(Map<String, dynamic> json) {
    return CurrentSessionResult(
      sessionTokenId: (json['session_token_id'] as String?) ?? '',
      loginTime: _parseDateTimeOrNull(json['login_time']),
      lastActiveAt: _parseDateTimeOrNull(json['last_active_at']),
      expiresAt: _parseDateTimeOrNull(json['expires_at']),
      status: (json['status'] as String?) ?? '',
      remainingSeconds: (json['remaining_seconds'] as int?) ?? 0,
    );
  }
}

class LoginLogItem {
  LoginLogItem({
    required this.id,
    required this.loginTime,
    required this.username,
    required this.success,
    required this.ipAddress,
    required this.terminalInfo,
    required this.failureReason,
    required this.sessionTokenId,
  });

  final int id;
  final DateTime? loginTime;
  final String username;
  final bool success;
  final String? ipAddress;
  final String? terminalInfo;
  final String? failureReason;
  final String? sessionTokenId;

  factory LoginLogItem.fromJson(Map<String, dynamic> json) {
    return LoginLogItem(
      id: (json['id'] as int?) ?? 0,
      loginTime: _parseDateTimeOrNull(json['login_time']),
      username: (json['username'] as String?) ?? '',
      success: (json['success'] as bool?) ?? false,
      ipAddress: json['ip_address'] as String?,
      terminalInfo: json['terminal_info'] as String?,
      failureReason: json['failure_reason'] as String?,
      sessionTokenId: json['session_token_id'] as String?,
    );
  }
}

class LoginLogListResult {
  LoginLogListResult({required this.total, required this.items});

  final int total;
  final List<LoginLogItem> items;
}

class OnlineSessionItem {
  OnlineSessionItem({
    required this.id,
    required this.sessionTokenId,
    required this.userId,
    required this.username,
    required this.roleCode,
    required this.roleName,
    required this.stageId,
    required this.stageName,
    required this.loginTime,
    required this.lastActiveAt,
    required this.expiresAt,
    required this.ipAddress,
    required this.terminalInfo,
    required this.status,
  });

  final int id;
  final String sessionTokenId;
  final int userId;
  final String username;
  final String? roleCode;
  final String? roleName;
  final int? stageId;
  final String? stageName;
  final DateTime? loginTime;
  final DateTime? lastActiveAt;
  final DateTime? expiresAt;
  final String? ipAddress;
  final String? terminalInfo;
  final String status;

  factory OnlineSessionItem.fromJson(Map<String, dynamic> json) {
    return OnlineSessionItem(
      id: (json['id'] as int?) ?? 0,
      sessionTokenId: (json['session_token_id'] as String?) ?? '',
      userId: (json['user_id'] as int?) ?? 0,
      username: (json['username'] as String?) ?? '',
      roleCode: json['role_code'] as String?,
      roleName: json['role_name'] as String?,
      stageId: json['stage_id'] as int?,
      stageName: json['stage_name'] as String?,
      loginTime: _parseDateTimeOrNull(json['login_time']),
      lastActiveAt: _parseDateTimeOrNull(json['last_active_at']),
      expiresAt: _parseDateTimeOrNull(json['expires_at']),
      ipAddress: json['ip_address'] as String?,
      terminalInfo: json['terminal_info'] as String?,
      status: (json['status'] as String?) ?? '',
    );
  }
}

class OnlineSessionListResult {
  OnlineSessionListResult({required this.total, required this.items});

  final int total;
  final List<OnlineSessionItem> items;
}

class ForceOfflineResult {
  ForceOfflineResult({required this.affected});

  final int affected;

  factory ForceOfflineResult.fromJson(Map<String, dynamic> json) {
    return ForceOfflineResult(affected: (json['affected'] as int?) ?? 0);
  }
}

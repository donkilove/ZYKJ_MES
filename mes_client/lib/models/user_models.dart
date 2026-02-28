class UserItem {
  UserItem({
    required this.id,
    required this.username,
    required this.fullName,
    required this.isOnline,
    required this.lastSeenAt,
    required this.roleCodes,
    required this.roleNames,
    required this.processCodes,
    required this.processNames,
  });

  final int id;
  final String username;
  final String? fullName;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final List<String> roleCodes;
  final List<String> roleNames;
  final List<String> processCodes;
  final List<String> processNames;

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeenAt: json['last_seen_at'] == null
          ? null
          : DateTime.parse(json['last_seen_at'] as String),
      roleCodes: (json['role_codes'] as List<dynamic>).cast<String>(),
      roleNames: (json['role_names'] as List<dynamic>).cast<String>(),
      processCodes: (json['process_codes'] as List<dynamic>).cast<String>(),
      processNames: (json['process_names'] as List<dynamic>).cast<String>(),
    );
  }
}

class RoleItem {
  RoleItem({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  factory RoleItem.fromJson(Map<String, dynamic> json) {
    return RoleItem(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}

class ProcessItem {
  ProcessItem({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  factory ProcessItem.fromJson(Map<String, dynamic> json) {
    return ProcessItem(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
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
    required this.createdAt,
  });

  final int id;
  final String account;
  final DateTime createdAt;

  factory RegistrationRequestItem.fromJson(Map<String, dynamic> json) {
    return RegistrationRequestItem(
      id: json['id'] as int,
      account: json['account'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RegistrationRequestListResult {
  RegistrationRequestListResult({required this.total, required this.items});

  final int total;
  final List<RegistrationRequestItem> items;
}

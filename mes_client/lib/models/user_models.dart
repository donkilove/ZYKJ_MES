class UserItem {
  UserItem({
    required this.id,
    required this.username,
    required this.fullName,
    required this.roleCodes,
    required this.roleNames,
    required this.processCodes,
    required this.processNames,
  });

  final int id;
  final String username;
  final String? fullName;
  final List<String> roleCodes;
  final List<String> roleNames;
  final List<String> processCodes;
  final List<String> processNames;

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      roleCodes: (json['role_codes'] as List<dynamic>).cast<String>(),
      roleNames: (json['role_names'] as List<dynamic>).cast<String>(),
      processCodes: (json['process_codes'] as List<dynamic>).cast<String>(),
      processNames: (json['process_names'] as List<dynamic>).cast<String>(),
    );
  }
}

class RoleItem {
  RoleItem({
    required this.id,
    required this.code,
    required this.name,
  });

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
  ProcessItem({
    required this.id,
    required this.code,
    required this.name,
  });

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
  UserListResult({
    required this.total,
    required this.items,
  });

  final int total;
  final List<UserItem> items;
}

class RoleListResult {
  RoleListResult({
    required this.total,
    required this.items,
  });

  final int total;
  final List<RoleItem> items;
}

class ProcessListResult {
  ProcessListResult({
    required this.total,
    required this.items,
  });

  final int total;
  final List<ProcessItem> items;
}

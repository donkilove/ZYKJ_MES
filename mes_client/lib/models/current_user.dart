class CurrentUser {
  CurrentUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.roleCodes,
    required this.roleNames,
    required this.processCodes,
    required this.processNames,
    required this.permissionCodes,
  });

  final int id;
  final String username;
  final String? fullName;
  final List<String> roleCodes;
  final List<String> roleNames;
  final List<String> processCodes;
  final List<String> processNames;
  final List<String> permissionCodes;

  String get displayName => (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : username;

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      roleCodes: (json['role_codes'] as List<dynamic>).cast<String>(),
      roleNames: (json['role_names'] as List<dynamic>).cast<String>(),
      processCodes: (json['process_codes'] as List<dynamic>).cast<String>(),
      processNames: (json['process_names'] as List<dynamic>).cast<String>(),
      permissionCodes: (json['permission_codes'] as List<dynamic>).cast<String>(),
    );
  }
}

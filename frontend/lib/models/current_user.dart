class CurrentUser {
  CurrentUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.roleCode,
    required this.roleName,
    required this.stageId,
    required this.stageName,
  });

  final int id;
  final String username;
  final String? fullName;
  final String? roleCode;
  final String? roleName;
  final int? stageId;
  final String? stageName;

  String get displayName => (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : username;

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      roleCode: json['role_code'] as String?,
      roleName: json['role_name'] as String?,
      stageId: json['stage_id'] as int?,
      stageName: json['stage_name'] as String?,
    );
  }
}

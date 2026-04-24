class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.entryScript,
    required this.pythonVersion,
    required this.arch,
    required this.dependencyPaths,
    required this.permissions,
    required this.startupTimeoutSeconds,
    required this.heartbeatIntervalSeconds,
  });

  final String id;
  final String name;
  final String version;
  final String entryScript;
  final String pythonVersion;
  final String arch;
  final List<String> dependencyPaths;
  final List<String> permissions;
  final int startupTimeoutSeconds;
  final int heartbeatIntervalSeconds;

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    String requireString(Map<String, dynamic> source, String keyPath) {
      final segments = keyPath.split('.');
      dynamic current = source;
      for (final segment in segments) {
        if (current is! Map<String, dynamic> || !current.containsKey(segment)) {
          throw FormatException('缺少必填字段：$keyPath');
        }
        current = current[segment];
      }
      if (current is! String || current.trim().isEmpty) {
        throw FormatException('字段无效：$keyPath');
      }
      return current.trim();
    }

    List<String> readStringList(Map<String, dynamic> source, String keyPath) {
      final segments = keyPath.split('.');
      dynamic current = source;
      for (final segment in segments) {
        if (current is! Map<String, dynamic> || !current.containsKey(segment)) {
          throw FormatException('缺少必填字段：$keyPath');
        }
        current = current[segment];
      }
      if (current is! List) {
        throw FormatException('字段无效：$keyPath');
      }
      return current.map((item) => item.toString()).toList(growable: false);
    }

    int requireInt(Map<String, dynamic> source, String keyPath) {
      final segments = keyPath.split('.');
      dynamic current = source;
      for (final segment in segments) {
        if (current is! Map<String, dynamic> || !current.containsKey(segment)) {
          throw FormatException('缺少必填字段：$keyPath');
        }
        current = current[segment];
      }
      if (current is! int) {
        throw FormatException('字段无效：$keyPath');
      }
      return current;
    }

    return PluginManifest(
      id: requireString(json, 'id'),
      name: requireString(json, 'name'),
      version: requireString(json, 'version'),
      entryScript: requireString(json, 'entry.script'),
      pythonVersion: requireString(json, 'runtime.python'),
      arch: requireString(json, 'runtime.arch'),
      dependencyPaths: readStringList(json, 'dependencies.paths'),
      permissions: readStringList(json, 'permissions'),
      startupTimeoutSeconds: requireInt(json, 'lifecycle.startup_timeout_sec'),
      heartbeatIntervalSeconds: requireInt(
        json,
        'lifecycle.heartbeat_interval_sec',
      ),
    );
  }
}

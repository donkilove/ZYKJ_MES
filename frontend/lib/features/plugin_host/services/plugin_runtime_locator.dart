import 'dart:io';

import 'package:path/path.dart' as p;

class PluginRuntimeLocator {
  PluginRuntimeLocator({
    String? executablePath,
    Map<String, String>? environment,
    String? currentDirectory,
    bool Function(String path)? directoryExists,
  }) : executablePath = executablePath ?? Platform.resolvedExecutable,
       environment = environment ?? Platform.environment,
       currentDirectory = currentDirectory ?? Directory.current.path,
       directoryExists =
           directoryExists ?? ((path) => Directory(path).existsSync());

  final String executablePath;
  final Map<String, String> environment;
  final String currentDirectory;
  final bool Function(String path) directoryExists;

  bool dirExists(String path) => directoryExists(path);

  bool fileExists(String path) => File(path).existsSync();

  String resolvePythonExecutable() {
    final externalRuntimeDir = environment['MES_PYTHON_RUNTIME_DIR']?.trim();
    if (externalRuntimeDir != null && externalRuntimeDir.isNotEmpty) {
      return p.join(externalRuntimeDir, 'python.exe');
    }
    return p.join(resolvePluginRoot(), 'runtime', 'python312', 'python.exe');
  }

  String resolvePluginRoot() {
    final externalPluginRoot = environment['MES_PLUGIN_ROOT']?.trim();
    if (externalPluginRoot != null && externalPluginRoot.isNotEmpty) {
      return externalPluginRoot;
    }

    final repoRoot =
        _findRepoRoot(p.dirname(executablePath)) ?? _findRepoRoot(currentDirectory);
    if (repoRoot != null) {
      return p.join(repoRoot, 'plugins');
    }

    return p.join(p.dirname(executablePath), 'plugins');
  }

  String? _findRepoRoot(String start) {
    var cursor = p.normalize(start);
    while (true) {
      if (_isRepoRoot(cursor)) {
        return cursor;
      }

      final parent = p.dirname(cursor);
      if (parent == cursor) {
        return null;
      }
      cursor = parent;
    }
  }

  bool _isRepoRoot(String path) {
    return directoryExists(p.join(path, 'frontend')) &&
        directoryExists(p.join(path, 'plugins'));
  }
}

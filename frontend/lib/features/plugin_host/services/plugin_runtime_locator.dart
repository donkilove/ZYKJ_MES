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

  String resolvePythonExecutable() {
    final externalRuntimeDir = environment['MES_PYTHON_RUNTIME_DIR']?.trim();
    if (externalRuntimeDir != null && externalRuntimeDir.isNotEmpty) {
      return p.join(externalRuntimeDir, 'python.exe');
    }
    return p.join(
      p.dirname(executablePath),
      'runtime',
      'python',
      'python.exe',
    );
  }

  String resolvePluginRoot() {
    final externalPluginRoot = environment['MES_PLUGIN_ROOT']?.trim();
    if (externalPluginRoot != null && externalPluginRoot.isNotEmpty) {
      return externalPluginRoot;
    }

    final seen = <String>{};
    for (final start in <String>[currentDirectory, p.dirname(executablePath)]) {
      var cursor = p.normalize(start);
      while (true) {
        final candidate = p.join(cursor, 'plugins');
        final normalizedCandidate = p.normalize(candidate);
        if (seen.add(normalizedCandidate) && directoryExists(normalizedCandidate)) {
          return normalizedCandidate;
        }

        final parent = p.dirname(cursor);
        if (parent == cursor) {
          break;
        }
        cursor = parent;
      }
    }

    return p.join(p.dirname(executablePath), 'plugins');
  }
}

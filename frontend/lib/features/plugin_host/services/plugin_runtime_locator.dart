import 'dart:io';

import 'package:path/path.dart' as p;

class PluginRuntimeLocator {
  PluginRuntimeLocator({
    String? executablePath,
    Map<String, String>? environment,
  }) : executablePath = executablePath ?? Platform.resolvedExecutable,
       environment = environment ?? Platform.environment;

  final String executablePath;
  final Map<String, String> environment;

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
    return p.join(p.dirname(executablePath), 'plugins');
  }
}

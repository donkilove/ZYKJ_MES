import 'dart:io';

class PluginSession {
  const PluginSession({
    required this.pluginId,
    required this.process,
    required this.pid,
    required this.entryUrl,
    required this.heartbeatUrl,
  });

  final String pluginId;
  final Process? process;
  final int pid;
  final Uri entryUrl;
  final Uri? heartbeatUrl;
}

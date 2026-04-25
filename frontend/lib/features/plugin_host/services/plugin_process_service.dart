import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_session.dart';
import 'package:path/path.dart' as p;

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
});

class PluginProcessService {
  PluginProcessService({
    ProcessStarter? processStarter,
    Future<bool> Function(Uri heartbeatUrl)? heartbeatClient,
    bool Function(Process process)? killProcess,
    this.readyTimeout = const Duration(seconds: 15),
  }) : processStarter = processStarter ?? Process.start,
       heartbeatClient =
           heartbeatClient ??
           ((heartbeatUrl) async {
             final response = await http.get(heartbeatUrl);
             return response.statusCode == 200;
           }),
       killProcess = killProcess ?? ((process) => process.kill());

  final ProcessStarter processStarter;
  final Future<bool> Function(Uri heartbeatUrl) heartbeatClient;
  final bool Function(Process process) killProcess;
  final Duration readyTimeout;

  Future<PluginSession> start({
    required PluginCatalogItem plugin,
    required String pythonExecutable,
    required String runtimeRoot,
  }) async {
    final manifest = plugin.manifest;
    if (manifest == null) {
      throw ArgumentError('插件缺少可用 manifest，无法启动');
    }

    final environment = <String, String>{
      'PYTHONHOME': runtimeRoot,
      'MES_PLUGIN_ID': manifest.id,
      'MES_PLUGIN_DIR': plugin.directory.path,
      'MES_PLUGIN_VENDOR_DIR': p.join(plugin.directory.path, 'vendor'),
      'MES_PLUGIN_APP_DIR': p.join(plugin.directory.path, 'app'),
      'MES_RUNTIME_DIR': runtimeRoot,
      'MES_HOST_SESSION_ID': DateTime.now().microsecondsSinceEpoch.toString(),
    };

    final process = await processStarter(
      pythonExecutable,
      [p.join(plugin.directory.path, manifest.entryScript)],
      workingDirectory: plugin.directory.path,
      environment: environment,
    );

    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    late final String readyLine;
    try {
      readyLine = await lines.first.timeout(readyTimeout);
    } on StateError {
      throw TimeoutException('插件未在限定时间内返回 ready 消息');
    }
    final payload = jsonDecode(readyLine) as Map<String, dynamic>;
    if (payload['event'] != 'ready') {
      throw const FormatException('ready 消息 event 非法');
    }
    if (payload['pid'] is! int || payload['entry_url'] is! String) {
      throw const FormatException('ready 消息缺少 pid 或 entry_url');
    }

    return PluginSession(
      pluginId: manifest.id,
      process: process,
      pid: payload['pid'] as int,
      entryUrl: Uri.parse(payload['entry_url'] as String),
      heartbeatUrl: payload['heartbeat_url'] == null
          ? null
          : Uri.parse(payload['heartbeat_url'] as String),
    );
  }

  Future<bool> ping(PluginSession session) async {
    final heartbeatUrl = session.heartbeatUrl;
    if (heartbeatUrl == null) {
      return true;
    }
    return heartbeatClient(heartbeatUrl);
  }

  Future<void> stop(PluginSession session) async {
    final process = session.process;
    if (process == null) {
      return;
    }
    killProcess(process);
  }
}

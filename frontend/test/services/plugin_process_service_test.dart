import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';
import 'package:mes_client/features/plugin_host/models/plugin_session.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';

void main() {
  test('start 会注入 PYTHONPATH 并解析 ready 消息', () async {
    final process = _FakeProcess.ready(
      '{"event":"ready","pid":456,"entry_url":"http://127.0.0.1:43125/","heartbeat_url":"http://127.0.0.1:43125/__heartbeat__"}',
    );
    Map<String, String>? capturedEnvironment;

    final service = PluginProcessService(
      processStarter: (
        executable,
        arguments, {
        workingDirectory,
        environment,
      }) async {
        capturedEnvironment = environment;
        return process;
      },
      heartbeatClient: (_) async => true,
    );

    final session = await service.start(
      plugin: PluginCatalogItem(
        directory: Directory.systemTemp,
        manifest: const PluginManifest(
          id: 'serial_assistant',
          name: '串口助手',
          version: '0.1.0',
          entryScript: 'launcher.py',
          pythonVersion: '3.14',
          arch: 'win_amd64',
          dependencyPaths: ['vendor', 'app'],
          permissions: ['serial'],
          startupTimeoutSeconds: 15,
          heartbeatIntervalSeconds: 5,
        ),
        status: PluginCatalogItemStatus.ready,
      ),
      pythonExecutable: r'C:\runtime\python\python.exe',
      runtimeRoot: r'C:\runtime\python',
    );

    expect(capturedEnvironment, isNotNull);
    expect(capturedEnvironment!['PYTHONPATH'], contains('vendor'));
    expect(session.entryUrl.toString(), 'http://127.0.0.1:43125/');
    expect(session.pid, 456);
  });

  test('ping 在 heartbeat 返回 true 时为 true，stop 会结束进程', () async {
    var killed = false;
    final process = _FakeProcess.ready(
      '{"event":"ready","pid":456,"entry_url":"http://127.0.0.1:43125/","heartbeat_url":"http://127.0.0.1:43125/__heartbeat__"}',
    );
    final session = PluginSession(
      pluginId: 'serial_assistant',
      process: process,
      pid: 456,
      entryUrl: Uri.parse('http://127.0.0.1:43125/'),
      heartbeatUrl: Uri.parse('http://127.0.0.1:43125/__heartbeat__'),
    );
    final service = PluginProcessService(
      processStarter: (
        executable,
        arguments, {
        workingDirectory,
        environment,
      }) async => process,
      heartbeatClient: (_) async => true,
      killProcess: (target) {
        killed = true;
        return true;
      },
    );

    expect(await service.ping(session), isTrue);
    await service.stop(session);
    expect(killed, isTrue);
  });
}

class _FakeProcess implements Process {
  _FakeProcess.ready(String line)
    : _stdout = Stream<List<int>>.value(utf8.encode('$line\n')),
      _stdinController = StreamController<List<int>>();

  final Stream<List<int>> _stdout;
  final StreamController<List<int>> _stdinController;

  @override
  int get pid => 456;

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => IOSink(_stdinController.sink);

  @override
  Future<int> get exitCode async => 0;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

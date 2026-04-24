import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_host_view_state.dart';
import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';
import 'package:mes_client/features/plugin_host/models/plugin_session.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';

void main() {
  test('openPlugin 会把视图状态切到 starting', () async {
    final controller = PluginHostController(
      catalogService: _StubCatalogService.withPlugin(),
      processService: _BlockingProcessService(),
      runtimeLocator: _StubRuntimeLocator(),
    );
    await controller.loadCatalog();

    controller.openPlugin('serial_assistant');
    await Future<void>.delayed(Duration.zero);

    expect(controller.viewState.phase, PluginHostPhase.starting);
    expect(controller.viewState.focusedPluginId, 'serial_assistant');
  });

  test('已运行时再次打开同一插件不会重复拉起进程', () async {
    final processService = _CountingProcessService();
    final controller = PluginHostController(
      catalogService: _StubCatalogService.withPlugin(),
      processService: processService,
      runtimeLocator: _StubRuntimeLocator(),
    );
    await controller.loadCatalog();

    controller.debugInjectRunningSession(
      PluginSession(
        pluginId: 'serial_assistant',
        process: null,
        pid: 456,
        entryUrl: Uri.parse('http://127.0.0.1:43125/'),
        heartbeatUrl: Uri.parse('http://127.0.0.1:43125/__heartbeat__'),
      ),
    );

    await controller.openPlugin('serial_assistant');

    expect(processService.startCount, 0);
    expect(controller.viewState.phase, PluginHostPhase.running);
  });

  test('启动失败时会进入 failed 状态并保留错误信息', () async {
    final controller = PluginHostController(
      catalogService: _StubCatalogService.withPlugin(),
      processService: _FailingProcessService(),
      runtimeLocator: _StubRuntimeLocator(),
    );
    await controller.loadCatalog();

    await controller.openPlugin('serial_assistant');

    expect(controller.viewState.phase, PluginHostPhase.failed);
    expect(controller.viewState.errorMessage, contains('ready timeout'));
  });
}

class _StubCatalogService extends PluginCatalogService {
  _StubCatalogService.withPlugin()
    : super(pluginRootResolver: () async => '');

  @override
  Future<List<PluginCatalogItem>> scan() async {
    return [
      PluginCatalogItem(
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
    ];
  }
}

class _StubRuntimeLocator extends PluginRuntimeLocator {
  _StubRuntimeLocator()
    : super(
        executablePath: r'C:\ZYKJ_MES\mes_client.exe',
        environment: const {},
      );
}

class _BlockingProcessService extends PluginProcessService {
  _BlockingProcessService();

  @override
  Future<PluginSession> start({
    required PluginCatalogItem plugin,
    required String pythonExecutable,
    required String runtimeRoot,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return PluginSession(
      pluginId: plugin.manifest!.id,
      process: null,
      pid: 456,
      entryUrl: Uri.parse('http://127.0.0.1:43125/'),
      heartbeatUrl: Uri.parse('http://127.0.0.1:43125/__heartbeat__'),
    );
  }
}

class _CountingProcessService extends PluginProcessService {
  _CountingProcessService();

  int startCount = 0;

  @override
  Future<PluginSession> start({
    required PluginCatalogItem plugin,
    required String pythonExecutable,
    required String runtimeRoot,
  }) async {
    startCount += 1;
    return PluginSession(
      pluginId: plugin.manifest!.id,
      process: null,
      pid: 456,
      entryUrl: Uri.parse('http://127.0.0.1:43125/'),
      heartbeatUrl: Uri.parse('http://127.0.0.1:43125/__heartbeat__'),
    );
  }
}

class _FailingProcessService extends PluginProcessService {
  _FailingProcessService();

  @override
  Future<PluginSession> start({
    required PluginCatalogItem plugin,
    required String pythonExecutable,
    required String runtimeRoot,
  }) {
    throw TimeoutException('ready timeout');
  }
}

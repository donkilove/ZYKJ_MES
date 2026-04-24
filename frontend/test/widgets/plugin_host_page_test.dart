import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_page.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';

void main() {
  testWidgets('插件中心会渲染列表与空工作区', (tester) async {
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PluginHostPage(controller: controller))),
    );
    await tester.pumpAndSettle();

    expect(find.text('插件中心'), findsOneWidget);
    expect(find.text('串口助手'), findsOneWidget);
    expect(find.text('选择一个插件以打开工作区'), findsOneWidget);
  });
}

class _StubCatalogService extends PluginCatalogService {
  _StubCatalogService() : super(pluginRootResolver: () async => '');

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

class _StubProcessService extends PluginProcessService {
  _StubProcessService();
}

class _StubRuntimeLocator extends PluginRuntimeLocator {
  _StubRuntimeLocator()
    : super(
        executablePath: r'C:\ZYKJ_MES\mes_client.exe',
        environment: const {},
      );
}

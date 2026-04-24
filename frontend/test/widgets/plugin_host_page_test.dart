import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';
import 'package:mes_client/features/plugin_host/models/plugin_session.dart';
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

  testWidgets('插件列表为空时会提示检查插件目录', (tester) async {
    final controller = PluginHostController(
      catalogService: _EmptyCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PluginHostPage(controller: controller))),
    );
    await tester.pumpAndSettle();

    expect(find.text('未发现插件，请检查插件目录。'), findsOneWidget);
  });

  testWidgets('点击左侧插件项后工作区显示启动面板', (tester) async {
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _BlockingProcessService(),
      runtimeLocator: _StubRuntimeLocator(),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PluginHostPage(controller: controller))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('串口助手'));
    await tester.pump();

    expect(find.text('正在启动串口助手'), findsOneWidget);
    expect(find.textContaining('等待页面就绪'), findsOneWidget);
  });

  testWidgets('启动失败时工作区显示异常面板', (tester) async {
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _FailingProcessService(),
      runtimeLocator: _StubRuntimeLocator(),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PluginHostPage(controller: controller))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('串口助手'));
    await tester.pumpAndSettle();

    expect(find.text('串口助手启动失败'), findsOneWidget);
    expect(find.textContaining('ready timeout'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重试'), findsOneWidget);
  });

  testWidgets('工作区在存在活动会话时会显示内嵌区域与宿主工具条', (tester) async {
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(),
    );
    controller.debugInjectSession(
      PluginSession(
        pluginId: 'serial_assistant',
        process: null,
        pid: 456,
        entryUrl: Uri.parse('http://127.0.0.1:43125/'),
        heartbeatUrl: Uri.parse('http://127.0.0.1:43125/__heartbeat__'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginHostPage(
            controller: controller,
            webviewBuilder: (entryUrl) => Text('WEBVIEW:$entryUrl'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WEBVIEW:http://127.0.0.1:43125/'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '关闭插件'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重启插件'), findsOneWidget);
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

class _EmptyCatalogService extends PluginCatalogService {
  _EmptyCatalogService() : super(pluginRootResolver: () async => '');

  @override
  Future<List<PluginCatalogItem>> scan() async {
    return const <PluginCatalogItem>[];
  }
}

class _StubProcessService extends PluginProcessService {
  _StubProcessService();
}

class _BlockingProcessService extends PluginProcessService {
  _BlockingProcessService();

  @override
  Future<PluginSession> start({
    required PluginCatalogItem plugin,
    required String pythonExecutable,
    required String runtimeRoot,
  }) async {
    return Completer<PluginSession>().future;
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

class _StubRuntimeLocator extends PluginRuntimeLocator {
  _StubRuntimeLocator()
    : super(
        executablePath: r'C:\ZYKJ_MES\mes_client.exe',
        environment: const {},
      );
}

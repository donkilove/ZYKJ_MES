import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';
import 'package:mes_client/features/plugin_host/models/plugin_session.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/presentation/widgets/plugin_host_workspace.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('插件工作区在父级重建时复用当前 WebView 子树', (tester) async {
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

    var buildCount = 0;
    StateSetter? rebuildHost;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildHost = setState;
            return Scaffold(
              body: PluginHostWorkspace(
                controller: controller,
                webviewBuilder: (entryUrl) {
                  buildCount += 1;
                  return Text('WEBVIEW:$entryUrl');
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(buildCount, 1);

    rebuildHost!.call(() {});
    await tester.pumpAndSettle();

    expect(buildCount, 1);
  });

  testWidgets('插件会话重建后即使地址不变也会替换 WebView 子树', (tester) async {
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

    var initCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return PluginHostWorkspace(
                controller: controller,
                webviewBuilder: (entryUrl) {
                  return _TrackedWebview(
                    label: 'WEBVIEW:$entryUrl',
                    onInit: () {
                      initCount += 1;
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(initCount, 1);

    controller.debugInjectSession(
      PluginSession(
        pluginId: 'serial_assistant',
        process: null,
        pid: 789,
        entryUrl: Uri.parse('http://127.0.0.1:43125/'),
        heartbeatUrl: Uri.parse('http://127.0.0.1:43125/__heartbeat__'),
      ),
    );
    await tester.pumpAndSettle();

    expect(initCount, 2);
  });
}

class _TrackedWebview extends StatefulWidget {
  const _TrackedWebview({required this.label, required this.onInit});

  final String label;
  final VoidCallback onInit;

  @override
  State<_TrackedWebview> createState() => _TrackedWebviewState();
}

class _TrackedWebviewState extends State<_TrackedWebview> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return Text(widget.label);
  }
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
          pythonVersion: '3.12',
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

  @override
  String resolvePythonExecutable() =>
      r'C:\ZYKJ_MES\plugins\runtime\python312\python.exe';

  @override
  String resolvePluginRoot() => r'C:\ZYKJ_MES\plugins';

  @override
  bool fileExists(String path) => true;

  @override
  bool dirExists(String path) => true;
}

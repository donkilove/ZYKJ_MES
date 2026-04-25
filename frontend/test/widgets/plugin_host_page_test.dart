import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_host_view_state.dart';
import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';
import 'package:mes_client/features/plugin_host/models/plugin_session.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_page.dart';
import 'package:mes_client/features/plugin_host/presentation/widgets/plugin_host_workspace.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';

void main() {
  testWidgets('插件中心会渲染列表与空工作区', (tester) async {
    final runtimeEnv = _createRuntimeEnvironment();
    addTearDown(runtimeEnv.dispose);
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(
        runtimeRoot: runtimeEnv.runtimeRoot.path,
        pluginRoot: runtimeEnv.pluginRoot.path,
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
    await _pumpForCatalogLoad(tester);

    expect(find.text('插件中心'), findsOneWidget);
    expect(find.text('串口助手'), findsOneWidget);
    expect(find.text('选择一个插件以打开工作区'), findsOneWidget);
  });

  testWidgets('插件列表为空时会提示检查插件目录', (tester) async {
    final runtimeEnv = _createRuntimeEnvironment();
    addTearDown(runtimeEnv.dispose);
    final controller = PluginHostController(
      catalogService: _EmptyCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(
        runtimeRoot: runtimeEnv.runtimeRoot.path,
        pluginRoot: runtimeEnv.pluginRoot.path,
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
    await _pumpForCatalogLoad(tester);

    expect(find.text('未发现插件，请检查插件目录。'), findsOneWidget);
  });

  testWidgets('启动中状态会渲染宿主启动面板', (tester) async {
    final runtimeEnv = _createRuntimeEnvironment();
    addTearDown(runtimeEnv.dispose);
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(
        runtimeRoot: runtimeEnv.runtimeRoot.path,
        pluginRoot: runtimeEnv.pluginRoot.path,
      ),
    );
    controller.debugSetViewState(
      const PluginHostViewState(
        phase: PluginHostPhase.starting,
        focusedPluginId: 'serial_assistant',
        statusTitle: '正在启动串口助手',
        statusMessage: '宿主正在拉起插件进程并等待页面就绪',
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
    await _pumpForCatalogLoad(tester);

    expect(find.text('正在启动串口助手'), findsOneWidget);
    expect(find.textContaining('等待页面就绪'), findsOneWidget);
  });

  testWidgets('异常状态会渲染宿主错误面板', (tester) async {
    final runtimeEnv = _createRuntimeEnvironment();
    addTearDown(runtimeEnv.dispose);
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(
        runtimeRoot: runtimeEnv.runtimeRoot.path,
        pluginRoot: runtimeEnv.pluginRoot.path,
      ),
    );
    controller.debugSetViewState(
      const PluginHostViewState(
        phase: PluginHostPhase.failed,
        focusedPluginId: 'serial_assistant',
        statusTitle: '串口助手启动失败',
        statusMessage: '宿主未能完成插件启动。',
        errorMessage: 'ready timeout',
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
    await _pumpForCatalogLoad(tester);

    expect(find.text('串口助手启动失败'), findsOneWidget);
    expect(find.textContaining('ready timeout'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重试'), findsOneWidget);
  });

  testWidgets('宿主插件根目录缺失时工作区直接展示插件目录缺失', (tester) async {
    final runtimeEnv = _createRuntimeEnvironment();
    addTearDown(runtimeEnv.dispose);
    final processService = _CountingProcessService();
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: processService,
      runtimeLocator: _StubRuntimeLocator(
        runtimeRoot: runtimeEnv.runtimeRoot.path,
        pluginRoot: _missingPath('plugin_root'),
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
    await _pumpForCatalogLoad(tester);
    await controller.openPlugin('serial_assistant');
    await _pumpForAction(tester);

    expect(find.text('串口助手启动失败'), findsOneWidget);
    expect(find.text('插件目录缺失'), findsOneWidget);
    expect(processService.startCount, 0);
  });

  testWidgets('Python 运行时缺失时工作区直接展示宿主错误文案', (tester) async {
    final runtimeEnv = _createRuntimeEnvironment();
    addTearDown(runtimeEnv.dispose);
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(
        runtimeRoot: _missingPath('runtime'),
        pluginRoot: runtimeEnv.pluginRoot.path,
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
    await _pumpForCatalogLoad(tester);
    await controller.openPlugin('serial_assistant');
    await _pumpForAction(tester);

    expect(find.text('串口助手启动失败'), findsOneWidget);
    expect(find.text('Python 运行时缺失'), findsOneWidget);
  });

  testWidgets('工作区在存在活动会话时会显示内嵌区域与宿主工具条', (tester) async {
    final runtimeEnv = _createRuntimeEnvironment();
    addTearDown(runtimeEnv.dispose);
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(
        runtimeRoot: runtimeEnv.runtimeRoot.path,
        pluginRoot: runtimeEnv.pluginRoot.path,
      ),
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
    await _pumpForCatalogLoad(tester);

    expect(find.text('WEBVIEW:http://127.0.0.1:43125/'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '关闭插件'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重启插件'), findsOneWidget);
  });

  testWidgets('父级重建时不会重复执行活动插件的 webviewBuilder', (tester) async {
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(
        runtimeRoot: Directory.systemTemp.path,
        pluginRoot: Directory.systemTemp.path,
      ),
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
    StateSetter? triggerParentRebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            triggerParentRebuild = setState;
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

    expect(buildCount, 1);

    triggerParentRebuild!.call(() {});
    await tester.pump();

    expect(buildCount, 1);
  });

  testWidgets('插件会话变化时即使地址相同也会重建 WebView 子树', (tester) async {
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(
        runtimeRoot: Directory.systemTemp.path,
        pluginRoot: Directory.systemTemp.path,
      ),
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
    await tester.pump();

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

class _StubRuntimeLocator extends PluginRuntimeLocator {
  _StubRuntimeLocator({required this.runtimeRoot, required this.pluginRoot})
    : super(
        executablePath: r'C:\ZYKJ_MES\mes_client.exe',
        environment: const {},
      );

  final String runtimeRoot;
  final String pluginRoot;

  @override
  String resolvePythonExecutable() => '$runtimeRoot\\python.exe';

  @override
  String resolvePluginRoot() => pluginRoot;

  @override
  bool fileExists(String path) => File(path).existsSync();

  @override
  bool dirExists(String path) => Directory(path).existsSync();
}

String _missingPath(String suffix) {
  return '${Directory.systemTemp.path}\\missing_${suffix}_${DateTime.now().microsecondsSinceEpoch}';
}

class _RuntimeEnvironment {
  _RuntimeEnvironment(this.pluginRoot, this.runtimeRoot);

  final Directory pluginRoot;
  final Directory runtimeRoot;

  void dispose() {
    if (pluginRoot.existsSync()) {
      pluginRoot.deleteSync(recursive: true);
    }
    if (runtimeRoot.existsSync()) {
      runtimeRoot.deleteSync(recursive: true);
    }
  }
}

_RuntimeEnvironment _createRuntimeEnvironment() {
  final pluginRoot = Directory.systemTemp.createTempSync('plugin_root_');
  final runtimeRoot = Directory.systemTemp.createTempSync('plugin_runtime_');
  final pythonExecutable = File('${runtimeRoot.path}\\python.exe');
  pythonExecutable.createSync();
  return _RuntimeEnvironment(pluginRoot, runtimeRoot);
}

Future<void> _pumpForCatalogLoad(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _pumpForAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

# Python 插件宿主 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Flutter Windows 主程序增加“内嵌独立 Python 插件应用”的宿主能力，让宿主只负责扫描、启动、承载与生命周期管理，插件自带 UI、逻辑与第三方依赖。

**Architecture:** 以新建 `plugin_host` 特性模块承接插件扫描、运行时定位、进程启动、`ready` 协议、心跳与宿主 UI。主壳通过新增 utility 入口打开插件中心；插件中心左侧展示插件列表，右侧使用独立 WebView 容器打开插件返回的 `entry_url`，所有第三方依赖由插件目录下的 `vendor/` 自带并通过宿主注入 `PYTHONPATH`。

**Tech Stack:** Flutter、Dart、`flutter_test`、`shared_preferences`、`http`、`path`、`webview_all ^1.0.3`、Python 3.14 embeddable runtime、`pytest`、`pyserial==3.5`

---

## 文件结构

### 需要创建的文件

- `frontend/lib/features/plugin_host/models/plugin_manifest.dart`
  - 插件 `manifest` 结构、生命周期参数与运行时声明。
- `frontend/lib/features/plugin_host/models/plugin_catalog_item.dart`
  - 扫描结果、状态、错误信息与目录信息。
- `frontend/lib/features/plugin_host/models/plugin_session.dart`
  - 宿主级运行会话、`entry_url`、心跳地址与进程句柄。
- `frontend/lib/features/plugin_host/services/plugin_catalog_service.dart`
  - 扫描插件目录、读取和校验 `manifest.json`。
- `frontend/lib/features/plugin_host/services/plugin_runtime_locator.dart`
  - 解析 `bundled` / `external_managed` 解释器路径与插件根目录。
- `frontend/lib/features/plugin_host/services/plugin_process_service.dart`
  - 启动插件、注入环境变量、解析 `ready`、执行心跳和停止进程。
- `frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart`
  - 宿主页状态机，管理插件目录、会话和操作按钮。
- `frontend/lib/features/plugin_host/presentation/plugin_host_page.dart`
  - 插件中心壳层页面。
- `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_sidebar.dart`
  - 左侧插件列表与状态区。
- `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart`
  - 右侧工作区、空态、异常态与宿主工具条。
- `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_webview_panel.dart`
  - 唯一直接依赖 WebView 包的封装层。
- `frontend/test/services/plugin_catalog_service_test.dart`
- `frontend/test/services/plugin_runtime_locator_test.dart`
- `frontend/test/services/plugin_process_service_test.dart`
- `frontend/test/widgets/plugin_host_page_test.dart`
- `plugins/serial_assistant/manifest.json`
- `plugins/serial_assistant/launcher.py`
- `plugins/serial_assistant/app/serial_bridge.py`
- `plugins/serial_assistant/app/server.py`
- `plugins/serial_assistant/web/index.html`
- `plugins/serial_assistant/web/app.js`
- `plugins/serial_assistant/requirements-dev.txt`
- `plugins/serial_assistant/tests/test_serial_bridge.py`
- `tools/plugin_tools/vendor_plugin_deps.ps1`
- `evidence/2026-04-24_Python插件宿主实施.md`
- `evidence/verification_20260424_python_plugin_host.md`

### 需要修改的文件

- `frontend/pubspec.yaml`
  - 增加 WebView 依赖。
- `frontend/lib/features/shell/presentation/main_shell_state.dart`
  - 新增 `plugin_host` utility code。
- `frontend/lib/features/shell/presentation/main_shell_controller.dart`
  - 增加打开插件中心入口。
- `frontend/lib/features/shell/presentation/main_shell_page.dart`
  - 注入 `PluginHostController` 并透传到注册表。
- `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
  - 为 `plugin_host` utility code 返回插件中心页面。
- `frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart`
  - 新增“插件中心”入口。
- `frontend/test/widgets/main_shell_page_registry_test.dart`
- `frontend/test/widgets/main_shell_page_test.dart`

### 计划内不改动的文件

- 后端 `backend/` 模块
- 现有消息、用户、生产等业务模块代码
- `frontend/windows/runner/*.cpp`
  - 第一版先不碰原生窗口嵌入

## Task 1: 插件目录扫描与 Manifest 校验

**Files:**
- Create: `frontend/lib/features/plugin_host/models/plugin_manifest.dart`
- Create: `frontend/lib/features/plugin_host/models/plugin_catalog_item.dart`
- Create: `frontend/lib/features/plugin_host/services/plugin_catalog_service.dart`
- Test: `frontend/test/services/plugin_catalog_service_test.dart`

- [ ] **Step 1: 先写扫描服务失败测试**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('scan 会读取合法 manifest 并返回 ready 状态', () async {
    final root = await Directory.systemTemp.createTemp('mes_plugin_scan_');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final pluginDir = Directory(p.join(root.path, 'serial_assistant'))
      ..createSync(recursive: true);
    await File(p.join(pluginDir.path, 'manifest.json')).writeAsString(
      jsonEncode({
        'id': 'serial_assistant',
        'name': '串口助手',
        'version': '0.1.0',
        'entry': {'type': 'python', 'script': 'launcher.py'},
        'ui': {'type': 'web', 'mode': 'embedded'},
        'runtime': {'python': '3.14', 'arch': 'win_amd64'},
        'dependencies': {
          'mode': 'plugin_local',
          'paths': ['vendor', 'app'],
        },
        'permissions': ['serial'],
        'lifecycle': {
          'startup_timeout_sec': 15,
          'heartbeat_interval_sec': 5,
        },
      }),
    );

    final service = PluginCatalogService(
      pluginRootResolver: () async => root.path,
    );

    final items = await service.scan();

    expect(items, hasLength(1));
    expect(items.single.manifest.id, 'serial_assistant');
    expect(items.single.status.name, 'ready');
  });
}
```

- [ ] **Step 2: 运行测试确认它先失败**

Run: `flutter test test/services/plugin_catalog_service_test.dart -r expanded`

Expected: FAIL，提示 `PluginCatalogService`、`PluginCatalogItem` 或 `PluginManifest` 尚不存在。

- [ ] **Step 3: 写出最小可用的 Manifest 与扫描服务实现**

```dart
enum PluginCatalogItemStatus { ready, invalid }

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.entryScript,
    required this.pythonVersion,
    required this.arch,
    required this.dependencyPaths,
    required this.permissions,
    required this.startupTimeout,
    required this.heartbeatInterval,
  });

  final String id;
  final String name;
  final String version;
  final String entryScript;
  final String pythonVersion;
  final String arch;
  final List<String> dependencyPaths;
  final List<String> permissions;
  final Duration startupTimeout;
  final Duration heartbeatInterval;

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final entry = json['entry'] as Map<String, dynamic>;
    final runtime = json['runtime'] as Map<String, dynamic>;
    final dependencies = json['dependencies'] as Map<String, dynamic>;
    final lifecycle = json['lifecycle'] as Map<String, dynamic>;
    return PluginManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      entryScript: entry['script'] as String,
      pythonVersion: runtime['python'] as String,
      arch: runtime['arch'] as String,
      dependencyPaths: (dependencies['paths'] as List<dynamic>)
          .cast<String>(),
      permissions: (json['permissions'] as List<dynamic>).cast<String>(),
      startupTimeout: Duration(
        seconds: lifecycle['startup_timeout_sec'] as int,
      ),
      heartbeatInterval: Duration(
        seconds: lifecycle['heartbeat_interval_sec'] as int,
      ),
    );
  }
}

class PluginCatalogItem {
  const PluginCatalogItem({
    required this.directory,
    required this.manifest,
    required this.status,
    this.errorMessage,
  });

  final Directory directory;
  final PluginManifest manifest;
  final PluginCatalogItemStatus status;
  final String? errorMessage;
}

class PluginCatalogService {
  PluginCatalogService({required this.pluginRootResolver});

  final Future<String> Function() pluginRootResolver;

  Future<List<PluginCatalogItem>> scan() async {
    final rootPath = await pluginRootResolver();
    final root = Directory(rootPath);
    if (!await root.exists()) {
      return const <PluginCatalogItem>[];
    }

    final result = <PluginCatalogItem>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) {
        continue;
      }
      final manifestFile = File(p.join(entity.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        continue;
      }
      final payload = jsonDecode(await manifestFile.readAsString())
          as Map<String, dynamic>;
      final manifest = PluginManifest.fromJson(payload);
      result.add(
        PluginCatalogItem(
          directory: entity,
          manifest: manifest,
          status: PluginCatalogItemStatus.ready,
        ),
      );
    }
    result.sort((a, b) => a.manifest.name.compareTo(b.manifest.name));
    return result;
  }
}
```

- [ ] **Step 4: 再加一个非法 manifest 测试并跑通**

```dart
test('scan 遇到缺失 script 的 manifest 时返回 invalid 状态', () async {
  final root = await Directory.systemTemp.createTemp('mes_plugin_invalid_');
  addTearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  final pluginDir = Directory('${root.path}/broken_plugin')
    ..createSync(recursive: true);
  await File('${pluginDir.path}/manifest.json').writeAsString(
    jsonEncode({
      'id': 'broken_plugin',
      'name': '损坏插件',
      'version': '0.1.0',
      'entry': {'type': 'python'},
      'ui': {'type': 'web', 'mode': 'embedded'},
      'runtime': {'python': '3.14', 'arch': 'win_amd64'},
      'dependencies': {'mode': 'plugin_local', 'paths': []},
      'permissions': [],
      'lifecycle': {'startup_timeout_sec': 15, 'heartbeat_interval_sec': 5},
    }),
  );

  final service = PluginCatalogService(
    pluginRootResolver: () async => root.path,
  );

  final items = await service.scan();
  expect(items.single.status, PluginCatalogItemStatus.invalid);
  expect(items.single.errorMessage, contains('entry.script'));
});
```

- [ ] **Step 5: 运行扫描服务测试确认通过**

Run: `flutter test test/services/plugin_catalog_service_test.dart -r expanded`

Expected: PASS，合法 manifest 返回 `ready`，非法 manifest 返回 `invalid`。

- [ ] **Step 6: 提交扫描与 manifest 基础能力**

```bash
git add frontend/lib/features/plugin_host/models/plugin_manifest.dart frontend/lib/features/plugin_host/models/plugin_catalog_item.dart frontend/lib/features/plugin_host/services/plugin_catalog_service.dart frontend/test/services/plugin_catalog_service_test.dart
git commit -m "新增插件扫描与清单校验基础能力"
```

## Task 2: 解释器定位与插件根目录解析

**Files:**
- Create: `frontend/lib/features/plugin_host/services/plugin_runtime_locator.dart`
- Test: `frontend/test/services/plugin_runtime_locator_test.dart`

- [ ] **Step 1: 先写运行时定位失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';

void main() {
  test('resolvePythonExecutable 优先使用环境变量指定的外部运行时', () {
    final locator = PluginRuntimeLocator(
      executablePath: r'C:\ZYKJ_MES\mes_client.exe',
      environment: const {
        'MES_PYTHON_RUNTIME_DIR': r'D:\MES_RUNTIME\python',
      },
    );

    expect(
      locator.resolvePythonExecutable(),
      r'D:\MES_RUNTIME\python\python.exe',
    );
  });

  test('resolvePluginRoot 在无环境变量时回退到可执行文件旁的 plugins 目录', () {
    final locator = PluginRuntimeLocator(
      executablePath: r'C:\ZYKJ_MES\mes_client.exe',
      environment: const {},
    );

    expect(
      locator.resolvePluginRoot(),
      r'C:\ZYKJ_MES\plugins',
    );
  });
}
```

- [ ] **Step 2: 运行测试确认它先失败**

Run: `flutter test test/services/plugin_runtime_locator_test.dart -r expanded`

Expected: FAIL，提示 `PluginRuntimeLocator` 尚不存在。

- [ ] **Step 3: 写出运行时与插件根目录解析器**

```dart
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
    final externalRoot = environment['MES_PYTHON_RUNTIME_DIR']?.trim();
    if (externalRoot != null && externalRoot.isNotEmpty) {
      return p.join(externalRoot, 'python.exe');
    }
    final executableDir = p.dirname(executablePath);
    return p.join(executableDir, 'runtime', 'python', 'python.exe');
  }

  String resolvePluginRoot() {
    final externalRoot = environment['MES_PLUGIN_ROOT']?.trim();
    if (externalRoot != null && externalRoot.isNotEmpty) {
      return externalRoot;
    }
    return p.join(p.dirname(executablePath), 'plugins');
  }
}
```

- [ ] **Step 4: 运行定位测试确认通过**

Run: `flutter test test/services/plugin_runtime_locator_test.dart -r expanded`

Expected: PASS，环境变量优先级与默认路径回退都符合预期。

- [ ] **Step 5: 提交运行时定位器**

```bash
git add frontend/lib/features/plugin_host/services/plugin_runtime_locator.dart frontend/test/services/plugin_runtime_locator_test.dart
git commit -m "新增插件解释器与目录定位器"
```

## Task 3: 进程启动、环境注入与 Ready 握手

**Files:**
- Create: `frontend/lib/features/plugin_host/models/plugin_session.dart`
- Create: `frontend/lib/features/plugin_host/services/plugin_process_service.dart`
- Test: `frontend/test/services/plugin_process_service_test.dart`

- [ ] **Step 1: 先写进程服务失败测试**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';

void main() {
  test('start 会注入 PYTHONPATH 并解析 ready 消息', () async {
    final process = _FakeProcess.ready(
      '{"event":"ready","pid":456,"entry_url":"http://127.0.0.1:43125/","heartbeat_url":"http://127.0.0.1:43125/__heartbeat__"}',
    );
    Map<String, String>? capturedEnvironment;

    final service = PluginProcessService(
      processStarter: (executable, arguments,
          {workingDirectory, environment}) async {
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
          startupTimeout: Duration(seconds: 15),
          heartbeatInterval: Duration(seconds: 5),
        ),
        status: PluginCatalogItemStatus.ready,
      ),
      pythonExecutable: r'C:\runtime\python\python.exe',
      runtimeRoot: r'C:\runtime\python',
    );

    expect(capturedEnvironment!['PYTHONPATH'], contains('vendor'));
    expect(session.entryUrl.toString(), 'http://127.0.0.1:43125/');
    expect(session.pid, 456);
  });
}

class _FakeProcess implements Process {
  _FakeProcess.ready(String line)
    : _stdoutController = Stream<List<int>>.value(utf8.encode('$line\n'));

  final Stream<List<int>> _stdoutController;

  @override
  int get pid => 456;

  @override
  Stream<List<int>> get stdout => _stdoutController;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);

  @override
  Future<int> get exitCode async => 0;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}
```

- [ ] **Step 2: 运行测试确认它先失败**

Run: `flutter test test/services/plugin_process_service_test.dart -r expanded`

Expected: FAIL，提示 `PluginProcessService`、`PluginSession` 或 `start` 尚不存在。

- [ ] **Step 3: 实现会话模型与进程服务**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:path/path.dart' as p;

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
  }) : processStarter = processStarter ?? Process.start,
       heartbeatClient = heartbeatClient ??
           ((heartbeatUrl) async {
             final response = await http.get(heartbeatUrl);
             return response.statusCode == 200;
           }),
       killProcess = killProcess ?? ((process) => process.kill());

  final ProcessStarter processStarter;
  final Future<bool> Function(Uri heartbeatUrl) heartbeatClient;
  final bool Function(Process process) killProcess;

  Future<PluginSession> start({
    required PluginCatalogItem plugin,
    required String pythonExecutable,
    required String runtimeRoot,
  }) async {
    final environment = <String, String>{
      'PYTHONHOME': runtimeRoot,
      'PYTHONPATH': plugin.manifest.dependencyPaths
          .map((path) => p.join(plugin.directory.path, path))
          .join(';'),
      'MES_PLUGIN_ID': plugin.manifest.id,
      'MES_PLUGIN_DIR': plugin.directory.path,
      'MES_RUNTIME_DIR': runtimeRoot,
      'MES_HOST_SESSION_ID': DateTime.now().microsecondsSinceEpoch.toString(),
    };

    final process = await processStarter(
      pythonExecutable,
      [p.join(plugin.directory.path, plugin.manifest.entryScript)],
      workingDirectory: plugin.directory.path,
      environment: environment,
    );

    final line = await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((value) => value.contains('"event":"ready"'));
    final payload = jsonDecode(line) as Map<String, dynamic>;

    return PluginSession(
      pluginId: plugin.manifest.id,
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
```

- [ ] **Step 4: 再补心跳与停止测试**

```dart
test('ping 在 heartbeat 返回 200 时为 true，stop 会结束进程', () async {
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
    processStarter: (a, b, {workingDirectory, environment}) async => process,
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
```

- [ ] **Step 5: 跑进程服务测试确认通过**

Run: `flutter test test/services/plugin_process_service_test.dart -r expanded`

Expected: PASS，能够解析 `ready`、注入 `PYTHONPATH`、执行心跳与停止。

- [ ] **Step 6: 提交进程服务与 Ready 协议**

```bash
git add frontend/lib/features/plugin_host/models/plugin_session.dart frontend/lib/features/plugin_host/services/plugin_process_service.dart frontend/test/services/plugin_process_service_test.dart
git commit -m "新增插件进程启动与就绪协议能力"
```

## Task 4: 主壳插件中心入口与宿主页面骨架

**Files:**
- Create: `frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart`
- Create: `frontend/lib/features/plugin_host/presentation/plugin_host_page.dart`
- Create: `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_sidebar.dart`
- Create: `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_state.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_controller.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
- Modify: `frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart`
- Test: `frontend/test/widgets/plugin_host_page_test.dart`
- Test: `frontend/test/widgets/main_shell_page_registry_test.dart`
- Test: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 先写插件中心页失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/models/plugin_catalog_item.dart';
import 'package:mes_client/features/plugin_host/models/plugin_manifest.dart';
import 'package:mes_client/features/plugin_host/services/plugin_catalog_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_process_service.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_controller.dart';
import 'package:mes_client/features/plugin_host/presentation/plugin_host_page.dart';

void main() {
  testWidgets('插件中心会渲染列表与空工作区', (tester) async {
    final controller = PluginHostController(
      catalogService: _StubCatalogService(),
      processService: _StubProcessService(),
      runtimeLocator: _StubRuntimeLocator(),
    );
    controller.debugReplacePlugins([
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
          startupTimeout: Duration(seconds: 15),
          heartbeatInterval: Duration(seconds: 5),
        ),
        status: PluginCatalogItemStatus.ready,
      ),
    ]);

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
  _StubCatalogService() : super(pluginRootResolver: () async => Directory.systemTemp.path);
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
```

- [ ] **Step 2: 再写主壳注册表失败测试**

```dart
test('插件中心 utility code 会返回 PluginHostPage', () {
  const registry = MainShellPageRegistry();
  final pluginHostController = PluginHostController(
    catalogService: _StubCatalogService(),
    processService: _StubProcessService(),
    runtimeLocator: _StubRuntimeLocator(),
  );

  final widget = registry.build(
    pageCode: pluginHostUtilityCode,
    session: testSession,
    state: MainShellViewState(
      currentUser: buildCurrentUser(),
      authzSnapshot: buildSnapshot(),
      catalog: buildCatalog(),
      tabCodesByParent: const {},
      menus: const [
        MainShellMenuItem(code: 'home', title: '首页', icon: Icons.home),
      ],
      selectedPageCode: 'home',
    ),
    onLogout: () {},
    onRefreshShellData: ({bool loadCatalog = true}) async {},
    onNavigateToPageTarget:
        ({required pageCode, String? tabCode, String? routePayloadJson}) {},
    onVisibilityConfigSaved: () {},
    onUnreadCountChanged: (_) {},
    messageService: MessageService(testSession),
    softwareSettingsController: SoftwareSettingsController.memory(),
    timeSyncController: _buildTimeSyncController(
      SoftwareSettingsController.memory(),
    ),
    pluginHostController: pluginHostController,
  );

  expect(widget, isA<PluginHostPage>());
});
```

- [ ] **Step 3: 运行 widget 测试确认先失败**

Run: `flutter test test/widgets/plugin_host_page_test.dart test/widgets/main_shell_page_registry_test.dart test/widgets/main_shell_page_test.dart -r expanded`

Expected: FAIL，提示 `PluginHostPage`、`PluginHostController`、`pluginHostUtilityCode` 尚不存在。

- [ ] **Step 4: 实现插件中心骨架与主壳入口**

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

const String pluginHostUtilityCode = 'plugin_host';

class PluginHostController extends ChangeNotifier {
  PluginHostController({
    required PluginCatalogService catalogService,
    required PluginProcessService processService,
    required PluginRuntimeLocator runtimeLocator,
  }) : _catalogService = catalogService,
       _processService = processService,
       _runtimeLocator = runtimeLocator;

  final PluginCatalogService _catalogService;
  final PluginProcessService _processService;
  final PluginRuntimeLocator _runtimeLocator;

  List<PluginCatalogItem> _plugins = const [];
  List<PluginCatalogItem> get plugins => _plugins;
  final Map<String, PluginSession> _sessions = <String, PluginSession>{};
  String? _activePluginId;
  PluginSession? get activeSession => _activePluginId == null
      ? null
      : _sessions[_activePluginId];

  Future<void> loadCatalog() async {
    _plugins = await _catalogService.scan();
    notifyListeners();
  }

  void debugReplacePlugins(List<PluginCatalogItem> items) {
    _plugins = items;
    notifyListeners();
  }

  void debugInjectSession(PluginSession session) {
    _sessions[session.pluginId] = session;
    _activePluginId = session.pluginId;
    notifyListeners();
  }

  Future<void> openPlugin(String pluginId) async {
    final plugin = _plugins.firstWhere((item) => item.manifest.id == pluginId);
    final pythonExecutable = _runtimeLocator.resolvePythonExecutable();
    final runtimeRoot = p.dirname(pythonExecutable);
    final session = await _processService.start(
      plugin: plugin,
      pythonExecutable: pythonExecutable,
      runtimeRoot: runtimeRoot,
    );
    _sessions[pluginId] = session;
    _activePluginId = pluginId;
    notifyListeners();
  }

  Future<void> closePlugin(String pluginId) async {
    final session = _sessions.remove(pluginId);
    if (session != null) {
      await _processService.stop(session);
    }
    if (_activePluginId == pluginId) {
      _activePluginId = _sessions.keys.firstOrNull;
    }
    notifyListeners();
  }

  Future<void> restartPlugin(String pluginId) async {
    await closePlugin(pluginId);
    await openPlugin(pluginId);
  }
}

class PluginHostPage extends StatefulWidget {
  const PluginHostPage({super.key, required this.controller});

  final PluginHostController controller;

  @override
  State<PluginHostPage> createState() => _PluginHostPageState();
}

class _PluginHostPageState extends State<PluginHostPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.loadCatalog());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Row(
          children: [
            SizedBox(
              width: 280,
              child: PluginHostSidebar(controller: widget.controller),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: PluginHostWorkspace(controller: widget.controller),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 5: 在主壳里接入插件中心入口**

```dart
void openPluginHost() {
  if (_state.activeUtilityCode == pluginHostUtilityCode) {
    return;
  }
  _setState(_state.copyWith(activeUtilityCode: pluginHostUtilityCode));
}
```

```dart
ListTile(
  key: const ValueKey('main-shell-entry-plugin-host'),
  selected: state.activeUtilityCode == pluginHostUtilityCode,
  leading: const Icon(Icons.extension_rounded),
  title: sidebarCollapsed ? null : const Text('插件中心'),
  onTap: onOpenPluginHost,
),
```

- [ ] **Step 6: 跑主壳与插件中心 widget 测试确认通过**

Run: `flutter test test/widgets/plugin_host_page_test.dart test/widgets/main_shell_page_registry_test.dart test/widgets/main_shell_page_test.dart -r expanded`

Expected: PASS，主壳能打开“插件中心”，插件中心壳层能渲染列表与空工作区。

- [ ] **Step 7: 提交插件中心骨架**

```bash
git add frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart frontend/lib/features/plugin_host/presentation/plugin_host_page.dart frontend/lib/features/plugin_host/presentation/widgets/plugin_host_sidebar.dart frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart frontend/lib/features/shell/presentation/main_shell_state.dart frontend/lib/features/shell/presentation/main_shell_controller.dart frontend/lib/features/shell/presentation/main_shell_page.dart frontend/lib/features/shell/presentation/main_shell_page_registry.dart frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart frontend/test/widgets/plugin_host_page_test.dart frontend/test/widgets/main_shell_page_registry_test.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "主壳新增插件中心入口与页面骨架"
```

## Task 5: WebView 承载层与宿主工作区动作

**Files:**
- Modify: `frontend/pubspec.yaml`
- Create: `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_webview_panel.dart`
- Modify: `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart`
- Modify: `frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart`
- Test: `frontend/test/widgets/plugin_host_page_test.dart`

- [ ] **Step 1: 先写工作区失败测试，要求运行中会话显示内嵌页面**

```dart
testWidgets('工作区在存在活动会话时会调用 webviewBuilder 打开 entryUrl', (tester) async {
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
          webviewBuilder: (url) => Text('WEBVIEW:$url'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('WEBVIEW:http://127.0.0.1:43125/'), findsOneWidget);
  expect(find.widgetWithText(TextButton, '关闭插件'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试确认它先失败**

Run: `flutter test test/widgets/plugin_host_page_test.dart -r expanded`

Expected: FAIL，`PluginHostPage` 还没有 `webviewBuilder` 注入，工作区也不会显示会话。

- [ ] **Step 3: 增加 WebView 依赖并跑 `pub get`**

```yaml
dependencies:
  webview_all: ^1.0.3
```

Run: `flutter pub get`

Expected: 成功拉取 `webview_all 1.0.3` 及其 Windows 适配依赖。

- [ ] **Step 4: 写唯一依赖 WebView 包的封装层**

```dart
import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

class PluginHostWebviewPanel extends StatefulWidget {
  const PluginHostWebviewPanel({super.key, required this.entryUrl});

  final Uri entryUrl;

  @override
  State<PluginHostWebviewPanel> createState() => _PluginHostWebviewPanelState();
}

class _PluginHostWebviewPanelState extends State<PluginHostWebviewPanel> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(widget.entryUrl);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
```

- [ ] **Step 5: 在工作区接入宿主工具条与 WebView Builder 注入**

```dart
class PluginHostPage extends StatefulWidget {
  const PluginHostPage({
    super.key,
    required this.controller,
    this.webviewBuilder,
  });

  final PluginHostController controller;
  final Widget Function(Uri entryUrl)? webviewBuilder;
}

Widget _buildActiveSession(BuildContext context, PluginSession session) {
  final content =
      widget.webviewBuilder?.call(session.entryUrl) ??
      PluginHostWebviewPanel(entryUrl: session.entryUrl);
  return Column(
    children: [
      Row(
        children: [
          Text(session.pluginId),
          const Spacer(),
          TextButton(
            onPressed: () => widget.controller.restartPlugin(session.pluginId),
            child: const Text('重启插件'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => widget.controller.closePlugin(session.pluginId),
            child: const Text('关闭插件'),
          ),
        ],
      ),
      const Divider(height: 1),
      Expanded(child: content),
    ],
  );
}
```

- [ ] **Step 6: 运行插件中心 widget 测试确认通过**

Run: `flutter test test/widgets/plugin_host_page_test.dart -r expanded`

Expected: PASS，活动会话能显示注入的 WebView 占位，宿主工具条动作可见。

- [ ] **Step 7: 提交 WebView 承载层**

```bash
git add frontend/pubspec.yaml frontend/lib/features/plugin_host/presentation/widgets/plugin_host_webview_panel.dart frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart frontend/test/widgets/plugin_host_page_test.dart
git commit -m "插件中心接入内嵌 WebView 工作区"
```

## Task 6: 串口助手 PoC 插件与依赖自带模式

**Files:**
- Create: `plugins/serial_assistant/manifest.json`
- Create: `plugins/serial_assistant/launcher.py`
- Create: `plugins/serial_assistant/app/serial_bridge.py`
- Create: `plugins/serial_assistant/app/server.py`
- Create: `plugins/serial_assistant/web/index.html`
- Create: `plugins/serial_assistant/web/app.js`
- Create: `plugins/serial_assistant/requirements-dev.txt`
- Create: `plugins/serial_assistant/tests/test_serial_bridge.py`
- Create: `tools/plugin_tools/vendor_plugin_deps.ps1`

- [ ] **Step 1: 先写串口桥接失败测试，要求 `loop://` 能完成一次收发**

```python
from plugins.serial_assistant.app.serial_bridge import SerialBridge


def test_loopback_round_trip():
    bridge = SerialBridge()
    handle = bridge.open("loop://", 115200)
    try:
        bridge.send(handle, "ping")
        payload = bridge.read(handle, timeout=1.0)
        assert payload == "ping"
    finally:
        bridge.close(handle)
```

- [ ] **Step 2: 运行测试确认它先失败**

Run: `python -m pytest plugins/serial_assistant/tests/test_serial_bridge.py -q`

Expected: FAIL，提示 `plugins.serial_assistant.app.serial_bridge` 或 `SerialBridge` 不存在。

- [ ] **Step 3: 写出插件 manifest、桥接层与启动脚本**

```json
{
  "id": "serial_assistant",
  "name": "串口助手",
  "version": "0.1.0",
  "entry": {
    "type": "python",
    "script": "launcher.py"
  },
  "ui": {
    "type": "web",
    "mode": "embedded"
  },
  "runtime": {
    "python": "3.14",
    "arch": "win_amd64"
  },
  "dependencies": {
    "mode": "plugin_local",
    "paths": ["vendor", "app"]
  },
  "permissions": ["serial", "filesystem"],
  "lifecycle": {
    "startup_timeout_sec": 15,
    "heartbeat_interval_sec": 5
  }
}
```

```python
# plugins/serial_assistant/app/serial_bridge.py
import time
import uuid

import serial


class SerialBridge:
    def __init__(self) -> None:
        self._connections: dict[str, serial.SerialBase] = {}

    def open(self, port: str, baudrate: int) -> str:
        handle = uuid.uuid4().hex
        connection = serial.serial_for_url(port, baudrate=baudrate, timeout=0.1)
        self._connections[handle] = connection
        return handle

    def send(self, handle: str, payload: str) -> None:
        self._connections[handle].write(payload.encode("utf-8"))

    def read(self, handle: str, timeout: float = 1.0) -> str:
        deadline = time.time() + timeout
        buffer = bytearray()
        connection = self._connections[handle]
        while time.time() < deadline:
            chunk = connection.read(connection.in_waiting or 1)
            if chunk:
                buffer.extend(chunk)
                return buffer.decode("utf-8", errors="replace")
        return ""

    def close(self, handle: str) -> None:
        connection = self._connections.pop(handle, None)
        if connection is not None:
          connection.close()
```

```python
# plugins/serial_assistant/launcher.py
import json
import os
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR / "vendor"))
sys.path.insert(0, str(BASE_DIR / "app"))

from app.server import start_server  # noqa: E402


if __name__ == "__main__":
    port, heartbeat_path = start_server(base_dir=BASE_DIR)
    print(
        json.dumps(
            {
                "event": "ready",
                "pid": os.getpid(),
                "entry_url": f"http://127.0.0.1:{port}/index.html",
                "heartbeat_url": f"http://127.0.0.1:{port}{heartbeat_path}",
            }
        ),
        flush=True,
    )
    sys.stdin.read()
```

- [ ] **Step 4: 写出最小 Web UI、HTTP 服务与依赖 vendoring 脚本**

```python
# plugins/serial_assistant/app/server.py
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
import json
import socket


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def start_server(base_dir: Path) -> tuple[int, str]:
    web_root = base_dir / "web"
    heartbeat_path = "/__heartbeat__"

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(web_root), **kwargs)

        def do_GET(self):
            if self.path == heartbeat_path:
                payload = json.dumps({"status": "ok"}).encode("utf-8")
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
                return
            return super().do_GET()

    port = _free_port()
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    Thread(target=server.serve_forever, daemon=True).start()
    return port, heartbeat_path
```

```html
<!-- plugins/serial_assistant/web/index.html -->
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <title>串口助手</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
  </head>
  <body>
    <main>
      <h1>串口助手</h1>
      <label>端口 <input id="port" value="COM1" /></label>
      <label>波特率 <input id="baudrate" value="115200" /></label>
      <button id="open">打开</button>
      <button id="close">关闭</button>
      <textarea id="sendText"></textarea>
      <button id="send">发送</button>
      <pre id="receiveLog"></pre>
    </main>
    <script src="./app.js"></script>
  </body>
</html>
```

```powershell
# tools/plugin_tools/vendor_plugin_deps.ps1
param(
  [string]$PluginName = 'serial_assistant'
)

$pluginDir = Join-Path $PSScriptRoot "..\..\plugins\$PluginName"
$vendorDir = Join-Path $pluginDir "vendor"
$requirements = Join-Path $pluginDir "requirements-dev.txt"

if (Test-Path $vendorDir) {
  Remove-Item -Recurse -Force $vendorDir
}

python -m pip install --no-compile --target $vendorDir -r $requirements
```

- [ ] **Step 5: 先 vendoring 再跑 Python 测试**

Run: `powershell -ExecutionPolicy Bypass -File tools/plugin_tools/vendor_plugin_deps.ps1`

Expected: `plugins/serial_assistant/vendor/serial/` 目录生成成功。

Run: `python -m pytest plugins/serial_assistant/tests/test_serial_bridge.py -q`

Expected: PASS，`loop://` 下完成一次真实打开、发送、接收、关闭。

- [ ] **Step 6: 提交串口助手 PoC 插件**

```bash
git add plugins/serial_assistant tools/plugin_tools/vendor_plugin_deps.ps1
git commit -m "新增串口助手插件原型"
```

## Task 7: 全链路验证与 Evidence 收口

**Files:**
- Create: `evidence/2026-04-24_Python插件宿主实施.md`
- Create: `evidence/verification_20260424_python_plugin_host.md`
- Test: `frontend/test/services/plugin_catalog_service_test.dart`
- Test: `frontend/test/services/plugin_runtime_locator_test.dart`
- Test: `frontend/test/services/plugin_process_service_test.dart`
- Test: `frontend/test/widgets/plugin_host_page_test.dart`
- Test: `frontend/test/widgets/main_shell_page_registry_test.dart`
- Test: `frontend/test/widgets/main_shell_page_test.dart`
- Test: `plugins/serial_assistant/tests/test_serial_bridge.py`

- [ ] **Step 1: 运行 Flutter 目标测试集**

Run: `flutter test test/services/plugin_catalog_service_test.dart test/services/plugin_runtime_locator_test.dart test/services/plugin_process_service_test.dart test/widgets/plugin_host_page_test.dart test/widgets/main_shell_page_registry_test.dart test/widgets/main_shell_page_test.dart -r expanded`

Expected: PASS，扫描、运行时、进程握手、主壳入口和插件中心 UI 全部通过。

- [ ] **Step 2: 运行 Python 插件测试**

Run: `python -m pytest plugins/serial_assistant/tests/test_serial_bridge.py -q`

Expected: PASS，串口桥接的 loopback 测试通过。

- [ ] **Step 3: 跑静态检查**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 4: 做一次人工联调**

Run: `python start_frontend.py`

Expected:
- 主程序能正常启动到登录后主壳。
- 左侧出现“插件中心”入口。
- 打开“插件中心”后能看到“串口助手”。
- 点击“打开”后，右侧工作区能加载插件页面。
- 关闭插件后，宿主状态从“运行中”回到“已停止”或“未启动”。

- [ ] **Step 5: 新增实施留痕**

```md
# Python 插件宿主实施

- 日期：2026-04-24
- 执行人：Codex
- 当前状态：已完成

## 已完成项

1. 宿主扫描插件目录与 manifest 校验
2. 解释器定位与环境注入
3. `ready` / 心跳 / 停止协议
4. 主壳插件中心入口与工作区
5. 串口助手 PoC

## 迁移说明

- 无迁移，直接替换
```

- [ ] **Step 6: 新增验证留痕**

```md
# Python 插件宿主验证

- 执行日期：2026-04-24
- 当前状态：已通过

## 验证结果

1. `flutter test` 目标集：通过
2. `python -m pytest plugins/serial_assistant/tests/test_serial_bridge.py -q`：通过
3. `flutter analyze`：通过
4. 人工联调：通过
```

- [ ] **Step 7: 提交验证与留痕**

```bash
git add evidence/2026-04-24_Python插件宿主实施.md evidence/verification_20260424_python_plugin_host.md
git commit -m "补齐 Python 插件宿主验证留痕"
```

## Self-Review

### Spec coverage

- 宿主/插件边界：Task 1、Task 3
- 解释器由宿主提供、依赖由插件自带：Task 2、Task 6
- 主壳插件中心 UI：Task 4
- 内嵌 WebView 工作区：Task 5
- 串口助手 PoC：Task 6
- 测试与 evidence：Task 7

### Placeholder scan

- 本计划未使用 `TODO`、`TBD`、`稍后补`、`后续处理` 等占位表述。
- 每个任务都包含具体文件、测试代码、运行命令、最小实现和提交口径。

### Type consistency

- 宿主常量统一使用 `pluginHostUtilityCode`
- 插件清单统一使用 `PluginManifest` 与 `PluginCatalogItem`
- 运行会话统一使用 `PluginSession`
- WebView 注入统一使用 `webviewBuilder`
- 解释器与插件目录解析统一由 `PluginRuntimeLocator` 提供

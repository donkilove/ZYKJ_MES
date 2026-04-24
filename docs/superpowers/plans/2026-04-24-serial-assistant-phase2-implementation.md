# 串口助手第二阶段 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打通插件中心对 `serial_assistant` 的直接打开链路，让右侧工作区先显示宿主启动/异常面板，再切入真实插件页面，并把串口助手第一页重构为连接区、发送区、接收日志区的完整闭环。

**Architecture:** 宿主侧先补“单插件单实例 + 启动中/运行中/异常”状态机，再把左侧插件列表从“选中”改成“直接打开”。插件侧保持 Python 本地服务模型不变，只整理 `web/index.html` 与 `web/app.js`，让首页围绕“连接、发送、读取、关闭”形成稳定工作台。

**Tech Stack:** Flutter、Dart、`flutter_test`、`webview_all`、Python、`pytest`、`pyserial`

---

## 文件结构

### 需要创建的文件

- `frontend/lib/features/plugin_host/models/plugin_host_view_state.dart`
  - 承载宿主工作区状态：空态、启动中、运行中、异常，以及对应的文案和错误信息。
- `frontend/test/services/plugin_host_controller_test.dart`
  - 用 fake catalog / fake process service 验证单实例、直接打开、失败回退和重启链路。
- `evidence/2026-04-24_串口助手第二阶段实施.md`
- `evidence/verification_20260424_serial_assistant_phase2.md`

### 需要修改的文件

- `frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart`
  - 维护 `PluginHostViewState`，把点击插件项从“选中”改为“直接打开”。
- `frontend/lib/features/plugin_host/presentation/plugin_host_page.dart`
  - 触发 catalog 加载，保持页面装配，不直接堆逻辑。
- `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_sidebar.dart`
  - 左侧列表项点击后直接调用打开动作，并显示运行状态徽标。
- `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart`
  - 去掉当前简介卡主路径，接入启动面板、异常面板和运行态 WebView。
- `frontend/lib/features/plugin_host/services/plugin_process_service.dart`
  - 增加 `ready` 超时、失败消息收集和宿主可消费的异常信息。
- `frontend/lib/features/plugin_host/models/plugin_session.dart`
  - 如需补充 `startedAt`、`statusText` 等运行态附加信息，在这里收口。
- `frontend/test/widgets/plugin_host_page_test.dart`
- `frontend/test/services/plugin_process_service_test.dart`
- `plugins/serial_assistant/web/index.html`
- `plugins/serial_assistant/web/app.js`
- `plugins/serial_assistant/app/server.py`
- `plugins/serial_assistant/app/serial_bridge.py`
- `plugins/serial_assistant/tests/test_serial_bridge.py`

### 计划内不修改的文件

- `frontend/lib/features/shell/` 主壳业务模块本体
- `backend/`
- 其他插件目录

## Task 1: 为宿主补齐进程失败与超时语义

**Files:**
- Modify: `frontend/lib/features/plugin_host/services/plugin_process_service.dart`
- Modify: `frontend/test/services/plugin_process_service_test.dart`

- [ ] **Step 1: 先写失败测试，要求 `ready` 超时会抛出明确异常**

```dart
test('start 在超时未收到 ready 时抛出 TimeoutException', () async {
  final process = _FakeProcess(
    stdoutLines: const <String>[],
    pid: 456,
  );
  final service = PluginProcessService(
    processStarter: (executable, arguments, {workingDirectory, environment}) async {
      return process;
    },
    heartbeatClient: (_) async => true,
    readyTimeout: const Duration(milliseconds: 50),
  );

  await expectLater(
    () => service.start(
      plugin: _buildReadyPluginItem(),
      pythonExecutable: r'C:\runtime\python\python.exe',
      runtimeRoot: r'C:\runtime\python',
    ),
    throwsA(isA<TimeoutException>()),
  );
});
```

- [ ] **Step 2: 再写失败测试，要求 `ready` 非法 JSON 会抛出 `FormatException`**

```dart
test('start 遇到非法 ready 消息时抛出 FormatException', () async {
  final process = _FakeProcess(
    stdoutLines: const <String>['not-json'],
    pid: 456,
  );
  final service = PluginProcessService(
    processStarter: (executable, arguments, {workingDirectory, environment}) async {
      return process;
    },
    heartbeatClient: (_) async => true,
    readyTimeout: const Duration(milliseconds: 50),
  );

  await expectLater(
    () => service.start(
      plugin: _buildReadyPluginItem(),
      pythonExecutable: r'C:\runtime\python\python.exe',
      runtimeRoot: r'C:\runtime\python',
    ),
    throwsA(isA<FormatException>()),
  );
});
```

- [ ] **Step 3: 运行测试确认它们先失败**

Run: `flutter test test/services/plugin_process_service_test.dart -r expanded`

Expected: FAIL，当前 `PluginProcessService` 没有 `readyTimeout`，也不会对 `ready` 超时与非法 JSON 给出明确异常。

- [ ] **Step 4: 用最小实现补齐超时与格式错误处理**

```dart
class PluginProcessService {
  PluginProcessService({
    ProcessStarter? processStarter,
    Future<bool> Function(Uri heartbeatUrl)? heartbeatClient,
    bool Function(Process process)? killProcess,
    Duration readyTimeout = const Duration(seconds: 15),
  }) : processStarter = processStarter ?? Process.start,
       heartbeatClient = heartbeatClient ?? _defaultHeartbeatClient,
       killProcess = killProcess ?? ((process) => process.kill()),
       readyTimeout = readyTimeout;

  final Duration readyTimeout;

  Future<PluginSession> start({
    required PluginCatalogItem plugin,
    required String pythonExecutable,
    required String runtimeRoot,
  }) async {
    final process = await processStarter(...);
    final readyLineFuture = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((line) => line.contains('"event":"ready"'));
    final readyLine = await readyLineFuture.timeout(readyTimeout);
    final payload = jsonDecode(readyLine) as Map<String, dynamic>;
    if (payload['entry_url'] is! String || payload['pid'] is! int) {
      throw const FormatException('ready 消息缺少 entry_url 或 pid');
    }
    return PluginSession(...);
  }
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/services/plugin_process_service_test.dart -r expanded`

Expected: PASS，既有 `ready` 解析测试通过，新增超时与非法消息测试通过。

- [ ] **Step 6: 提交这一批进程服务收口**

```bash
git add frontend/lib/features/plugin_host/services/plugin_process_service.dart frontend/test/services/plugin_process_service_test.dart
git commit -m "补齐插件进程就绪超时与失败语义"
```

## Task 2: 宿主控制器改为“直接打开 + 单实例状态机”

**Files:**
- Create: `frontend/lib/features/plugin_host/models/plugin_host_view_state.dart`
- Modify: `frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart`
- Create: `frontend/test/services/plugin_host_controller_test.dart`

- [ ] **Step 1: 先写控制器失败测试，要求点击插件项后进入启动中**

```dart
test('openPlugin 会把视图状态切到 starting', () async {
  final controller = PluginHostController(
    catalogService: _StubCatalogService.withPlugin(),
    processService: _BlockingProcessService(),
    runtimeLocator: _StubRuntimeLocator(),
  );
  await controller.loadCatalog();

  unawaited(controller.openPlugin('serial_assistant'));
  await Future<void>.delayed(Duration.zero);

  expect(controller.viewState.phase, PluginHostPhase.starting);
  expect(controller.viewState.focusedPluginId, 'serial_assistant');
});
```

- [ ] **Step 2: 再写控制器失败测试，要求单实例下再次点击不重复启动**

```dart
test('已运行时再次打开同一插件不会重复拉起进程', () async {
  final processService = _CountingProcessService();
  final controller = PluginHostController(
    catalogService: _StubCatalogService.withPlugin(),
    processService: processService,
    runtimeLocator: _StubRuntimeLocator(),
  );
  await controller.loadCatalog();

  await controller.debugInjectRunningSession(
    const PluginSession(
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
```

- [ ] **Step 3: 运行测试确认先失败**

Run: `flutter test test/services/plugin_host_controller_test.dart -r expanded`

Expected: FAIL，当前控制器没有 `viewState`、没有 `openPlugin` 主路径，也没有单实例约束。

- [ ] **Step 4: 引入最小视图状态模型**

```dart
enum PluginHostPhase { idle, starting, running, failed }

class PluginHostViewState {
  const PluginHostViewState({
    this.phase = PluginHostPhase.idle,
    this.focusedPluginId,
    this.statusTitle = '选择一个插件以打开工作区',
    this.statusMessage = '',
    this.errorMessage,
  });

  final PluginHostPhase phase;
  final String? focusedPluginId;
  final String statusTitle;
  final String statusMessage;
  final String? errorMessage;

  PluginHostViewState copyWith({
    PluginHostPhase? phase,
    Object? focusedPluginId = _unset,
    String? statusTitle,
    String? statusMessage,
    Object? errorMessage = _unset,
  }) { ... }
}
```

- [ ] **Step 5: 用最小实现把控制器切到直接打开**

```dart
Future<void> openPlugin(String pluginId) async {
  final running = _sessions[pluginId];
  if (running != null) {
    _selectedPluginId = pluginId;
    _viewState = _viewState.copyWith(
      phase: PluginHostPhase.running,
      focusedPluginId: pluginId,
      statusTitle: '串口助手运行中',
      statusMessage: '插件页面已就绪。',
      errorMessage: null,
    );
    notifyListeners();
    return;
  }

  _selectedPluginId = pluginId;
  _viewState = _viewState.copyWith(
    phase: PluginHostPhase.starting,
    focusedPluginId: pluginId,
    statusTitle: '正在启动串口助手',
    statusMessage: '宿主正在拉起插件进程并等待页面就绪。',
    errorMessage: null,
  );
  notifyListeners();

  try {
    final started = await _processService.start(...);
    _sessions[pluginId] = started;
    _viewState = _viewState.copyWith(
      phase: PluginHostPhase.running,
      focusedPluginId: pluginId,
      statusTitle: '串口助手运行中',
      statusMessage: '插件页面已就绪。',
      errorMessage: null,
    );
  } catch (error) {
    _viewState = _viewState.copyWith(
      phase: PluginHostPhase.failed,
      focusedPluginId: pluginId,
      statusTitle: '串口助手启动失败',
      statusMessage: '宿主未能完成插件启动。',
      errorMessage: error.toString(),
    );
  }
  notifyListeners();
}
```

- [ ] **Step 6: 运行控制器测试确认通过**

Run: `flutter test test/services/plugin_host_controller_test.dart -r expanded`

Expected: PASS，点击后进入启动中，已运行时不会重复启动。

- [ ] **Step 7: 提交宿主状态机**

```bash
git add frontend/lib/features/plugin_host/models/plugin_host_view_state.dart frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart frontend/test/services/plugin_host_controller_test.dart
git commit -m "插件宿主切换为直接打开单实例状态机"
```

## Task 3: 工作区改为启动面板 / 异常面板 / 运行态三态

**Files:**
- Modify: `frontend/lib/features/plugin_host/presentation/plugin_host_page.dart`
- Modify: `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_sidebar.dart`
- Modify: `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart`
- Modify: `frontend/test/widgets/plugin_host_page_test.dart`

- [ ] **Step 1: 先写失败测试，要求点击左侧后工作区进入启动面板**

```dart
testWidgets('点击左侧插件项后工作区显示启动面板', (tester) async {
  final controller = PluginHostController(
    catalogService: _StubCatalogService.withPlugin(),
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
```

- [ ] **Step 2: 再写失败测试，要求启动失败时显示异常面板**

```dart
testWidgets('启动失败时工作区显示异常面板', (tester) async {
  final controller = PluginHostController(
    catalogService: _StubCatalogService.withPlugin(),
    processService: _FailingProcessService('ready timeout'),
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
```

- [ ] **Step 3: 运行测试确认先失败**

Run: `flutter test test/widgets/plugin_host_page_test.dart -r expanded`

Expected: FAIL，当前左侧点击还是“选中”语义，工作区没有启动/异常面板。

- [ ] **Step 4: 在 sidebar 把点击动作改为 `openPlugin`**

```dart
ListTile(
  selected: pluginId != null && pluginId == controller.selectedPluginId,
  leading: Icon(_statusIconFor(item, controller.viewState)),
  title: Text(manifest?.name ?? '无效插件'),
  subtitle: Text(_statusTextFor(item, controller.viewState)),
  onTap: pluginId == null ? null : () => controller.openPlugin(pluginId),
)
```

- [ ] **Step 5: 在 workspace 渲染三态面板**

```dart
if (controller.viewState.phase == PluginHostPhase.starting) {
  return _PluginHostStatusPanel(
    title: controller.viewState.statusTitle,
    message: controller.viewState.statusMessage,
    actions: [
      TextButton(onPressed: () => controller.cancelStarting(), child: const Text('取消启动')),
      TextButton(onPressed: () => controller.openPluginLog(), child: const Text('查看日志')),
    ],
  );
}

if (controller.viewState.phase == PluginHostPhase.failed) {
  return _PluginHostStatusPanel(
    title: controller.viewState.statusTitle,
    message: controller.viewState.errorMessage ?? controller.viewState.statusMessage,
    actions: [
      TextButton(onPressed: () => controller.retryFocusedPlugin(), child: const Text('重试')),
      TextButton(onPressed: () => controller.openPluginLog(), child: const Text('查看日志')),
      TextButton(onPressed: () => controller.closeFocusedPlugin(), child: const Text('关闭插件')),
    ],
  );
}
```

- [ ] **Step 6: 运行 widget 测试确认通过**

Run: `flutter test test/widgets/plugin_host_page_test.dart -r expanded`

Expected: PASS，点击左侧即进入启动中，失败时进入异常态，已有运行态测试仍通过。

- [ ] **Step 7: 提交宿主工作区三态**

```bash
git add frontend/lib/features/plugin_host/presentation/plugin_host_page.dart frontend/lib/features/plugin_host/presentation/widgets/plugin_host_sidebar.dart frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart frontend/test/widgets/plugin_host_page_test.dart
git commit -m "插件中心工作区补齐启动与异常面板"
```

## Task 4: 串口助手第一页重构为三段工作台

**Files:**
- Modify: `plugins/serial_assistant/web/index.html`
- Modify: `plugins/serial_assistant/web/app.js`
- Modify: `plugins/serial_assistant/app/server.py`
- Modify: `plugins/serial_assistant/app/serial_bridge.py`
- Modify: `plugins/serial_assistant/tests/test_serial_bridge.py`

- [ ] **Step 1: 先写 Python 失败测试，要求 `list_ports()` 至少带上 `loop://`**

```python
from plugins.serial_assistant.app.serial_bridge import SerialBridge


def test_list_ports_contains_loopback_entry():
    bridge = SerialBridge()
    ports = bridge.list_ports()
    assert any(item["port"] == "loop://" for item in ports)
```

- [ ] **Step 2: 再写失败测试，要求关闭后再次读取会报错而不是假成功**

```python
import pytest

from plugins.serial_assistant.app.serial_bridge import SerialBridge


def test_read_after_close_raises_key_error():
    bridge = SerialBridge()
    handle = bridge.open("loop://", 115200)
    bridge.close(handle)
    with pytest.raises(KeyError):
        bridge.read(handle, timeout=0.1)
```

- [ ] **Step 3: 运行测试确认先失败**

Run: `python -m pytest plugins/serial_assistant/tests/test_serial_bridge.py -q`

Expected: FAIL，当前 `list_ports()` 与关闭后读取的行为还没按第二阶段要求锁定。

- [ ] **Step 4: 保持 Python 接口最小稳定**

```python
class SerialBridge:
    def list_ports(self) -> list[dict[str, str]]:
        ports = [
            {
                "port": port.device,
                "description": port.description,
            }
            for port in list_ports.comports()
        ]
        if not any(item["port"] == "loop://" for item in ports):
            ports.append({"port": "loop://", "description": "内置回环测试端口"})
        return ports
```

```python
if parsed.path == "/api/open":
    handle = bridge.open(...)
    self._send_json(HTTPStatus.OK, {"handle": handle, "status": "opened"})
    return
```

- [ ] **Step 5: 把 Web 页面改成三段工作台**

```html
<section class="panel">
  <h1>串口助手</h1>
  <p id="status">状态：未连接</p>
  <div class="row">
    <label>端口<select id="port"></select></label>
    <label>波特率<input id="baudrate" value="115200" /></label>
  </div>
  <div class="row">
    <button id="refreshPorts">刷新端口</button>
    <button id="open">打开</button>
    <button id="close" class="secondary">关闭</button>
  </div>
</section>

<section class="panel">
  <label style="flex: 1 1 100%;">发送内容<textarea id="sendText"></textarea></label>
  <div class="row">
    <button id="send">发送</button>
    <button id="clearSend" class="secondary">清空发送框</button>
  </div>
</section>

<section class="panel">
  <h2>接收日志</h2>
  <div class="row">
    <button id="read" class="secondary">读取一次</button>
    <button id="clearLog" class="secondary">清空日志</button>
  </div>
  <pre id="receiveLog"></pre>
</section>
```

```javascript
document.getElementById("clearSend").addEventListener("click", () => {
  sendText.value = "";
});

document.getElementById("clearLog").addEventListener("click", () => {
  receiveLog.textContent = "";
});
```

- [ ] **Step 6: 运行 Python 测试确认通过**

Run: `python -m pytest plugins/serial_assistant/tests/test_serial_bridge.py -q`

Expected: PASS，`loop://` 仍能完成回环收发，列表与关闭后行为符合预期。

- [ ] **Step 7: 提交串口助手第一页重构**

```bash
git add plugins/serial_assistant/web/index.html plugins/serial_assistant/web/app.js plugins/serial_assistant/app/server.py plugins/serial_assistant/app/serial_bridge.py plugins/serial_assistant/tests/test_serial_bridge.py
git commit -m "串口助手重构为三段工作台首页"
```

## Task 5: 全链路验证与 evidence 收口

**Files:**
- Create: `evidence/2026-04-24_串口助手第二阶段实施.md`
- Create: `evidence/verification_20260424_serial_assistant_phase2.md`
- Test: `frontend/test/services/plugin_process_service_test.dart`
- Test: `frontend/test/services/plugin_host_controller_test.dart`
- Test: `frontend/test/widgets/plugin_host_page_test.dart`
- Test: `plugins/serial_assistant/tests/test_serial_bridge.py`

- [ ] **Step 1: 运行宿主侧目标测试集**

Run: `flutter test test/services/plugin_process_service_test.dart test/services/plugin_host_controller_test.dart test/widgets/plugin_host_page_test.dart -r expanded`

Expected: PASS，宿主进程超时语义、直接打开、单实例、启动/异常面板全部通过。

- [ ] **Step 2: 运行 Python 插件测试**

Run: `python -m pytest plugins/serial_assistant/tests/test_serial_bridge.py -q`

Expected: PASS，串口助手回环测试与列表/关闭行为测试全部通过。

- [ ] **Step 3: 跑静态检查**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 4: 做一次人工联调**

Run: `python start_frontend.py --skip-pub-get --skip-bootstrap-admin`

Expected:
- 打开插件中心后，点击左侧 `串口助手`
- 右侧先显示“正在启动串口助手”
- 随后自动切到真实插件页面
- 页面第一屏包含连接区、发送区、接收日志区
- 完成一次打开、发送、读取、关闭

- [ ] **Step 5: 新增实施留痕**

```md
# 串口助手第二阶段实施

- 日期：2026-04-24
- 执行人：Codex
- 当前状态：已完成

## 已完成项

1. 宿主改为直接打开插件
2. 宿主工作区补齐启动中 / 运行中 / 异常态
3. 串口助手第一页重构为三段工作台
4. 自动化验证与人工联调完成

## 迁移说明

- 无迁移，直接替换
```

- [ ] **Step 6: 新增验证留痕**

```md
# 串口助手第二阶段验证

- 执行日期：2026-04-24
- 当前状态：已通过

## 验证结果

1. 宿主 Flutter 目标测试：通过
2. Python 串口测试：通过
3. `flutter analyze`：通过
4. 人工联调：通过
```

- [ ] **Step 7: 提交验证与留痕**

```bash
git add evidence/2026-04-24_串口助手第二阶段实施.md evidence/verification_20260424_serial_assistant_phase2.md
git commit -m "补齐串口助手第二阶段验证留痕"
```

## Self-Review

### Spec coverage

- 宿主直接打开、单实例、状态流：Task 2、Task 3
- 启动面板 / 异常面板：Task 3
- 三段工作台：Task 4
- 真实串口闭环：Task 4、Task 5
- 测试与留痕：Task 5

### Placeholder scan

- 本计划未使用 `TODO`、`TBD`、`待补`、`实现细节略` 等占位表述。
- 每个任务都包含具体文件、测试代码、命令和提交口径。

### Type consistency

- 宿主状态统一使用 `PluginHostPhase`
- 宿主视图状态统一使用 `PluginHostViewState`
- 打开动作统一使用 `openPlugin`
- 关闭与重启统一使用 `closePlugin` / `restartPlugin`

# 插件系统

## 1. 插件运行时

### 嵌入式 Python 3.12

嵌入式 Python 解释器位于 `plugins/runtime/python312/`，版本为 Python 3.12（Windows amd64）。

关键文件：

| 文件 | 用途 |
|------|------|
| `python.exe` | 解释器可执行文件 |
| `python312.dll` | 核心动态库 |
| `python312.zip` | 标准库压缩包 |
| `python312._pth` | 模块搜索路径配置 |
| `*.pyd` | C 扩展模块（`_socket`, `_ssl`, `_sqlite3` 等） |
| `libcrypto-3.dll`, `libssl-3.dll` | OpenSSL 库 |
| `sqlite3.dll` | SQLite 库 |
| `vcruntime140.dll`, `vcruntime140_1.dll` | VC 运行时 |

### 运行时目录结构

```
plugins/
├── runtime/
│   └── python312/          # 嵌入式 Python 3.12 (36 个文件)
└── serial_assistant/       # 示例插件
```

## 2. Manifest 规范

每个插件根目录下需包含 `manifest.json`。以 `serial_assistant` 插件为例：

### 必填字段

| 字段 | 类型 | 说明 | 实际值 |
|------|------|------|--------|
| `id` | string | 插件唯一标识 | `"serial_assistant"` |
| `name` | string | 显示名称 | `"串口助手"` |
| `version` | string | 语义版本号 | `"0.1.0"` |
| `entry.type` | string | 入口类型 | `"python"` |
| `entry.script` | string | 启动脚本路径（相对插件根目录） | `"launcher.py"` |
| `runtime.python` | string | 要求的 Python 版本 | `"3.12"` |
| `runtime.arch` | string | 目标架构 | `"win_amd64"` |
| `dependencies.paths` | string[] | 插件本地依赖路径 | `["vendor", "app"]` |
| `permissions` | string[] | 权限声明 | `["serial", "filesystem"]` |
| `lifecycle.startup_timeout_sec` | int | 启动超时（秒） | `15` |
| `lifecycle.heartbeat_interval_sec` | int | 心跳间隔（秒） | `5` |

### 可选字段

| 字段 | 类型 | 说明 | 实际值 |
|------|------|------|--------|
| `ui.type` | string | UI 类型 | `"web"` |
| `ui.mode` | string | UI 嵌入模式 | `"embedded"` |
| `dependencies.mode` | string | 依赖模式 | `"plugin_local"` |

### 前端解析模型

Flutter 端通过 `PluginManifest.fromJson()`（`frontend/lib/features/plugin_host/models/plugin_manifest.dart:26`）解析，验证所有必填字段的完整性。解析后的模型包含：`id`, `name`, `version`, `entryScript`, `pythonVersion`, `arch`, `dependencyPaths`, `permissions`, `startupTimeoutSeconds`, `heartbeatIntervalSeconds`。

## 3. 插件生命周期

### 3.1 前端启动流程

1. 用户在 `PluginHostSidebar` 选择插件 → `PluginHostController.openPlugin(pluginId)` 被调用
2. `PluginHostController._prepareLaunchContext()` 校验插件目录、Python 运行时是否存在
3. 调用 `PluginProcessService.start()`（`frontend/lib/features/plugin_host/services/plugin_process_service.dart:37`）

### 3.2 进程拉起

`PluginProcessService.start()` 执行以下操作：

1. 构造环境变量：
   - `PYTHONHOME` → 嵌入式 Python 运行时根目录
   - `MES_PLUGIN_ID` → 插件 ID
   - `MES_PLUGIN_DIR` → 插件根目录
   - `MES_PLUGIN_VENDOR_DIR` → 插件 vendor 目录
   - `MES_PLUGIN_APP_DIR` → 插件 app 目录
   - `MES_RUNTIME_DIR` → 运行时目录
   - `MES_HOST_SESSION_ID` → 会话标识

2. 以 `python.exe` + `launcher.py` 启动子进程

3. 等待子进程 stdout 输出 `ready` 事件（超时时间 15 秒）

4. 解析 `ready` JSON，提取 `pid`, `entry_url`, `heartbeat_url`，构造 `PluginSession`

### 3.3 launcher.py 启动流程

`plugins/serial_assistant/launcher.py`：

1. 从环境变量读取 `MES_PLUGIN_DIR`, `MES_PLUGIN_VENDOR_DIR`, `MES_PLUGIN_APP_DIR`，加入 `sys.path`
2. 导入 `app.server.start_server`，调用后获得 `(port, heartbeat_path)`
3. 向 stdout 输出 JSON 格式的 `ready` 事件：`{"event": "ready", "pid": <pid>, "entry_url": "...", "heartbeat_url": "..."}`
4. 进入 `sys.stdin.read()` 阻塞等待，保持进程存活

### 3.4 app/server.py HTTP 服务

`start_server()` 函数（`plugins/serial_assistant/app/server.py:20`）：

1. 创建 `SerialBridge` 实例
2. 使用 `_find_free_port()` 在 `127.0.0.1` 上获取空闲端口
3. 实例化 `ThreadingHTTPServer`，在守护线程中启动 `serve_forever()`
4. 返回 `(port, heartbeat_path)` 给 launcher

内置 API 端点：

| 方法 | 路径 | 功能 |
|------|------|------|
| GET | `/__heartbeat__` | 心跳检测，返回 `{"status": "ok"}` |
| GET | `/api/ports` | 枚举可用串口 |
| GET | `/api/read?handle=...&timeout=...` | 读取串口数据 |
| POST | `/api/open` | 打开串口，body: `{"port", "baudrate"}` |
| POST | `/api/send` | 发送数据，body: `{"handle", "payload"}` |
| POST | `/api/close` | 关闭串口，body: `{"handle"}` |
| GET | `/*` | 静态文件服务，root 为 `web/` 目录 |

静态文件服务（`_serve_static`）仅允许访问 `web/` 目录下的文件，路径遍历尝试返回 404。

### 3.5 前端通信方式

插件进程通过本地 HTTP（`http://127.0.0.1:<port>`）提供服务，前端通过 `webview_all` 包创建的 WebView 加载 `entry_url`。WebView 内 JavaScript 通过 `fetch()` 调用插件 API。

## 4. serial_assistant 参考实现

### 4.1 串口桥接（SerialBridge）

类定义：`app/serial_bridge.py:17`

| 方法 | 说明 |
|------|------|
| `SerialBridge()` | 初始化，创建 `_connections: dict[str, serial.SerialBase]` |
| `list_ports()` | 通过 `serial.tools.list_ports.comports()` 枚举串口；额外添加 `loop://` 虚拟回环端口 |
| `open(port, baudrate)` | 使用 `serial.serial_for_url()` 打开端口，返回 UUID 句柄 |
| `send(handle, payload)` | 向指定连接写入 UTF-8 编码字符串 |
| `read(handle, timeout)` | 带超时的阻塞读取，以 `bytearray` 缓冲 |
| `close(handle)` | 关闭并清理连接 |

依赖 `pyserial` 库，位于 `vendor/` 目录。

### 4.2 Web UI

`web/` 目录包含两个文件：

- **`index.html`** — 纯 HTML + 内联 CSS：端口选择区、发送区、接收日志区
- **`app.js`** — 原生 JavaScript（无框架），核心函数：
  - `request(path, options)` — 封装 `fetch()` 调用
  - `loadPorts()` — 获取并渲染端口列表
  - `openPort()` / `closePort()` — 打开/关闭串口
  - `sendPayload()` — 发送文本数据
  - `readOnce()` — 单次读取
  - `appendLog(message)` — 带时间戳的日志追加

UI 通过 `fetch()` 调用同一源上的 `/api/*` 端点。

### 4.3 关键类名与方法汇总

| 文件 | 类/函数 | 说明 |
|------|---------|------|
| `launcher.py` | `__main__` | 入口：设置路径 → 启动服务 → 输出 ready |
| `app/server.py` | `start_server(base_dir)` | 启动 HTTP 服务，返回 `(port, heartbeat_path)` |
| `app/server.py` | `Handler._serve_static(request_path)` | 静态文件服务，仅限 `web/` 目录 |
| `app/serial_bridge.py` | `SerialBridge` | 串口连接管理 |
| `web/app.js` | `request()` | 封装 REST API 调用 |

## 5. 前端插件宿主

### 5.1 目录结构

```
frontend/lib/features/plugin_host/
├── models/
│   ├── plugin_catalog_item.dart    # 插件目录项（状态：ready / invalid）
│   ├── plugin_host_view_state.dart # 视图状态（idle / starting / running / failed）
│   ├── plugin_manifest.dart        # Manifest 解析模型
│   └── plugin_session.dart         # 运行中的插件会话（process, pid, entryUrl, heartbeatUrl）
├── presentation/
│   ├── plugin_host_controller.dart # 核心控制器（ChangeNotifier）
│   ├── plugin_host_page.dart       # 页面布局（侧边栏 + 工作区）
│   └── widgets/
│       ├── plugin_host_sidebar.dart        # 插件列表侧边栏
│       ├── plugin_host_webview_panel.dart  # WebView 面板
│       └── plugin_host_workspace.dart      # 工作区（状态面板 + 工具栏 + WebView）
└── services/
    ├── plugin_catalog_service.dart  # 扫描插件目录，解析 manifest
    ├── plugin_process_service.dart  # 启动/停止/心跳插件进程
    └── plugin_runtime_locator.dart  # 定位 Python 运行时和插件根目录
```

### 5.2 核心服务

**PluginCatalogService** (`plugin_catalog_service.dart:8`)：
- `scan()` 遍历插件根目录下所有包含 `manifest.json` 的子目录
- 成功解析 → `PluginCatalogItemStatus.ready`；失败 → `PluginCatalogItemStatus.invalid`
- 结果按插件名称排序

**PluginRuntimeLocator** (`plugin_runtime_locator.dart:5`)：
- `resolvePythonExecutable()`：优先使用环境变量 `MES_PYTHON_RUNTIME_DIR`，否则从仓库根目录 `plugins/runtime/python312/python.exe` 定位
- `resolvePluginRoot()`：优先使用环境变量 `MES_PLUGIN_ROOT`，否则通过 `_findRepoRoot()` 向上查找包含 `frontend/` 和 `plugins/` 子目录的目录

**PluginProcessService** (`plugin_process_service.dart:17`)：
- `start(plugin, pythonExecutable, runtimeRoot)`：构造环境变量 → 启动子进程 → 等待 ready → 返回 PluginSession
- `ping(session)`：通过 `heartbeatClient` 访问 `/__heartbeat__` 检测进程存活
- `stop(session)`：终止进程

### 5.3 视图状态

`PluginHostViewState` (`plugin_host_view_state.dart:5`) 定义四种阶段：

| 阶段 | 枚举值 | 说明 |
|------|--------|------|
| 空闲 | `PluginHostPhase.idle` | 未选中任何插件 |
| 启动中 | `PluginHostPhase.starting` | 正在拉起插件进程 |
| 运行中 | `PluginHostPhase.running` | 插件正常运行 |
| 失败 | `PluginHostPhase.failed` | 启动失败，可重试或关闭 |

### 5.4 Web UI 嵌入方式

使用 `webview_all` 包（Flutter），通过 `PluginHostWebviewPanel`（`plugin_host_webview_panel.dart:6`）实现：

- `WebViewController` + `WebViewWidget` 组合
- `JavaScriptMode.unrestricted`（允许 JS 执行）
- 传入 `entryUrl`（插件 ready 时返回的 `http://127.0.0.1:<port>/index.html`）
- 支持全屏模式（`PluginHostController.toggleFullscreen()`）

`PluginHostPage` 通过 `webviewBuilder` 回调注入 WebView 组件，布局为左侧 300px 侧边栏 + 右侧工作区（WebView 嵌入在 `MesSectionCard` 内）。

# 插件运行时目录重定向 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将插件宿主的 Python 运行时从 `frontend/build/.../runtime/python` 的临时推断改为仓库内固定的 `plugins/runtime/python312/python.exe`，并让 `serial_assistant` 在不依赖环境变量的情况下稳定启动。

**Architecture:** 宿主侧把“插件目录”和“解释器路径”都收敛为仓库内固定路径，只保留环境变量作为调试覆盖；仓库结构方面将 Python 3.12 embeddable runtime 直接纳入 `plugins/runtime/python312/`。最后补齐宿主错误提示与验证留痕，确保解释器缺失时不再冒出神秘 `ProcessException`。

**Tech Stack:** Flutter、Dart、`flutter_test`、Python 3.12.10 embeddable package、PowerShell、`pytest`

---

## 文件结构

### 需要创建的文件

- `backend/tests/test_start_frontend_script_unit.py`
  - 验证 `start_frontend.py` 构建的子进程环境会暴露固定插件目录与固定 Python 运行时目录。
- `plugins/runtime/python312/`
  - 直接提交 Python 3.12.10 Windows embeddable runtime 本体。
- `plugins/runtime/python312/README.md`
  - 说明目录来源、版本和后续维护口径。
- `evidence/2026-04-25_插件运行时目录重定向实施.md`
- `evidence/verification_20260425_plugin_runtime_redirection.md`

### 需要修改的文件

- `frontend/lib/features/plugin_host/services/plugin_runtime_locator.dart`
  - 固定解释器路径与插件根目录路径，废弃构建目录推断逻辑。
- `frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart`
  - 启动插件前显式检查解释器和插件目录是否存在，并输出明确错误文案。
- `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart`
  - 宿主错误面板接入“Python 运行时缺失 / 插件目录缺失”的明确提示。
- `frontend/test/services/plugin_runtime_locator_test.dart`
- `frontend/test/services/plugin_host_controller_test.dart`
- `frontend/test/widgets/plugin_host_page_test.dart`
- `start_frontend.py`
  - 把固定插件根目录和固定运行时目录注入前端启动环境。
- `.gitignore`
  - 确保 `plugins/runtime/python312/` 与插件 `vendor/` 不被误忽略，同时继续忽略缓存与日志。
- `README.md`
  - 补充统一插件根目录和 Python 3.12 运行时口径。

### 计划内不修改的文件

- `plugins/serial_assistant/` 业务逻辑与页面本身
- `frontend/lib/features/shell/` 主壳业务功能
- `backend/` 业务接口

## Task 1: 固定启动环境与运行时定位规则

**Files:**
- Create: `backend/tests/test_start_frontend_script_unit.py`
- Modify: `frontend/test/services/plugin_runtime_locator_test.dart`
- Modify: `frontend/lib/features/plugin_host/services/plugin_runtime_locator.dart`
- Modify: `start_frontend.py`

- [ ] **Step 1: 先写 `start_frontend.py` 的失败测试**

```python
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import start_frontend


def test_build_subprocess_env_injects_fixed_plugin_paths() -> None:
    env = start_frontend.build_subprocess_env()

    assert env["MES_PLUGIN_ROOT"] == str(REPO_ROOT / "plugins")
    assert env["MES_PYTHON_RUNTIME_DIR"] == str(
        REPO_ROOT / "plugins" / "runtime" / "python312"
    )
```
```

- [ ] **Step 2: 再写运行时定位失败测试，要求默认定位到仓库内固定解释器**

```dart
test('resolvePythonExecutable 默认定位到仓库内 python312', () {
  final locator = PluginRuntimeLocator(
    executablePath:
        r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend\build\windows\x64\runner\Debug\mes_client.exe',
    environment: const {},
    currentDirectory: r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend',
    directoryExists: (path) => true,
  );

  expect(
    locator.resolvePythonExecutable(),
    r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins\runtime\python312\python.exe',
  );
});
```

- [ ] **Step 3: 再写失败测试，要求不再回退到 build 目录 runtime**

```dart
test('resolvePythonExecutable 不再回退到 frontend build runtime 目录', () {
  final locator = PluginRuntimeLocator(
    executablePath:
        r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend\build\windows\x64\runner\Debug\mes_client.exe',
    environment: const {},
    currentDirectory: r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend',
    directoryExists: (path) =>
        path ==
        r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins\runtime\python312',
  );

  expect(
    locator.resolvePythonExecutable(),
    isNot(
      r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend\build\windows\x64\runner\Debug\runtime\python\python.exe',
    ),
  );
});
```

- [ ] **Step 4: 运行测试确认它们先失败**

Run: `python -m pytest backend/tests/test_start_frontend_script_unit.py -q`
Expected: FAIL，`MES_PYTHON_RUNTIME_DIR` 还没注入。

Run: `flutter test test/services/plugin_runtime_locator_test.dart -r expanded`
Expected: FAIL，运行时定位器还会从构建目录派生解释器路径。

- [ ] **Step 5: 用最小实现收紧启动环境与定位规则**

```python
# start_frontend.py
def build_subprocess_env() -> dict[str, str]:
    env = os.environ.copy()
    merged_no_proxy = _merge_no_proxy(env.get("NO_PROXY") or env.get("no_proxy"))
    env["NO_PROXY"] = merged_no_proxy
    env["no_proxy"] = merged_no_proxy
    env.setdefault("MES_PLUGIN_ROOT", str(ROOT_DIR / "plugins"))
    env.setdefault(
        "MES_PYTHON_RUNTIME_DIR",
        str(ROOT_DIR / "plugins" / "runtime" / "python312"),
    )
    return env
```

```dart
// plugin_runtime_locator.dart
String resolvePythonExecutable() {
  final externalRuntimeDir = environment['MES_PYTHON_RUNTIME_DIR']?.trim();
  if (externalRuntimeDir != null && externalRuntimeDir.isNotEmpty) {
    return p.join(externalRuntimeDir, 'python.exe');
  }
  return p.join(
    p.dirname(resolvePluginRoot()),
    'runtime',
    'python312',
    'python.exe',
  );
}

String resolvePluginRoot() {
  final externalPluginRoot = environment['MES_PLUGIN_ROOT']?.trim();
  if (externalPluginRoot != null && externalPluginRoot.isNotEmpty) {
    return externalPluginRoot;
  }
  // 只在 currentDirectory / executablePath 的祖先链里找 repo 根 plugins
  ...
}
```

- [ ] **Step 6: 运行测试确认通过**

Run: `python -m pytest backend/tests/test_start_frontend_script_unit.py -q`
Expected: PASS，两个固定路径都已注入。

Run: `flutter test test/services/plugin_runtime_locator_test.dart -r expanded`
Expected: PASS，定位器默认指向仓库内 `plugins/runtime/python312/python.exe`。

- [ ] **Step 7: 提交这一批运行时定位改动**

```bash
git add backend/tests/test_start_frontend_script_unit.py frontend/test/services/plugin_runtime_locator_test.dart frontend/lib/features/plugin_host/services/plugin_runtime_locator.dart start_frontend.py
git commit -m "收紧插件运行时定位到仓库内固定路径"
```

## Task 2: 将 Python 3.12 运行时直接放入仓库并收口忽略规则

**Files:**
- Create: `plugins/runtime/python312/README.md`
- Modify: `.gitignore`
- Modify: `README.md`
- Add binary contents under: `plugins/runtime/python312/`

- [ ] **Step 1: 先创建运行时目录说明文件**

```markdown
# Python 3.12 Runtime

- 来源：Python 3.12.10 Windows embeddable package (64-bit)
- 上游发布页：https://www.python.org/downloads/release/python-31210/
- 目录职责：仅承载插件宿主运行时，不承载插件业务代码或插件私有依赖
- 默认解释器路径：`plugins/runtime/python312/python.exe`
```
```

- [ ] **Step 2: 用精确命令下载并展开官方 embeddable runtime**

```powershell
$runtimeRoot = 'C:\Users\Donki\Desktop\ZYKJ_MES\plugins\runtime\python312'
$zipPath = Join-Path $runtimeRoot 'python-3.12.10-embed-amd64.zip'
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
curl.exe -L --output $zipPath 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip'
if ((Get-FileHash $zipPath -Algorithm MD5).Hash.ToLower() -ne 'fe8ef205f2e9c3ba44d0cf9954e1abd3') {
    throw 'python 3.12.10 embeddable package checksum mismatch'
}
Expand-Archive -LiteralPath $zipPath -DestinationPath $runtimeRoot -Force
Remove-Item $zipPath
```

Expected:
- `plugins/runtime/python312/python.exe`
- `plugins/runtime/python312/pythonw.exe`
- `plugins/runtime/python312/python312.dll`
- `plugins/runtime/python312/python312.zip`

- [ ] **Step 3: 调整 `.gitignore`，确保运行时不被忽略**

```gitignore
# Python caches and logs
__pycache__/
*.pyc
*.pyo
*.log

# Keep committed plugin runtime and vendored plugin deps
!plugins/runtime/
!plugins/runtime/python312/
!plugins/runtime/python312/**
!plugins/*/vendor/
!plugins/*/vendor/**
```

- [ ] **Step 4: 在 README 补统一口径**

```md
## 插件运行时

- 插件统一根目录：`plugins/`
- 仓库内固定解释器：`plugins/runtime/python312/python.exe`
- 后续 Python 插件默认基于该解释器开发与验证
- 插件私有依赖继续放在各插件目录的 `vendor/` 下
```

- [ ] **Step 5: 验证运行时目录已到位**

Run: `Test-Path 'C:\Users\Donki\Desktop\ZYKJ_MES\plugins\runtime\python312\python.exe'`
Expected: `True`

Run: `& 'C:\Users\Donki\Desktop\ZYKJ_MES\plugins\runtime\python312\python.exe' -c "import sys; print(sys.version)"`
Expected: 输出 `3.12.10`

- [ ] **Step 6: 提交运行时目录与忽略规则**

```bash
git add .gitignore README.md plugins/runtime/python312
git commit -m "提交仓库内固定 Python 3.12 运行时"
```

## Task 3: 宿主启动前显式检查目录与解释器缺失

**Files:**
- Modify: `frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart`
- Modify: `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart`
- Modify: `frontend/test/services/plugin_host_controller_test.dart`
- Modify: `frontend/test/widgets/plugin_host_page_test.dart`

- [ ] **Step 1: 先写控制器失败测试，要求解释器缺失时进入明确错误态**

```dart
test('解释器缺失时 viewState 显示 Python 运行时缺失', () async {
  final controller = PluginHostController(
    catalogService: _StubCatalogService.withPlugin(),
    processService: _CountingProcessService(),
    runtimeLocator: _StubRuntimeLocator(
      pythonExecutable: r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins\runtime\python312\python.exe',
      pluginRoot: r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins',
      fileExists: (path) => false,
      directoryExists: (path) => path.endsWith(r'\plugins'),
    ),
  );
  await controller.loadCatalog();

  await controller.openPlugin('serial_assistant');

  expect(controller.viewState.phase, PluginHostPhase.failed);
  expect(controller.viewState.statusTitle, '串口助手启动失败');
  expect(controller.viewState.errorMessage, contains('Python 运行时缺失'));
});
```

- [ ] **Step 2: 再写失败测试，要求插件目录缺失时进入明确错误态**

```dart
test('插件目录缺失时 viewState 显示插件目录缺失', () async {
  final controller = PluginHostController(
    catalogService: _StubCatalogService.withPlugin(),
    processService: _CountingProcessService(),
    runtimeLocator: _StubRuntimeLocator(
      pythonExecutable: r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins\runtime\python312\python.exe',
      pluginRoot: r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins',
      fileExists: (path) => path.endsWith(r'python.exe'),
      directoryExists: (path) => false,
    ),
  );
  await controller.loadCatalog();

  await controller.openPlugin('serial_assistant');

  expect(controller.viewState.phase, PluginHostPhase.failed);
  expect(controller.viewState.errorMessage, contains('插件目录缺失'));
});
```

- [ ] **Step 3: 运行测试确认先失败**

Run: `flutter test test/services/plugin_host_controller_test.dart test/widgets/plugin_host_page_test.dart -r expanded`
Expected: FAIL，当前控制器还不会在启动前显式校验目录和解释器，也没有明确错误文案。

- [ ] **Step 4: 给运行时定位器补存在性查询接口**

```dart
class PluginRuntimeLocator {
  bool fileExists(String path) => File(path).existsSync();
  bool dirExists(String path) => Directory(path).existsSync();
}
```

- [ ] **Step 5: 在控制器里先校验再启动**

```dart
Future<void> openPlugin(String pluginId) async {
  final pluginRoot = _runtimeLocator.resolvePluginRoot();
  if (!_runtimeLocator.dirExists(pluginRoot)) {
    _viewState = _viewState.copyWith(
      phase: PluginHostPhase.failed,
      focusedPluginId: pluginId,
      statusTitle: '${_displayNameFor(pluginId)}启动失败',
      statusMessage: '宿主未找到插件目录。',
      errorMessage: '插件目录缺失：$pluginRoot',
    );
    notifyListeners();
    return;
  }

  final pythonExecutable = _runtimeLocator.resolvePythonExecutable();
  if (!_runtimeLocator.fileExists(pythonExecutable)) {
    _viewState = _viewState.copyWith(
      phase: PluginHostPhase.failed,
      focusedPluginId: pluginId,
      statusTitle: '${_displayNameFor(pluginId)}启动失败',
      statusMessage: '宿主未找到 Python 运行时。',
      errorMessage: 'Python 运行时缺失：$pythonExecutable',
    );
    notifyListeners();
    return;
  }

  ...
}
```

- [ ] **Step 6: 在异常面板明确显示宿主错误文案**

```dart
if (viewState.phase == PluginHostPhase.failed) {
  return _PluginHostStatusPanel(
    title: viewState.statusTitle,
    message: viewState.errorMessage ?? viewState.statusMessage,
    actions: [...],
  );
}
```

- [ ] **Step 7: 运行测试确认通过**

Run: `flutter test test/services/plugin_host_controller_test.dart test/widgets/plugin_host_page_test.dart -r expanded`
Expected: PASS，缺少插件目录或解释器时都会进入明确错误态。

- [ ] **Step 8: 提交宿主错误文案收口**

```bash
git add frontend/lib/features/plugin_host/presentation/plugin_host_controller.dart frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart frontend/test/services/plugin_host_controller_test.dart frontend/test/widgets/plugin_host_page_test.dart
git commit -m "宿主补齐插件目录与解释器缺失提示"
```

## Task 4: 全链路验证与 evidence 收口

**Files:**
- Create: `evidence/2026-04-25_插件运行时目录重定向实施.md`
- Create: `evidence/verification_20260425_plugin_runtime_redirection.md`
- Test: `backend/tests/test_start_frontend_script_unit.py`
- Test: `frontend/test/services/plugin_runtime_locator_test.dart`
- Test: `frontend/test/services/plugin_host_controller_test.dart`
- Test: `frontend/test/widgets/plugin_host_page_test.dart`

- [ ] **Step 1: 运行 Python 启动脚本测试**

Run: `python -m pytest backend/tests/test_start_frontend_script_unit.py -q`
Expected: PASS，固定插件根目录和固定运行时目录都被注入。

- [ ] **Step 2: 运行 Flutter 目标测试集**

Run: `flutter test test/services/plugin_runtime_locator_test.dart test/services/plugin_host_controller_test.dart test/widgets/plugin_host_page_test.dart -r expanded`
Expected: PASS，路径定位与宿主错误态全部通过。

- [ ] **Step 3: 跑静态检查**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: 做一次人工联调**

Run: `python start_frontend.py --skip-pub-get --skip-bootstrap-admin`

Expected:
- 不设置任何额外环境变量
- 插件中心仍能发现 `serial_assistant`
- 点击后能拉起插件

- [ ] **Step 5: 新增实施留痕**

```md
# 插件运行时目录重定向实施

- 日期：2026-04-25
- 执行人：Codex
- 当前状态：已完成

## 已完成项

1. 运行时定位固定为 `plugins/runtime/python312/python.exe`
2. 插件根目录固定为 `plugins/`
3. Python 3.12 embeddable runtime 已纳入仓库
4. 宿主缺失解释器/插件目录时有明确错误文案

## 迁移说明

- 无迁移，直接替换
```

- [ ] **Step 6: 新增验证留痕**

```md
# 插件运行时目录重定向验证

- 执行日期：2026-04-25
- 当前状态：已通过

## 验证结果

1. 启动脚本测试：通过
2. Flutter 目标测试：通过
3. `flutter analyze`：通过
4. 人工联调：通过
```

- [ ] **Step 7: 提交验证与留痕**

```bash
git add evidence/2026-04-25_插件运行时目录重定向实施.md evidence/verification_20260425_plugin_runtime_redirection.md
git commit -m "补齐插件运行时目录重定向验证留痕"
```

## Self-Review

### Spec coverage

- 统一目录结构：Task 2
- 固定定位规则：Task 1
- 解释器提交边界：Task 2
- 宿主明确错误文案：Task 3
- 测试与留痕：Task 4

### Placeholder scan

- 本计划未使用 `TODO`、`TBD`、`稍后补`、`待实现` 等占位语句。
- 每个任务都包含精确文件路径、代码片段、命令和预期结果。

### Type consistency

- 统一使用 `plugins/runtime/python312/python.exe`
- 插件根目录统一使用 `plugins/`
- 宿主错误文案统一使用“插件目录缺失”和“Python 运行时缺失”

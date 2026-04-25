# 插件开发指南正文编写 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `docs/插件开发指南/` 下建立一套面向宿主维护者与插件开发者的正式正文文档，并与当前仓库中的插件实现保持一致。

**Architecture:** 文档采用“总览入口 + 分册正文”的结构：先用一篇总览文档定义边界与阅读顺序，再按宿主约定、插件包结构、Python 入口、UI 接口、调试交付和样板拆解分册展开。所有规则都以当前 `plugins/`、`serial_assistant` 样板和宿主实现为准，通过最后一轮占位词扫描和一致性复核收口。

**Tech Stack:** Markdown、PowerShell、现有插件 spec/evidence、Flutter 插件宿主实现、Python 插件样板

---

## 文件结构

### 需要创建的文件

- `docs/插件开发指南/00-总览与阅读顺序.md`
  - 说明文档定位、适用对象、阅读路径和总边界。
- `docs/插件开发指南/10-宿主约定与目录结构.md`
  - 收敛宿主扫描规则、运行时路径和目录结构。
- `docs/插件开发指南/20-插件包结构与清单规范.md`
  - 解释插件目录结构与 `manifest.json` 规范。
- `docs/插件开发指南/30-Python入口与依赖加载.md`
  - 解释 `launcher.py`、环境变量与 `sys.path` 规则。
- `docs/插件开发指南/40-UI承载与前后端接口.md`
  - 解释 Web UI 承载、`ready` 消息、`entry_url`、`heartbeat_url`。
- `docs/插件开发指南/50-开发调试测试与交付.md`
  - 收敛本地调试、联调、测试、日志与交付清单。
- `docs/插件开发指南/60-串口助手示例拆解.md`
  - 用 `serial_assistant` 逐文件解释样板插件。

### 需要修改的文件

- `evidence/2026-04-25_插件开发指南编写.md`
  - 追加正文编写、校对、自检和完成结论。

### 需要参考但不修改的文件

- `docs/superpowers/specs/2026-04-25-plugin-development-guide-design.md`
- `docs/superpowers/specs/2026-04-24-python-plugin-host-design.md`
- `docs/superpowers/specs/2026-04-25-plugin-runtime-redirection-design.md`
- `frontend/lib/features/plugin_host/services/plugin_runtime_locator.dart`
- `plugins/serial_assistant/manifest.json`
- `plugins/serial_assistant/launcher.py`
- `plugins/serial_assistant/app/server.py`
- `plugins/serial_assistant/web/index.html`

## Task 1: 建立总览入口与宿主约定分册

**Files:**
- Create: `docs/插件开发指南/00-总览与阅读顺序.md`
- Create: `docs/插件开发指南/10-宿主约定与目录结构.md`

- [ ] **Step 1: 创建总览文档并写入完整目录说明**

```md
# 插件开发指南总览与阅读顺序

## 1. 文档定位

- 本目录是当前仓库插件体系的正式开发指南。
- 适用对象：
  - 宿主维护者
  - 插件开发者
- 本目录只描述当前已经采用的实现口径，不描述未来愿景。

## 2. 当前插件体系边界

- 插件根目录固定为 `plugins/`
- Python 运行时固定为 `plugins/runtime/python312/python.exe`
- 插件以独立 Python 程序包存在，并自带业务逻辑与 Web UI
- 宿主只负责扫描、启动、停止、状态判断和内嵌承载

## 3. 阅读顺序

### 3.1 宿主维护者

1. `00-总览与阅读顺序.md`
2. `10-宿主约定与目录结构.md`
3. `40-UI承载与前后端接口.md`
4. `50-开发调试测试与交付.md`

### 3.2 插件开发者

1. `00-总览与阅读顺序.md`
2. `20-插件包结构与清单规范.md`
3. `30-Python入口与依赖加载.md`
4. `40-UI承载与前后端接口.md`
5. `50-开发调试测试与交付.md`
6. `60-串口助手示例拆解.md`
```

- [ ] **Step 2: 验证总览文档已写入关键边界**

Run: `Get-Content -Raw "docs/插件开发指南/00-总览与阅读顺序.md"`
Expected: 能看到 `plugins/`、`python312`、宿主维护者与插件开发者两条阅读路径。

- [ ] **Step 3: 创建宿主约定分册并写入正式路径口径**

```md
# 宿主约定与目录结构

## 1. 目的

- 本文档说明插件宿主如何定位插件目录与 Python 运行时。
- 本文档主要面向宿主维护者，也为插件开发者提供目录背景。

## 2. 正式目录口径

```text
plugins/
  runtime/
    python312/
      python.exe
  serial_assistant/
    manifest.json
    launcher.py
    app/
    vendor/
    web/
```

## 3. 固定规则

- 宿主必须默认从仓库根目录下的 `plugins/` 扫描插件。
- 宿主必须默认从 `plugins/runtime/python312/python.exe` 定位解释器。
- `MES_PLUGIN_ROOT` 与 `MES_PYTHON_RUNTIME_DIR` 只作为调试覆盖，不是正式交付口径。

## 4. 常见错误

- 把解释器重新放回 `frontend/build/.../runtime/python/`
- 让插件自己声明解释器绝对路径
- 在正式文档里把环境变量覆盖写成默认口径
```

- [ ] **Step 4: 验证宿主约定文档包含正式与调试两层口径**

Run: `Select-String -Path "docs/插件开发指南/10-宿主约定与目录结构.md" -Pattern "MES_PLUGIN_ROOT|MES_PYTHON_RUNTIME_DIR|python312"`
Expected: 至少匹配到 3 处，且能明确看出“正式口径”和“调试覆盖”的区别。

- [ ] **Step 5: 提交第一批总览与宿主分册**

```bash
git add "docs/插件开发指南/00-总览与阅读顺序.md" "docs/插件开发指南/10-宿主约定与目录结构.md"
git commit -m "新增插件开发指南总览与宿主约定"
```

## Task 2: 建立插件结构与 Python 入口分册

**Files:**
- Create: `docs/插件开发指南/20-插件包结构与清单规范.md`
- Create: `docs/插件开发指南/30-Python入口与依赖加载.md`

- [ ] **Step 1: 创建插件包结构分册并写入目录与 manifest 规范**

```md
# 插件包结构与清单规范

## 1. 标准目录结构

```text
plugins/<plugin_id>/
  manifest.json
  launcher.py
  app/
  vendor/
  web/
  tests/
```

## 2. `manifest.json` 必填字段

- `id`
- `name`
- `version`
- `entry.type`
- `entry.script`
- `ui.type`
- `ui.mode`
- `runtime.python`
- `runtime.arch`

## 3. 当前样板

```json
{
  "id": "serial_assistant",
  "name": "串口助手",
  "version": "0.1.0",
  "entry": { "type": "python", "script": "launcher.py" },
  "ui": { "type": "web", "mode": "embedded" }
}
```

## 4. 常见错误

- `id` 与目录名不一致
- `entry.script` 不是 `launcher.py`
- 漏掉 `runtime.python`
- 把依赖路径写成宿主绝对路径
```

- [ ] **Step 2: 验证插件包结构分册对齐当前样板 manifest**

Run: `Get-Content -Raw "docs/插件开发指南/20-插件包结构与清单规范.md"`
Expected: 能直接看到 `serial_assistant`、`launcher.py`、`vendor/`、`runtime.python`。

- [ ] **Step 3: 创建 Python 入口分册并写入环境变量与 `sys.path` 规则**

```md
# Python入口与依赖加载

## 1. `launcher.py` 的职责

- 读取宿主注入的环境变量
- 组装 `sys.path`
- 启动插件服务
- 输出结构化 `ready` 消息
- 保持主进程存活，直到宿主关闭

## 2. 宿主会注入的关键环境变量

- `MES_PLUGIN_DIR`
- `MES_PLUGIN_VENDOR_DIR`
- `MES_PLUGIN_APP_DIR`

## 3. 推荐写法

```python
plugin_dir = Path(os.environ.get("MES_PLUGIN_DIR", str(BASE_DIR)))
vendor_dir = Path(os.environ.get("MES_PLUGIN_VENDOR_DIR", str(plugin_dir / "vendor")))
app_dir = Path(os.environ.get("MES_PLUGIN_APP_DIR", str(plugin_dir / "app")))

sys.path.insert(0, str(vendor_dir))
sys.path.insert(0, str(plugin_dir))
sys.path.insert(0, str(app_dir))
```

## 4. `ready` 消息要求

- 必须输出 JSON
- 必须包含：
  - `event`
  - `pid`
  - `entry_url`
  - `heartbeat_url`

## 5. 禁止事项

- 依赖系统 Python 环境变量
- 把第三方库装进宿主公共目录
- 用非结构化文本代替 `ready` 消息
```

- [ ] **Step 4: 验证 Python 分册已经包含 `ready` 与环境变量**

Run: `Select-String -Path "docs/插件开发指南/30-Python入口与依赖加载.md" -Pattern "MES_PLUGIN_DIR|ready|heartbeat_url|sys.path"`
Expected: 至少匹配到 4 处，覆盖环境变量、启动消息和依赖注入。

- [ ] **Step 5: 提交第二批插件结构与 Python 分册**

```bash
git add "docs/插件开发指南/20-插件包结构与清单规范.md" "docs/插件开发指南/30-Python入口与依赖加载.md"
git commit -m "新增插件结构与 Python 入口指南"
```

## Task 3: 建立 UI 接口、调试交付与样板拆解分册

**Files:**
- Create: `docs/插件开发指南/40-UI承载与前后端接口.md`
- Create: `docs/插件开发指南/50-开发调试测试与交付.md`
- Create: `docs/插件开发指南/60-串口助手示例拆解.md`

- [ ] **Step 1: 创建 UI 接口分册并写入宿主与插件边界**

```md
# UI承载与前后端接口

## 1. 当前承载模式

- 插件必须自带 Web UI
- 宿主通过内嵌 WebView 打开插件提供的 `entry_url`
- 宿主不渲染插件内部业务 UI

## 2. 启动后接口要求

- 插件必须监听本地服务
- 插件必须提供可访问的 `entry_url`
- 插件必须提供 `heartbeat_url`

## 3. 前端页面建议

- 静态资源放在 `web/`
- 页面入口通常为 `index.html`
- 相对资源路径必须能在插件自己的本地服务下解析

## 4. 常见错误

- 只返回 `entry_url`，不返回 `heartbeat_url`
- 页面资源引用写成宿主路径
- 插件服务没有监听到 `127.0.0.1`
```

- [ ] **Step 2: 创建调试交付分册并写入开发流程与清单**

```md
# 开发调试测试与交付

## 1. 推荐开发流程

1. 复制样板插件目录
2. 修改 `manifest.json`
3. 实现 `launcher.py`
4. 实现 `app/` 业务逻辑
5. 实现 `web/` 页面
6. 先插件自测，再宿主联调

## 2. 自测要点

- `launcher.py` 能独立启动
- `ready` 消息结构正确
- `entry_url` 可打开
- `heartbeat_url` 可访问
- `vendor/` 依赖能正常导入

## 3. 交付前检查

- 目录中不应保留无意义缓存和临时文件
- `manifest.json` 与目录名一致
- 解释器路径未写死在插件内部
- 第三方依赖已随插件提供
```

- [ ] **Step 3: 创建串口助手样板拆解分册并按真实文件解释**

```md
# 串口助手示例拆解

## 1. 样板目录

- `manifest.json`：声明插件元数据
- `launcher.py`：组装路径并启动服务
- `app/server.py`：提供本地 HTTP 服务
- `app/serial_bridge.py`：封装串口操作
- `web/index.html`：插件页面入口
- `web/app.js`：页面交互逻辑
- `vendor/serial/`：插件自带的 pyserial 依赖

## 2. 最小启动链路

1. 宿主读取 `manifest.json`
2. 宿主调用 `python.exe launcher.py`
3. `launcher.py` 组装 `sys.path`
4. `app/server.py` 启动本地服务
5. 插件输出 `ready` JSON
6. 宿主打开 `entry_url`
```

- [ ] **Step 4: 验证三篇分册都包含示例和常见错误**

Run: `Select-String -Path "docs/插件开发指南/40-UI承载与前后端接口.md","docs/插件开发指南/50-开发调试测试与交付.md","docs/插件开发指南/60-串口助手示例拆解.md" -Pattern "常见错误|ready|entry_url|vendor|serial_assistant"`
Expected: 三个文件都能命中至少 1 条核心关键字。

- [ ] **Step 5: 提交第三批 UI、调试与样板分册**

```bash
git add "docs/插件开发指南/40-UI承载与前后端接口.md" "docs/插件开发指南/50-开发调试测试与交付.md" "docs/插件开发指南/60-串口助手示例拆解.md"
git commit -m "新增插件 UI 接口与调试样板指南"
```

## Task 4: 自检全文并更新 evidence 收口

**Files:**
- Modify: `evidence/2026-04-25_插件开发指南编写.md`
- Test: `docs/插件开发指南/*.md`

- [ ] **Step 1: 扫描占位词与空泛口径**

Run: `Select-String -Path "docs/插件开发指南/*.md" -Pattern "T[O]DO|TB[D]|待[补]|稍[后]|自[行]处理|类[似]上文"`
Expected: 无输出。

- [ ] **Step 2: 扫描关键固定口径是否写全**

Run: `Select-String -Path "docs/插件开发指南/*.md" -Pattern "plugins/runtime/python312/python.exe|plugins/|launcher.py|vendor/|entry_url|heartbeat_url"`
Expected: 所有关键口径都至少命中 1 次。

- [ ] **Step 3: 人工复核目录与阅读顺序**

Run: `Get-ChildItem "docs/插件开发指南" | Select-Object Name`
Expected:
- `00-总览与阅读顺序.md`
- `10-宿主约定与目录结构.md`
- `20-插件包结构与清单规范.md`
- `30-Python入口与依赖加载.md`
- `40-UI承载与前后端接口.md`
- `50-开发调试测试与交付.md`
- `60-串口助手示例拆解.md`

- [ ] **Step 4: 更新 evidence 记录完成情况与验证结果**

```md
## 3. 当前状态

- 已完成：
  - `docs/插件开发指南/` 七篇正文已全部写入
  - 已完成占位词扫描
  - 已完成固定口径一致性复核
- 进行中：
  - 无

## 3.3 最终交付

1. 插件开发指南目录已建立
2. 宿主维护者阅读路径已明确
3. 插件开发者阅读路径已明确
4. 当前 `serial_assistant` 已作为标准样板纳入文档
```

- [ ] **Step 5: 提交正文与 evidence 收口**

```bash
git add "docs/插件开发指南" "evidence/2026-04-25_插件开发指南编写.md"
git commit -m "补齐插件开发指南正文"
```

## Self-Review

### Spec coverage

- 文档目录与分册边界：Task 1、Task 2、Task 3
- 宿主维护者阅读路径：Task 1
- 插件开发者阅读路径：Task 1、Task 2、Task 3
- 固定口径统一：Task 1、Task 2、Task 3、Task 4
- 样板插件拆解：Task 3
- evidence 收口：Task 4

### Placeholder scan

- 本计划未使用常见占位语句、模糊指代或“后续再补”的写法。
- 所有创建步骤都给出了精确文件路径和可直接落入的 Markdown 结构。

### Type consistency

- 插件根目录统一为 `plugins/`
- 运行时路径统一为 `plugins/runtime/python312/python.exe`
- 插件入口统一为 `launcher.py`
- 关键启动字段统一为 `entry_url` 与 `heartbeat_url`

# ZYKJ MES 交接总览

## 项目定位

本仓库是一个前后端分离的 MES 项目：

- `backend/`：Python 后端，负责 API、数据库迁移、权限与业务服务。
- `frontend/`：Flutter 前端，默认以 Windows 桌面应用方式运行。
- `plugins/`：插件根目录；固定 Python 解释器位于 `plugins/runtime/python312/python.exe`。
- `docs/superpowers/specs/` 与 `docs/superpowers/plans/`：近期功能设计与实施计划。
- `evidence/`：任务日志、验证日志、只读复核与交付留痕。

开始任何新任务前，先阅读：

1. 根 `AGENTS.md`
2. `docs/AGENTS/00-导航与装配说明.md`
3. `docs/AGENTS/10-执行总则.md`
4. `docs/AGENTS/20-指挥官模式与工作流.md`
5. `docs/AGENTS/30-工具治理与验证门禁.md`
6. `docs/AGENTS/40-质量交付与留痕.md`
7. `docs/AGENTS/50-模板与索引.md`

## 插件运行时口径

- 插件统一放在 `plugins/` 根目录下组织。
- 仓库固定解释器路径为 `plugins/runtime/python312/python.exe`。
- 涉及仓库内插件运行、插件安装说明、插件调试复现、CI/脚本需要固定版本时，必须使用内置解释器，避免依赖系统全局 Python。
- 仅在运行仓库根级启动脚本、开发者自管工具链，且任务不依赖插件固定运行时时，可以继续使用系统 Python。
- 当前运行时目录按官方 `Python 3.12.10 Windows embeddable package (64-bit)` 原样入仓，仅额外补充说明文档；日常维护不允许随意裁剪、增删其中二进制内容。
- 平台边界：当前仅支持 Windows x64。
- 整目录入仓是为了同时固定 `python.exe`、`python312.dll`、`python312.zip`、VC 运行库与扩展模块，避免插件在不同机器上因缺文件或版本漂移无法复现。
- 运行时升级或替换时，统一用新的官方 embeddable package 整包覆盖 `plugins/runtime/python312/`，保留或更新本目录 `README.md`，再执行：

```powershell
git check-ignore -v plugins/runtime/python312/python.exe
& .\plugins\runtime\python312\python.exe -c "import sys; print(sys.version)"
```

- 校验通过标准：`python.exe` 不应被忽略，且 `sys.version` 输出目标版本号；若不满足，则不得提交。

## 默认启动命令

推荐从仓库根目录启动。

### 1. 本地联调主线

先启动后端：

```powershell
python start_backend.py
```

再在新终端启动前端：

```powershell
python start_frontend.py
```

说明：

- `start_frontend.py` 默认设备是 `windows`。
- 前端启动前会尝试等待本地后端 `/health`，并调用 `/api/v1/auth/bootstrap-admin` 修复默认管理员。
- 如需切换前端设备，可使用：

```powershell
python start_frontend.py --device chrome
```

### 2. 常用后端运维命令

```powershell
python start_backend.py ps
python start_backend.py logs
python start_backend.py down
python start_backend.py --expose-db --db-port 5433
```

### 3. Docker Compose 启动口径

```powershell
docker compose up -d --build
docker compose ps
docker compose logs backend-web --tail=100
docker compose logs backend-worker --tail=100
```

## 默认账号

本地默认管理员账号如下：

- 用户名：`admin`
- 密码：`Admin_Local_20260419!`

如账号状态异常，优先重新执行：

```powershell
python start_frontend.py --skip-pub-get
```

或重启后端后再次启动前端，让 bootstrap 逻辑自动修复。

## 测试命令

### 后端

后端全量测试：

```powershell
python -m pytest backend/tests -q
```

后端启动脚本轻量验证：

```powershell
python -m pytest backend/tests/test_start_backend_script_unit.py -q
```

### 前端

先进入前端目录：

```powershell
cd frontend
```

静态检查：

```powershell
flutter analyze
```

前端默认测试主线：

```powershell
flutter test
```

近期高频回归命令：

```powershell
flutter test test/widgets/message_center_page_test.dart -r compact
flutter test test/widgets/main_shell_page_test.dart --plain-name "主壳会把消息模块活跃态真实传到消息中心页面" -r expanded
flutter test test/widgets/production_page_test.dart --plain-name "production page 会在页签切换时联动订单查询轮询活跃态" -r expanded
```

### 集成测试

当前仓库已拆分出 11 份 `frontend/integration_test/*.dart` 用例，按单文件执行即可，例如：

```powershell
cd frontend
flutter test integration_test/login_flow_test.dart
flutter test integration_test/home_shell_flow_test.dart
flutter test integration_test/message_center_flow_test.dart
```

## 当前优先事项

以下优先事项基于当前仓库状态与最近留痕整理，更新时间：2026-04-24。

1. 工序管理页下一阶段改造优先采用“紧凑工作台”方案。
   - 计划文件：`docs/superpowers/plans/2026-04-23-process-management-compact-workbench-implementation.md`
   - 备选方案：`docs/superpowers/plans/2026-04-23-process-management-redesign-implementation.md`
2. 保持前端关键回归链路为绿。
   - 重点关注：主壳、首页、消息中心、生产页轮询联动。
   - 建议至少跑上面的 3 条高频回归命令，再决定是否继续扩改页面。
3. 继续保持交接与留痕一致。
   - 每次任务开始与结束都更新 `evidence/`。
   - `evidence/task_log_*.md` 当前被 `.gitignore` 忽略；如果需要把日志随提交共享，请同时更新非忽略的 evidence 文件或 `verification_*.md`。

## 近期已完成事项

1. 消息中心页面重做已完成，包含布局重做、详情预览收口与响应式修正。
   - 主日志：`evidence/task_log_20260424_message_center_redesign.md`
   - 验证日志：`evidence/verification_20260424_message_center_redesign.md`
2. 前端轮询治理已完成最终只读复核，可进入分支收尾。
   - 复核日志：`evidence/2026-04-24_前端轮询治理最终只读复核.md`

## 常用目录

- `backend/app/`：后端业务代码
- `backend/tests/`：后端测试
- `frontend/lib/`：前端页面、服务与模型
- `frontend/test/`：前端单元 / widget / 服务测试
- `frontend/integration_test/`：前端集成流测试
- `docs/superpowers/specs/`：设计稿
- `docs/superpowers/plans/`：实施计划
- `evidence/`：任务与验证留痕

## 交接提醒

- 所有沟通、文档、注释与新增文件默认使用中文。
- 每次提交前先做真实验证，再写结论。
- 所有 git 提交信息必须使用中文。
- 默认迁移口径：`无迁移，直接替换`。

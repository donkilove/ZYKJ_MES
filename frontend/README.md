# ZYKJ MES Frontend

## 前端定位

`frontend/` 是 ZYKJ MES 的 Flutter 客户端，当前默认运行形态是 Windows 桌面应用。

前端主要职责：

- 承载主壳导航、首页、消息中心、用户、产品、工艺、设备、生产、质量、设置等模块页面
- 对接 `backend/` 提供的 REST API 与消息推送能力
- 维护 widget / service / integration 测试基线

如需查看仓库级交接信息，回到仓库根目录阅读 `README.md`。

## 启动方式

### 1. 推荐入口

在仓库根目录执行：

```powershell
python start_frontend.py
```

默认行为：

- 默认设备：`windows`
- 默认 API 基地址：`http://127.0.0.1:8000/api/v1`
- 启动前会等待本地后端 `/health`
- 启动前会尝试调用 `/auth/bootstrap-admin` 修复默认管理员

常用参数：

```powershell
python start_frontend.py --device chrome
python start_frontend.py --skip-pub-get
python start_frontend.py --skip-bootstrap-admin
python start_frontend.py --api-base-url http://127.0.0.1:8000/api/v1
```

### 2. 直接使用 Flutter

在 `frontend/` 目录执行：

```powershell
flutter pub get
flutter run -d windows
```

## 默认账号

联调时默认使用以下管理员账号：

- 用户名：`admin`
- 密码：`Admin_Local_20260419!`

如果登录失败，优先确认后端已启动，再重新执行仓库根目录的：

```powershell
python start_frontend.py
```

## 测试命令

以下命令默认在 `frontend/` 目录执行。

### 1. 静态检查

```powershell
flutter analyze
```

### 2. 默认测试主线

```powershell
flutter test
```

### 3. 高频回归命令

```powershell
flutter test test/widgets/message_center_page_test.dart -r compact
flutter test test/widgets/main_shell_page_test.dart --plain-name "主壳会把消息模块活跃态真实传到消息中心页面" -r expanded
flutter test test/widgets/production_page_test.dart --plain-name "production page 会在页签切换时联动订单查询轮询活跃态" -r expanded
```

### 4. 集成测试

当前已拆分 11 份 `integration_test` 用例，可按单文件执行，例如：

```powershell
flutter test integration_test/login_flow_test.dart
flutter test integration_test/home_shell_flow_test.dart
flutter test integration_test/message_center_flow_test.dart
```

## 当前优先事项

截至 2026-04-24，前端接手建议如下：

1. 工序管理页下一轮优先推进“紧凑工作台”方案。
   - 计划文件：`../docs/superpowers/plans/2026-04-23-process-management-compact-workbench-implementation.md`
2. 继续守住主壳、消息中心、生产页轮询联动相关回归。
3. 新任务必须同步更新 `evidence/`，并让留痕状态与实际完成度保持一致。

## 目录说明

- `lib/features/`：按业务模块组织的页面、服务、模型
- `lib/core/`：共享基础设施、UI Pattern、通用服务
- `test/`：单元、widget、服务测试
- `integration_test/`：模块流与壳层联动测试
- `web/`：Web 运行所需静态资源
- `windows/`：Windows 桌面端 runner 与生成文件

## 交接提醒

- 前端默认测试基线是 `flutter test` 与 `integration_test`，不要只改页面不补验证。
- 若命中用户模块行为、入口、筛选、状态流转、文案边角分支，需要同步收敛后端/API、Flutter、`integration_test` 与 `evidence/`。
- 如需提交可共享的任务日志，注意 `evidence/task_log_*.md` 当前默认被 `.gitignore` 忽略。

# 指挥官执行留痕：用户模块批次一整改（2026-03-22）

## 1. 任务信息

- 任务名称：用户模块批次一整改
- 执行方式：静态对照整改 + 定向回归验证
- 当前状态：已完成
- 工具降级：当前会话未提供 `Sequential Thinking`、`update_plan`，改为书面拆解与定向测试补偿

## 2. 输入基线

- 整改基线：`docs/功能规划V1_极深审查报告_20260322.md`
- 重点问题：首次改密后重新登录、编辑/重置密码拆分、导出权限显隐、登录日志/在线会话细粒度权限闭环、个人中心保底访问、前后端契约同步

## 3. 核心改动

- `backend/app/schemas/user.py`：移除编辑用户接口中的密码字段，并禁止额外旧字段透传。
- `backend/app/services/user_service.py`：编辑用户逻辑不再处理密码，仅保留资料/角色/工段/状态更新。
- `backend/tests/test_user_module_integration.py`：补充首次改密后旧 token 立即失效、旧编辑密码契约被拒绝回归。
- `frontend/lib/main.dart`、`frontend/lib/pages/force_change_password_page.dart`、`frontend/lib/pages/login_page.dart`：首次改密后清空前端会话并回到登录页，提示用户使用新密码重登。
- `frontend/lib/pages/user_management_page.dart`、`frontend/lib/services/user_service.dart`：拆分编辑与重置密码流程，导出按钮按独立权限控制。
- `frontend/lib/pages/user_page.dart`、`frontend/lib/pages/login_session_page.dart`：登录日志查看、在线会话查看、强制下线拆成独立前端权限闭环，仅加载/展示有权内容。
- `frontend/test/widgets/user_management_page_test.dart`、`frontend/test/widgets/user_module_support_pages_test.dart`、`frontend/test/services/user_service_test.dart`：补齐前端高价值回归。

## 4. 验证留痕

- `".venv\Scripts\python.exe" -m unittest backend.tests.test_user_module_integration`：4 项通过。
- `flutter test "test/services/user_service_test.dart" "test/widgets/user_management_page_test.dart" "test/widgets/user_module_support_pages_test.dart"`：14 项通过。
- `flutter analyze "lib/main.dart" "lib/pages/force_change_password_page.dart" "lib/pages/login_page.dart" "lib/pages/login_session_page.dart" "lib/pages/user_management_page.dart" "lib/pages/user_page.dart" "lib/services/user_service.dart" "test/services/user_service_test.dart" "test/widgets/user_management_page_test.dart" "test/widgets/user_module_support_pages_test.dart"`：通过，无问题。

## 5. 迁移说明

- 无迁移，直接替换。

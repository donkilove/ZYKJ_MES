# 2026-04-07 用户管理在线状态轮询优化

## 目标
- 按照需求把用户管理在线状态轮询改成可见性感知和退避调度，操作后能立即同步状态，并补齐测试。

## 结论
- `UserManagementPage` 接收来自 `UserPage` 的页签可见性并在不可见时停止轮询。
- 将原先固定的 `Timer.periodic` 替换为自退避的单次调度，轮询仅在可见、非加载、非暂停、无进行中轮询且存在可轮询用户时激活。
- 用户停用/删除/密码重置/启用等操作会先本地调整行数据再静默刷新，保持在线状态贴近当前操作。
- 覆盖新增场景（页签可见性、失败退避、状态即时修正）并保持现有测试通过。

## 验证
- 在 `frontend` 目录执行：
  - `flutter test test/widgets/user_management_page_test.dart`
  - `flutter test test/widgets/user_page_test.dart`
  所有测试均通过。

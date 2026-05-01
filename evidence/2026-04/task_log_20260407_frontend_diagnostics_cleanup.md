# 任务日志：前端诊断清理与回归

## 时间
- 2026-04-07 23:05 ~ 23:20 +08:00

## 目标
- 清理截图中的 9 个前端诊断
- 保持行为不回退
- 补齐与重置密码失败分支相关的 widget 回归

## 实际改动
- `frontend/test/widgets/message_center_page_test.dart`
  - 对齐 `_FakeUserService.listUsers` 方法签名，补齐 `deletedScope`
- `frontend/lib/pages/user_management_page.dart`
  - 移除多余的 `detailWarning!`
  - 修正重置密码失败分支中跨 async gap 使用 `State.context` 的保护
  - 删除未引用的 `_downloadExportTask`
  - 用 `WidgetStatePropertyAll` 替换 `MaterialStatePropertyAll`
  - 用 `withValues(alpha: ...)` 替换 `withOpacity(...)`
- `frontend/test/widgets/main_shell_page_test.dart`
  - 移除两个计数 fake 中未使用的 `error` 构造参数
- `frontend/test/widgets/user_management_page_test.dart`
  - 新增“重置密码返回 400 时展示失败提示”
  - 新增“重置密码返回 401 时触发登出回调”

## 验证命令
- `flutter analyze lib/pages/user_management_page.dart test/widgets/message_center_page_test.dart test/widgets/main_shell_page_test.dart`
- `flutter test test/widgets/message_center_page_test.dart`
- `flutter test test/widgets/main_shell_page_test.dart`
- `flutter test test/widgets/user_management_page_test.dart --plain-name "重置密码返回 400 时展示失败提示"`
- `flutter test test/widgets/user_management_page_test.dart --plain-name "重置密码返回 401 时触发登出回调"`

## 验证结果
- 上述命令全部通过
- 目标 9 个诊断在分析中已清零

## 备注
- 本次仅清理截图中的诊断与其直接相关测试，不扩展为全仓 lint 清扫

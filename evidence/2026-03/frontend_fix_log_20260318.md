# 前端错误修复记录（2026-03-18）

## 任务信息
- 开始时间：2026-03-18
- 结束时间：2026-03-18
- 任务目标：修复已审批的前端启动、文档、检查脚本、测试签名与 API 基址透传问题。
- 输入来源：用户审批意见、仓库源码、静态检查结果。

## 已执行变更
- 将 `start_frontend.py` 的前端目录从 `mes_client` 修正为 `frontend`。
- 为 `start_frontend.py` 增加 `--dart-define=MES_API_BASE_URL=...` 透传。
- 修正文档中的错误启动入口，统一为 `start_backend.py`、`start_frontend.py`。
- 修复 `backend/scripts/check_frontend_chinese_mojibake.py` 的默认扫描路径，改为仓库真实前端目录。
- 修复 `frontend/test/widgets/product_module_issue_regression_test.dart` 中过期的 `listProducts` override 签名。
- 让 `frontend/lib/pages/login_page.dart` 支持从 `MES_API_BASE_URL` 读取默认接口地址。
- 将 `frontend/lib/pages/user_management_page.dart` 的用户导出从固定写入 Windows `Downloads` 目录改为 `file_selector` 保存对话框，避免路径假设导致保存失败。

## 验证结果
- 首轮 `flutter analyze`：通过，无 error；存在 5 条 info 级 lint。
- 已修复 `frontend/lib/services/craft_service.dart` 的 4 条 `use_null_aware_elements` 与 `frontend/lib/services/production_service.dart` 的 1 条 `curly_braces_in_flow_control_structures`。
- 二次 `flutter analyze`：`No issues found!`。
- `python -c "from start_frontend import FRONTEND_DIR; print(FRONTEND_DIR.exists(), FRONTEND_DIR)"`：结果为 `True`，确认启动脚本目录指向有效。
- `python backend/scripts/check_frontend_chinese_mojibake.py`：输出 `No frontend Chinese mojibake detected.`。
- `flutter test test/widgets/user_management_page_test.dart`：3 项通过。

## 假设与局限
- 本次按审批意见未继续推进其他平台 runner，仅优先收敛 Windows 使用链路。
- 未实际拉起 GUI 前端窗口；当前结论基于脚本解析、静态检查与只读运行结果，置信度高。

## 迁移说明
- 无迁移，直接替换。

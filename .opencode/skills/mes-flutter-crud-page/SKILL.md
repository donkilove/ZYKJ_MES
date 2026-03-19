---
name: mes-flutter-crud-page
description: 在 ZYKJ_MES Flutter Windows 管理端中实现或重构列表、筛选、分页、表单弹窗类 CRUD 页面。
---

# mes-flutter-crud-page

## 何时使用

- 需要新增或重构管理后台风格的 Flutter 页面。
- 页面包含表格列表、筛选、分页、弹窗表单、只读态、导出或详情展示。
- 需要让页面与当前 `MainShellPage` 权限体系、消息跳转与中文文案保持一致。

## 不适用场景

- 仅改后端接口，不改前端页面。
- 仅修复单个文案或样式瑕疵。
- 需要做完全脱离现有系统风格的新视觉实验页。

## 本仓库关键路径

- `frontend/lib/pages/`
- `frontend/lib/models/`
- `frontend/lib/services/`
- `frontend/lib/widgets/adaptive_table_container.dart`
- `frontend/lib/widgets/locked_form_dialog.dart`
- `frontend/lib/widgets/simple_pagination_bar.dart`
- `frontend/lib/widgets/unified_list_table_header_style.dart`
- `frontend/test/widgets/`

## 默认原则

- 优先复用现有页面骨架、表格样式和分页组件，不重复造轮子。
- 所有页面文案、提示、按钮文本使用中文，并与业务语义一致。
- 列表页要同时覆盖加载中、空数据、错误、无权限、成功操作反馈几种状态。
- 不硬编码下载目录；如需导出，优先沿用 `file_selector` 或现有安全保存方案。

## 执行步骤

1. 明确页面属于哪个模块，以及上层 `pageCode`、`tabCode`、能力码来源。
2. 先定义页面所需模型与服务接口，再落界面，避免 UI 先跑偏。
3. 列表区域优先使用统一表头样式和自适应表格容器。
4. 表单类操作优先使用弹窗或已有交互模式，区分新增、编辑、只读、禁用态。
5. 将权限控制落实到页面入口、操作按钮和提交校验，不只隐藏文案。
6. 若涉及导出、选择文件或外链跳转，优先复用已存在的服务模式。
7. 为关键交互补充 widget test，至少覆盖主流程与一个异常场景。

## 验证与证据

- 最低验证：`flutter analyze`
- 优先运行目标页面相关的 widget test 与 service test。
- 若页面依赖新接口且未联调成功，必须在交付里标出未验证点。

## 输出要求

- 明确列出页面、模型、服务、测试各自改动文件。
- 明确说明页面对应的能力码或可见性入口。
- 明确说明是否沿用了现有组件，避免后续维护出现双轨实现。

## 风险提示

- 该仓库页面很多，最容易出现的问题是复制旧页面后遗留旧字段、旧权限码、旧导出逻辑。
- 页面看似可用并不代表权限正确，必须回到 `MainShellPage` 与能力码入口做交叉检查。

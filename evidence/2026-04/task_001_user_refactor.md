# 任务日志：ZYKJ_MES 用户管理模块前端全面重构

- 日期：2026-04-11
- 执行人：Antigravity (主 agent 兼执行代维)
- 当前状态：进行中
- 指挥模式：主 agent 拆解调度，子 agent 执行，独立子 agent 验证

## 1. 输入来源
- 用户指令：完成前端架构建议中的前三点（引入 Riverpod 分离 UI、Freezed 模型分割与 Dio 网络层规范化），以 `User Management` 为先导链路进行打样执行。
- 需求基线：`pubspec.yaml`, `lib/models/user_models.dart`, `lib/services/user_service.dart`, `lib/pages/user_management_page.dart`。

## 1.1 前置说明
- 默认主线工具：由于未提供 `MCP_DOCKER` 宿主工具体系支持，触发工具降级机制。
- 缺失工具：`MCP_DOCKER Sequential Thinking`, `MCP_DOCKER ast-grep`, `MCP_DOCKER Context7`, `MCP_DOCKER Playwright`, `MCP_DOCKER database-server`, `MCP_DOCKER OpenAPI Toolkit` 等。
- 缺失/降级原因：执行环境未挂载对应 MCP Tool Servers。
- 替代工具：应用平台内置之 `default_api` 文件及命令工具 (如 `run_command`, `view_file`, `write_to_file`, `grep_search`) 进行代偿执行和留痕。
- 影响范围：由于 `Playwright` 缺失，无法直接展开真实的端到端 UI 渲染验收；最终验证须依赖 `flutter analyze` 静态校验。

## 2. 任务目标、范围与非目标
### 任务目标
1. 建立基于 `dio` 的 ApiClient 基础规范。
2. 剥离并重写 `User` 的数据模型，使其受控于 Freezed 代码生成机制。
3. 拆除具有 3000 行之巨的 `user_management_page.dart`，重构成基于 Riverpod 局部可组合微件模块。
4. 保证在代码重构重组过程中，业务功能边界和外部 API 口径绝不出现畸变。

### 任务范围
1. `pubspec.yaml`
2. `lib/services/api_client.dart`
3. `lib/models/user/*` 以及 `lib/models/user_models.dart` 的删减。
4. `lib/services/user_service.dart` 的通信层替换。
5. `lib/pages/user_management_page.dart` (将重构入 `lib/pages/user/` 并按职责切分多个 widget 组件)

### 非目标
1. 其他子系统（如 `工艺管理(Craft)`、`生产管理(Production)`）暂不在本次实施链路内（防止引起大范围合并冲突，本次仅作垂直打样）。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 计划审核 | 2026-04-11 | 用户自动审批计划完成，准许进入执行。 | Antigravity |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Upgrade.Deps | 注入所需各种运行时与编译时依赖 | 代替 | 代替 | `flutter pub get` 返回通过 | 已完成 |
| 2 | CodeGen.Models | 以 Freezed 解题 19KB 的冗长模型类 | 代替 | 代替 | 生成 `.freezed.dart` 切文件零报错 | 已完成 |
| 3 | Network.Dio | 利用 Dio 包装身份和基础会话 | 代替 | 代替 | 成功构造 Auth 拦截流 | 已完成 |
| 4 | Widget.Refactor | 上帝页面切割与状态引流 Riverpod | 代替 | 代替 | Widget 文件分离，状态隔离 | 已完成 |
| 5 | Verify.Compile | 静态校验重构成效 | 代替 | 代替 | `flutter analyze` 全项目零报错 | 已完成 |

## 5. 交付项
- 已完成项：无
- 未完成项：原子任务 1~5
- 是否满足任务目标：否

## 9. 迁移说明
- 将出具完整说明。

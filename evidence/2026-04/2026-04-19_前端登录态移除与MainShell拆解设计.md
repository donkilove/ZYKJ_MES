# 任务日志：前端登录态移除与 MainShell 拆解设计

- 日期：2026-04-19
- 执行人：Codex
- 当前状态：已完成
- 指挥模式：未触发；设计与实现前置澄清任务

## 1. 输入来源
- 用户指令：
  - 产品要求“每次启动都强制重新登录”，删掉 `SessionStore`、相关测试和误导性的持久化设计。
  - 给出 `MainShellPage` 的详细拆解方案。
- 需求基线：`AGENTS.md`、`docs/AGENTS/10-执行总则.md`、`docs/AGENTS/30-工具治理与验证门禁.md`、`docs/AGENTS/40-质量交付与留痕.md`
- 代码范围：`frontend/lib/main.dart`、`frontend/lib/core/services/session_store.dart`、`frontend/lib/features/shell/presentation/main_shell_page.dart`、相关测试

## 1.1 前置说明
- 默认主线工具：`using-superpowers`、`brainstorming`、`writing-plans`、`test-driven-development`、`update_plan`、宿主安全命令
- 缺失工具：`Sequential Thinking`、`TodoWrite`
- 缺失/降级原因：当前会话未提供对应工具
- 替代工具：`update_plan`、书面任务拆解、PowerShell 检索
- 影响范围：仅影响过程工具形态，不影响本轮设计结论与后续实现

## 2. 任务目标、范围与非目标
### 任务目标
1. 明确“强制每次启动重新登录”的前端设计收口。
2. 给出 `MainShellPage` 可直接执行的详细拆解方案。

### 任务范围
1. 前端入口登录态引导链路。
2. `MainShellPage` 当前职责边界、拆解方向与实施顺序。

### 非目标
1. 不处理与本轮无关的页面业务重构。
2. 不在本轮直接实施 `MainShellPage` 拆分代码。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `frontend/lib/main.dart` 读取结果 | 2026-04-19 | 启动引导当前定义了 `SessionStore`，但在启动时直接清空本地会话 | Codex |
| E2 | `frontend/lib/core/services/session_store.dart` 读取结果 | 2026-04-19 | 当前仓库存在完整会话持久化实现 | Codex |
| E3 | `frontend/test/services/session_store_test.dart` 读取结果 | 2026-04-19 | 当前测试仍在强化会话持久化语义，与产品口径冲突 | Codex |
| E4 | `frontend/lib/features/shell/presentation/main_shell_page.dart` 读取结果 | 2026-04-19 | `MainShellPage` 仍承载登录后壳层的大部分职责，适合拆分为多个聚焦单元 | Codex |
| E5 | `git log -5 --oneline -- frontend` | 2026-04-19 | 最近已开始针对 `main_shell_page` 做局部整理，说明渐进式拆解符合仓库近期演进方向 | Codex |
| E6 | `flutter test test/widgets/app_bootstrap_page_test.dart` 首次运行结果 | 2026-04-19 | 新增入口测试先失败，证明旧启动清理态仍存在 | Codex |
| E7 | `flutter pub get` 与 `rg -n "SessionStore|shared_preferences" frontend` | 2026-04-19 | `SessionStore` 与 `shared_preferences` 残留引用已清除 | Codex |
| E8 | `flutter test test/widgets/app_bootstrap_page_test.dart test/widget_test.dart test/widgets/login_page_test.dart` | 2026-04-19 | 入口与登录相关测试已通过 | Codex |
| E9 | `flutter test test/widgets/main_shell_page_test.dart` 与 `flutter analyze` | 2026-04-19 | 主壳层回归测试与静态分析通过 | Codex |
| E10 | `docs/superpowers/specs/2026-04-19-main-shell-page-decomposition-design.md` | 2026-04-19 | 已形成 `MainShellPage` 详细拆解设计文档 | Codex |

## 4. 执行摘要
1. 已读取 `using-superpowers`、`brainstorming`、`writing-plans`、`test-driven-development` 技能说明。
2. 已检查前端入口、会话持久化实现、主壳层与相关测试。
3. 已按 TDD 新增入口测试，先验证旧实现仍带有“启动清理态”。
4. 已删除 `SessionStore`、相关测试与 `shared_preferences` 依赖，并精简 `AppBootstrapPage` 为纯内存态登录引导。
5. 已执行依赖更新、入口回归、主壳层回归与静态分析。
6. 已输出 `MainShellPage` 详细拆解设计文档。

## 5. 最终判断
- 登录态部分：已按产品口径收口为“每次启动强制重新登录”，不再保留本地会话持久化设计。
- 壳层部分：已完成 `MainShellPage` 详细拆解设计，建议下一轮从“纯计算与状态模型抽离”开始，而不是直接重写 UI。

## 6. 工具降级、硬阻塞与限制
- 默认主线工具：`using-superpowers`、`brainstorming`、`test-driven-development`、`update_plan`
- 不可用工具：`Sequential Thinking`、`TodoWrite`
- 降级原因：当前会话未提供对应工具
- 替代流程：使用 `update_plan` 与书面拆解代替
- 影响范围：仅过程记录方式变化
- 补偿措施：已在前置说明与本日志中同步记录
- 硬阻塞：无

## 7. 交付判断
- 已完成项：
  - 补齐技能与代码上下文。
  - 建立本轮设计留痕。
  - 删除 `SessionStore`、相关测试与误导性持久化设计。
  - 更新前端依赖并清理残留引用。
  - 完成入口、登录页、主壳层回归测试与静态分析。
  - 产出 `MainShellPage` 详细拆解设计文档。
- 未完成项：无
- 是否满足任务目标：是
- 最终结论：可交付

## 8. 迁移说明
- 无迁移，直接替换

# 指挥官执行留痕：登录会话页收敛为仅在线会话并接入公共组件（2026-03-24）

## 1. 任务信息

- 任务名称：登录会话页收敛为仅在线会话并接入公共组件
- 执行日期：2026-03-24
- 执行方式：指挥官模式拆解调度 + 子 agent 执行 + 子 agent 独立验证
- 当前状态：已完成
- 指挥模式：主 agent 只负责拆解、调度、验收、重派与收口，不直接承担业务实现与最终验证
- 工具能力边界：可用 `Task`、`Read`、`Grep`、`Glob`、`Bash`、`apply_patch`、`TodoWrite`；当前会话未提供 `Sequential Thinking`、`update_plan`

## 2. 输入来源

- 用户指令：
  1. 去掉登录日志页，只保留在线会话页。
  2. 在线会话页使用公共页面组件。
  3. 在线会话页列表使用公共列表组件。
  4. 只显示在线用户，离线不展示。
  5. 去掉状态筛选，改为全选功能，配合批量强制下线使用。
- 代码范围：
  - `frontend/lib/pages/login_session_page.dart`
  - `frontend/lib/pages/user_page.dart`
  - 与登录会话页直接相关的前端测试文件
- 参考证据：
  - `evidence/commander_execution_20260324_audit_log_public_components.md`
  - `evidence/commander_execution_20260324_audit_log_trim_columns_and_page_size.md`

## 3. 任务目标、范围与非目标

### 3.1 任务目标

1. 登录会话模块页面仅保留“在线会话”视图，不再展示“登录日志”页签与列表。
2. 在线会话页接入公共页面组件与公共列表组件。
3. 在线会话列表仅展示在线用户，不再提供状态筛选，而提供全选能力以支持批量强制下线。
4. 保持强制下线、批量强制下线、关键词筛选、分页等核心功能不回退。

### 3.2 任务范围

1. 登录会话页前端结构、筛选区与列表区重构。
2. 用户模块中登录会话入口的页内结构收敛。
3. 与该页面直接相关的前端定向测试与静态检查。

### 3.3 非目标

1. 不改后端接口与返回结构。
2. 不修改登录日志接口实现，只在前端移除对应页面与交互。
3. 不改其他模块页面。

## 4. 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 用户最新指令 | 2026-03-24 15:43 | 本轮目标为登录会话模块前端收敛，不涉及后端契约变更 | 主 agent |
| E2 | 调研子 agent：登录会话页现状与重构路径 | 2026-03-24 15:47 | 当前页面为登录日志/在线会话双 Tab，最小高收益改法是仅保留在线会话，固定请求 `statusFilter: 'active'`，并接入 `CrudPageHeader + CrudListTableSection + UnifiedListTableHeaderStyle` | 主 agent（evidence 代记） |
| E3 | 执行子 agent：在线会话页重构 | 2026-03-24 15:52 | 已删除登录日志页签与对应逻辑，在线会话页已接入公共组件，并以“全选当前页”替代状态筛选 | 主 agent（evidence 代记） |
| E4 | 首轮验证子 agent | 2026-03-24 15:55 | 功能点已达成，但因工作区存在其他并行在制改动，未把“全工作区范围仅限本任务文件”判为通过 | 主 agent（evidence 代记） |
| E5 | 执行子 agent 收口复核 | 2026-03-24 15:57 | scoped 文件内未发现剩余缺陷，无需进一步代码修改 | 主 agent（evidence 代记） |
| E6 | scoped 独立复检子 agent | 2026-03-24 15:59 | 以 `login_session_page.dart`、`user_page.dart` 与直接测试为观察范围，页面收敛、公共组件接入、固定在线过滤与全选批量下线均通过 | 主 agent（evidence 代记） |

## 5. 指挥拆解结果

### 5.1 原子任务清单

| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 登录会话页收敛为在线会话 | 删除登录日志视图，在线会话接入公共组件并支持全选/批量下线 | 已创建并完成 | 已创建并通过 | 页面仅保留在线会话，接入公共页头与公共列表，状态筛选被全选替代，批量下线仍可用 | 已完成 |

### 5.2 排序依据

- 先调研现状与测试覆盖，再执行最小范围页面重构，最后做 scoped 独立验证。

## 6. 子 agent 输出摘要

### 6.1 调研子 agent

- 调研范围：`frontend/lib/pages/login_session_page.dart`、`frontend/lib/pages/user_page.dart`、`frontend/test/widgets/user_module_support_pages_test.dart` 与 `frontend/lib/widgets/` 下公共列表组件
- evidence 代记责任：主 agent，因子 agent 输出需统一沉淀到指挥官任务日志
- 关键发现：
  - 当前登录会话页为“登录日志 + 在线会话”双 Tab，登录日志与在线会话各有独立状态、加载逻辑与表格区。
  - 最适合接入的公共组件是 `CrudPageHeader`、`CrudListTableSection`、`UnifiedListTableHeaderStyle`，可直接参考 `audit_log_page.dart` 的结构。
  - 只显示在线用户的最小改法是前端固定传 `statusFilter: 'active'`，移除状态筛选下拉，并补“全选当前页”能力以配合批量强制下线。
- 风险提示：
  - 现有 `user_module_support_pages_test.dart` 明确覆盖“登录日志”标签与旧权限分支，重构后必须同步更新，否则必然回归失败。

### 6.2 执行子 agent

#### 原子任务 1：登录会话页收敛为在线会话

- 处理范围：`frontend/lib/pages/login_session_page.dart`、`frontend/lib/pages/user_page.dart`、`frontend/test/widgets/user_module_support_pages_test.dart`
- 核心改动：
  - `frontend/lib/pages/login_session_page.dart`：删除登录日志相关状态、加载与 UI；页面重构为单一在线会话页；接入 `CrudPageHeader`、`CrudListTableSection` 与统一表头样式；固定以 `statusFilter: 'active'` 请求；移除状态筛选控件，并新增“全选当前页”能力以服务批量强制下线。
  - `frontend/lib/pages/user_page.dart`：删除 `canViewLoginLogs` 旧权限 getter 与透传逻辑，仅保留在线会话查看/强制下线能力。
  - `frontend/test/widgets/user_module_support_pages_test.dart`：移除“登录日志”相关旧断言；新增“不显示登录日志”“显示全选当前页”“在线会话请求固定带 active 过滤”等断言，并保留无权限不发请求场景。
- 执行子 agent 自测：
  - `flutter analyze lib/pages/login_session_page.dart lib/pages/user_page.dart test/widgets/user_module_support_pages_test.dart`：通过，`No issues found!`
  - `flutter test test/widgets/user_module_support_pages_test.dart --plain-name "login session page renders"`：通过，`All tests passed!`
- 未决项：无

## 7. 验证结果

### 7.1 验证结论总览

| 原子任务 | 验证命令 | 结果 | 结论 | 验证子 agent 备注 |
| --- | --- | --- | --- | --- |
| 登录会话页收敛为在线会话 | `flutter analyze lib/pages/login_session_page.dart lib/pages/user_page.dart test/widgets/user_module_support_pages_test.dart`；`flutter test test/widgets/user_module_support_pages_test.dart --plain-name "login session page renders"` | 通过 | 通过 | 首轮验证受全工作区并行改动影响未直接放行，完成 scoped 复检后通过 |

### 7.2 详细验证留痕

- `git diff -- frontend/lib/pages/login_session_page.dart frontend/lib/pages/user_page.dart frontend/test/widgets/user_module_support_pages_test.dart`：确认登录日志相关状态、Tab 与 UI 已被删除，在线会话页已接入公共组件并新增“全选当前页”。
- `flutter analyze lib/pages/login_session_page.dart lib/pages/user_page.dart test/widgets/user_module_support_pages_test.dart`：通过，`No issues found!`
- `flutter test test/widgets/user_module_support_pages_test.dart --plain-name "login session page renders"`：通过，目标测试通过。
- 最后验证日期：2026-03-24

## 8. 失败重试记录

### 8.1 重试轮次

| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 登录会话页收敛为在线会话 | 首轮独立验证未通过 | 验证子 agent 将全工作区其他并行改动纳入范围门禁，导致无法直接判定“仅本任务文件变更” | 重派执行子 agent 做 scoped 收口复核，确认无需继续改代码；再派发新的独立验证子 agent 仅按本任务文件做复检 | 通过 |

### 8.2 收口结论

- 首轮失败并非登录会话页实现缺陷，而是范围门禁未剥离并行在制改动；经 scoped 收口复核与新的独立验证后，本任务通过。

## 9. 实际改动

- `evidence/commander_execution_20260324_login_session_online_only.md`：建立并更新本轮指挥官任务日志。
- `frontend/lib/pages/login_session_page.dart`：将登录会话页收敛为仅在线会话，并接入公共页面/公共列表组件。
- `frontend/lib/pages/user_page.dart`：收敛旧登录日志权限透传，仅保留在线会话相关能力。
- `frontend/test/widgets/user_module_support_pages_test.dart`：同步页面行为与请求参数断言，覆盖在线会话收敛后的核心交互。

## 10. 工具降级、硬阻塞与限制

### 10.1 工具降级记录

- 不可用工具：`Sequential Thinking`、`update_plan`
- 降级原因：当前会话未提供对应工具
- 触发时间：2026-03-24 15:43
- 替代工具或替代流程：书面拆解 + `TodoWrite` + 指挥官任务日志持续留痕 + `Task` 子 agent 闭环
- 影响范围：无法使用原生顺序思考 MCP 与计划工具记录过程
- 补偿措施：在 `evidence/` 中记录任务拆分、验收标准、执行摘要、验证结论与失败重试

### 10.2 evidence 代记说明

- 代记责任人：主 agent
- 代记原因：子 agent 输出需统一沉淀到指挥官任务日志
- 代记内容范围：调研摘要、执行摘要、验证结果、失败重试与最终结论

### 10.3 硬阻塞

- 阻塞项：无
- 已尝试动作：无
- 当前影响：无
- 建议动作：无

### 10.4 已知限制

- 本轮只按用户要求重构登录会话页前端，不处理后端接口裁撤与菜单/权限之外的更大范围清理。
- 工作区当前存在其他并行在制改动；本轮最终验证已按 scoped 文件与最小必要命令完成，不将其视为本任务失败条件。

## 11. 交付判断

- 已完成项：
  - 建立任务日志
  - 明确本轮范围与验收标准
  - 完成现状调研
  - 完成代码修改
  - 完成一轮收口复核与 scoped 独立复检
- 未完成项：
  - 无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 12. 输出文件

- `evidence/commander_execution_20260324_login_session_online_only.md`

## 13. 迁移说明

- 无迁移，直接替换。

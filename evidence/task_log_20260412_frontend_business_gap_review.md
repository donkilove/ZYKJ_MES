# 任务日志：前端业务代码缺口与优化盘点

- 日期：2026-04-12
- 执行人：Codex
- 当前状态：已完成
- 指挥模式：单 agent 调研与复核（受当前更高优先级约束，本轮不启用子 agent，采用分阶段检索与独立命令复核补偿）

## 1. 输入来源
- 用户指令：查看项目前端的业务代码，判断当前前端还缺哪些功能或优化。
- 需求基线：`AGENTS.md`、`docs/AGENTS/*.md`、`frontend/`
- 代码范围：`frontend/lib`、`frontend/integration_test`、`frontend/test`

## 1.1 前置说明
- 默认主线工具：`MCP_DOCKER Sequential Thinking`、`MCP_DOCKER ast-grep`、宿主文件工具、宿主安全命令
- 缺失工具：无
- 缺失/降级原因：无
- 替代工具：无
- 影响范围：无

## 2. 任务目标、范围与非目标
### 任务目标
1. 识别前端当前已实现的业务覆盖面与主要模块边界。
2. 基于代码证据判断当前仍缺失的功能闭环与值得优先优化的方向。
3. 形成可追溯的分析结论并同步留痕。

### 任务范围
1. Flutter 前端业务代码、页面入口、状态与服务调用。
2. 前端测试与集成测试覆盖情况。
3. 本次分析任务相关 `evidence/` 留痕。

### 非目标
1. 不在本轮直接修改业务代码。
2. 不对后端实现做完整审计，只在前端业务判断需要时做少量关联引用。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 根 `AGENTS.md` 与 `docs/AGENTS/*.md` 阅读结果 | 2026-04-12 | 本轮需以前端业务盘点为目标，保持中文留痕、计划维护与 evidence 闭环 | Codex |
| E2 | `MCP_DOCKER Sequential Thinking` 三步拆解 | 2026-04-12 | 已明确本轮分析路径、任务分类与输出结构 | Codex |
| E3 | `frontend/`、`frontend/lib/`、`frontend/integration_test/` 目录扫描 | 2026-04-12 | 前端以 Flutter 组织，存在业务模块、服务层与两条大型集成测试主线 | Codex |
| E4 | `frontend/lib/features/shell/presentation/home_page.dart` | 2026-04-12 | 首页已具备欢迎卡与快速跳转，但尚未承载业务 KPI、待办、异常告警与个性化工作台能力 | Codex |
| E5 | `frontend/lib/features/misc/presentation/login_page.dart`、`frontend/lib/main.dart`、`frontend/lib/core/services/session_store.dart` | 2026-04-12 | 登录页公告为静态常量，且启动时强制清空会话；已具备 `SessionStore` 能力但未实际用于免登录或会话恢复 | Codex |
| E6 | `frontend/lib/features/shell/presentation/main_shell_page.dart`、`frontend/lib/features/message/presentation/message_center_page.dart`、`frontend/lib/features/production/presentation/production_order_query_page.dart` | 2026-04-12 | 主壳与子页面存在多路定时轮询，且主壳使用 `IndexedStack` 承载模块页，存在后台轮询和首屏预建成本偏高的风险 | Codex |
| E7 | `frontend/lib/core/widgets/simple_pagination_bar.dart` | 2026-04-12 | 通用分页仅支持上一页/下一页，不支持页码跳转、页大小切换与快速定位，不利于大表格业务查询 | Codex |
| E8 | 大文件统计：`frontend/lib/features/user/presentation/user_management_page.dart`、`frontend/lib/features/craft/presentation/process_configuration_page.dart`、`frontend/lib/features/product/presentation/product_management_page.dart`、`frontend/lib/features/message/presentation/message_center_page.dart` | 2026-04-12 | 多个关键页面达到 1700 至 3000 行，页面、弹窗、状态与服务耦合度偏高，后续迭代和回归风险较大 | Codex |
| E9 | `frontend/lib/core/services/export_file_service.dart` 与多个产品/生产页面导出实现；多模块 service 中大量 `http.*` 调用 | 2026-04-12 | 导出与请求层存在重复实现，尚未形成统一的 API 客户端、错误恢复与导出能力复用 | Codex |
| E10 | `frontend/integration_test/home_shell_flow_test.dart`、`frontend/integration_test/login_flow_test.dart`；缺少同名 widget 测试的重页面清单 | 2026-04-12 | 集成测试集中在两份 2400+ 行大脚本，且若干复杂页面缺少直接 widget 测试，测试可维护性与定位粒度仍可提升 | Codex |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 规则装配与启动留痕 | 完成规则读取、计划维护与日志建立 | 不启用 | 不启用 | 规则、计划、日志齐备 | 已完成 |
| 2 | 前端结构盘点 | 识别模块、入口、状态、服务与测试边界 | 不启用 | 不启用 | 形成可引用的目录与代码地图 | 已完成 |
| 3 | 业务缺口判断 | 归纳缺失功能与优化项并给出依据 | 不启用 | 不启用 | 结论具备文件级依据与优先级 | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：无
- 执行摘要：已完成规则装配、Sequential Thinking、前端模块梳理、关键页面抽样、服务层与测试覆盖抽检。
- 验证摘要：通过结构检索、文件阅读、页面规模统计、测试文件盘点与关键代码行号定位完成交叉复核。

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 无 | 无 | 无 | 无 | 无 |

## 7. 工具降级、硬阻塞与限制
- 默认 `MCP_DOCKER` 主线：`MCP_DOCKER Sequential Thinking`、`MCP_DOCKER ast-grep`
- 不可用工具：无
- 降级原因：无
- 替代流程：无
- 影响范围：无
- 补偿措施：因未获用户授权启用子 agent，采用本地分阶段检索、交叉文件复核与测试覆盖抽检作为执行/验证分离补偿
- 硬阻塞：无

## 8. 交付判断
- 已完成项：
  1. 梳理了当前前端业务版图：用户、产品、设备、生产、品质、工艺、消息、登录/注册与主壳权限导航均已具备页面与服务层实现。
  2. 识别出优先级最高的功能缺口：首页工作台缺业务驾驶舱、登录入口缺动态公告与会话恢复。
  3. 识别出优先级最高的优化项：轮询治理与懒加载、分页能力增强、重页面拆分、统一请求层与导出复用、测试拆分与补盲。
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 8.1 分析结论
### 已具备的前端能力
1. 主壳已完成基于页面目录与权限快照的模块导航，支持首页、用户、产品、设备、生产、品质、工艺与消息入口。
2. 多个模块已具备较完整的业务闭环，例如消息驱动跳转、产品版本/参数管理、生产订单查询与详情、品质趋势图表、设备保养执行与工艺引用分析。
3. `widget_test` 与 service/model 测试基础较全，说明当前前端并非空壳，而是进入“体验与可维护性继续打磨”的阶段。

### 仍缺的业务功能
1. 首页工作台缺少真正的业务驾驶舱能力，仅展示欢迎信息和快速跳转；建议补上我的待办、待审批、异常工单、未读高优先级消息、核心 KPI 与最近操作入口。
2. 登录页缺少动态化入口内容，当前公告与更新时间均为前端硬编码；建议改为读取真实公告/运维通知，并区分系统公告、业务提醒、个人待办。
3. 会话恢复能力缺失，虽然已具备 `SessionStore.save/load`，但启动流程只执行 `clear()`；建议补上记住登录态、失效后回跳登录、密码变更后的明确回收策略。

### 优先优化项
1. 性能与运行态：主壳与子页面存在多路 `Timer.periodic` 轮询，建议统一为可见时轮询、隐藏时暂停，优先使用 WebSocket/手动刷新补齐，避免进入主壳后后台持续拉取。
2. 列表体验：通用分页条只有上一页/下一页，不支持页码跳转、页大小切换和快速定位；对订单、产品、审计等大列表影响明显。
3. 可维护性：多个关键页面体量过大，建议拆为页面容器、筛选区、表格区、弹窗区、表单状态控制器和导出/跳转协调器。
4. 基础设施：请求层仍以各 service 直接 `http.*` 为主，导出逻辑也分散在多个页面；建议统一鉴权头、错误解析、重试/超时与文件导出能力。
5. 测试体系：`integration_test` 只有两份超大脚本，建议按模块拆分；同时补齐复杂页面的直接 widget 测试，例如功能权限配置、产品管理、角色管理、审计日志等。

## 8.2 验证留痕
1. 结构盘点：读取 `frontend/lib/features`、`frontend/test`、`frontend/integration_test`，确认业务模块与测试边界。
2. 代码抽样：读取主壳、首页、登录、消息中心、用户/产品/生产/质量/设备/工艺总页与代表性业务页。
3. 工程抽检：统计前端最大 Dart 文件行数，核对请求层 `http.*` 分布、导出逻辑分布、轮询定时器分布与分页组件能力边界。
4. 测试抽检：核对集成测试用例名称与复杂页面的直接测试覆盖情况。

## 9. 迁移说明
- 无迁移，直接替换。

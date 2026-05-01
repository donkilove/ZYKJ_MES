# 指挥官执行任务日志

## 1. 任务信息

- 任务名称：对照 `docs/功能规划V1` 各模块需求，持续补全 MES 前后端并循环验证直至收口
- 执行日期：2026-03-21
- 执行方式：指挥官拆解 + 子 agent 调研 + 子 agent 实施 + 子 agent 验证 + 全量复查
- 当前状态：已完成
- 指挥模式：主 agent 拆解调度，子 agent 执行，独立子 agent 验证

## 2. 输入来源

- 用户指令：使用指挥官模式，按照 `docs` 文件夹中的各模块需求说明，对前端/后端各模块进行补全并建造完整工作流程，所有模块测试通过后再次检查 MES 系统并生成检查报告；若不合格则继续整改，重复该流程直到各模块满足需求说明文档。
- 需求基线：
  - `docs/功能规划V1/用户模块/用户模块需求说明.md`
  - `docs/功能规划V1/产品模块/产品模块需求说明.md`
  - `docs/功能规划V1/工艺模块/工艺模块需求说明.md`
  - `docs/功能规划V1/设备模块/设备模块需求说明.md`
  - `docs/功能规划V1/品质模块/品质模块需求说明.md`
  - `docs/功能规划V1/生产模块/生产模块需求说明.md`
  - `docs/功能规划V1/消息模块/消息模块需求说明.md`
- 代码范围：
  - `backend/`
  - `frontend/`
- 参考证据：
  - `docs/功能规划V1深度审查-20260318/`
  - `docs/功能规划V1复审-20260319/`
  - `evidence/commander_execution_20260321.md`
  - `evidence/continuous_improvement_run_20260321.md`
  - `evidence/continuous_improvement_queue_20260321.csv`

## 3. 目标、范围与非目标

### 3.1 本轮目标

1. 重新对照 7 个模块需求说明，形成当前缺口与原子整改任务清单。
2. 按指挥官模式循环派发执行与验证子 agent，持续整改直到模块级验收通过。
3. 在全部模块通过定向验证后，再执行系统级复查并输出检查报告。

### 3.2 本轮范围

1. `backend/`、`frontend/` 中与 7 个模块相关的模型、接口、服务、页面、测试、文档。
2. `docs/` 与 `evidence/` 中与需求对照、任务拆解、验证留痕、检查报告相关的文档资产。

### 3.3 非目标

1. 不做与需求说明无关的风格性重构。
2. 不修改用户未要求的基础设施、部署体系与额外安全设计。

## 4. 指挥拆解结果

### 4.1 原子任务清单

| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 全模块现状调研 | 形成 7 个模块的当前缺口、优先级与候选原子任务 | 待创建 | 待创建 | 每个模块都有可回溯证据、缺口分级与建议验证命令 | 进行中 |
| 2 | 用户模块收口批次 | 修复用户模块剩余需求缺口并通过回归 | 已执行 2 轮 | 已验证 2 轮 | 用户模块需求对应页面/接口/测试通过 | 已完成 |
| 3 | 生产模块收口批次 | 修复生产模块剩余需求缺口并通过回归 | 已执行 2 轮 | 已验证 2 轮 | 生产模块需求对应页面/接口/测试通过 | 已完成 |
| 4 | 品质模块收口批次 | 修复品质模块剩余需求缺口并通过回归 | 已执行 5 轮 | 已验证 5 轮 | 品质模块需求对应页面/接口/测试通过 | 已完成 |
| 5 | 消息模块收口批次 | 修复消息模块剩余需求缺口并通过回归 | 已执行 5 轮 | 已验证 5 轮 | 消息模块需求对应页面/接口/测试通过 | 已完成 |
| 6 | 产品模块收口批次 | 修复产品模块剩余需求缺口并通过回归 | 已执行 6 轮 | 已验证 6 轮 | 产品模块需求对应页面/接口/测试通过 | 已完成 |
| 7 | 工艺模块收口批次 | 修复工艺模块剩余需求缺口并通过回归 | 已执行 3 轮 | 已验证 3 轮 | 工艺模块需求对应页面/接口/测试通过 | 已完成 |
| 8 | 设备模块收口批次 | 修复设备模块剩余需求缺口并通过回归 | 已执行 4 轮 | 已验证 4 轮 | 设备模块需求对应页面/接口/测试通过 | 已完成 |
| 9 | 系统级复查与检查报告 | 全量复查模块收口结果并输出最终检查报告 | 已执行 1 轮 | 已验证 1 轮 | 报告明确已满足/未满足项与验证证据 | 已完成 |

### 4.2 排序依据

- 先统一调研，再按缺口规模和依赖关系组织批次，避免盲改造成返工。
- 优先沿用现有审查与整改资产，减少重复调研成本。
- 以“需求闭环 + 可验证 + 风险最小”为原则决定各模块实际整改顺序。
- 2026-03-22 续跑：已完成用户/生产/品质主链，当前继续收口消息对象级跳转、产品版本参数列表、工艺引用跳转与回滚预览、设备规则/参数一体化等剩余高优任务。

## 5. 子 agent 输出摘要

### 5.1 调研子 agent（如有）

- 用户模块：剩余高优缺口为“强制下线权限仍可被非系统管理员配置”“功能权限配置页面自身能力仍暴露在能力包中”；次级缺口为会话状态展示语义和工段实时拉取时机。
- 产品模块：剩余高优缺口为“参数管理页仍非版本参数列表”“产品停用后的启用流程与需求不一致”；次级缺口为产品表单字段/校验、删除保护覆盖面。
- 工艺模块：剩余高优缺口为“引用分析未闭环到记录级跳转”“回滚前缺少目标版本专属影响预览”；次级缺口为系统母版步骤列表直出和页面级回归测试。
- 设备模块：当前无新的 P0 主链路阻断项，主要待收口项为“规则/运行参数页一体化语义”“设备详情页与执行/记录详情深度”“记录列表附件列”。
- 品质模块：剩余高优缺口为“首件详情权限链未独立”“首件处置仍缺独立页面”“不良分析/质量趋势缺少关键分析项”；次级缺口为报废统计精确筛选。
- 生产模块：剩余高优缺口为“并行实例追踪页业务化不足”“工单执行详情基础信息不完整”；次级缺口为代班审批文案与专项回归测试。
- 消息模块：剩余高优缺口为“对象级上下文跳转未全模块闭环”“公告发布/范围控制能力缺失”“消息过期生命周期未闭环”“失效原因语义过粗”。

### 5.1.2 2026-03-22 续跑调研补记（evidence 代记）

- 消息模块：品质首件对象级跳转与公告最小闭环已收口；剩余高优缺口聚焦为“代班审批消息未指向代班记录详情”“用户注册审批通过消息缺少个人中心精确落位 payload”。
- 产品模块：剩余高优缺口聚焦为“参数管理页仍以产品列表而非版本参数列表呈现”；当前版本参数读写能力已存在，但公开契约仍保留“当前参数”旧口径。
- 工艺模块：剩余高优缺口聚焦为“工艺内链 jumpTarget 仍只切模块/Tab，未承接记录级跳转”“回滚弹窗仍基于当前模板通用影响分析，而非目标版本专属预览”。
- 设备模块：剩余最小可落地缺口为“保养记录列表附件列增强”；次级缺口为“设备详情风险提示与快捷入口小步收口”；规则/运行参数页一体化语义仍属更大改动。

### 5.1.1 本轮指挥排序

1. 用户模块权限特殊规则收口
2. 生产模块低风险文案/详情/测试收口
3. 品质模块首件权限与页面闭环
4. 消息模块对象级跳转与过期生命周期
5. 产品模块版本参数列表与启停口径
6. 工艺模块回滚预览与引用跳转
7. 设备模块详情与规则页深化

### 5.2 执行子 agent

#### 原子任务：用户模块权限特殊规则收口

- 处理范围：`backend/app/core/authz_hierarchy_catalog.py`、`backend/app/services/authz_service.py`、`frontend/lib/pages/function_permission_config_page.dart`、`frontend/lib/pages/user_page.dart`
- 核心改动：
  - 为特殊能力增加“隐藏于能力包/仅特定角色可持有”机制。
  - 将 `feature.system.role_permissions.manage` 与 `feature.user.login_session.force_offline` 从能力包与角色配置界面隐藏，并保持系统管理员 guardrail。
  - 用户模块页中强制下线入口改为与系统管理员保底规则一致，不再仅依赖 capability 暴露。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/function_permission_config_page.dart lib/pages/user_page.dart test/services/authz_service_test.dart test/services/user_service_test.dart`：通过
  - `cd frontend && flutter test test/services/authz_service_test.dart test/services/user_service_test.dart`：通过
  - `.venv/bin/python -m compileall backend/app`：通过
- 未决项：无

#### 原子任务：用户模块会话展示与工段实时刷新收口

- 处理范围：`frontend/lib/pages/login_session_page.dart`、`frontend/lib/pages/user_management_page.dart`、`frontend/lib/pages/registration_approval_page.dart`、`frontend/test/widgets/user_management_page_test.dart`、`frontend/test/widgets/registration_approval_page_test.dart`
- 核心改动：
  - 在线会话主状态统一为“在线/离线”，离线颜色统一为灰色。
  - 新建用户、编辑用户、审批通过弹窗在打开时统一调用启用工段刷新逻辑。
  - 新增/更新 widget 测试锁定工段刷新行为。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/login_session_page.dart lib/pages/user_management_page.dart lib/pages/registration_approval_page.dart test/widgets/user_management_page_test.dart`：通过
  - `cd frontend && flutter test test/widgets/user_management_page_test.dart`：通过
  - `cd frontend && flutter analyze test/widgets/registration_approval_page_test.dart`：通过
- `cd frontend && flutter test test/widgets/registration_approval_page_test.dart`：通过
- 未决项：无

#### 原子任务：生产模块页面文案与执行详情收口

- 处理范围：`frontend/lib/pages/production_assist_approval_page.dart`、`frontend/lib/pages/production_order_query_detail_page.dart`、`frontend/test/widgets/production_assist_approval_page_test.dart`、`frontend/test/widgets/production_order_query_detail_page_test.dart`
- 核心改动：
  - 代班状态筛选 `approved` 文案统一为“已审批”。
  - 工单执行详情页补齐产品版本、模板名称/版本、并行模式、创建人、创建时间等基础信息。
  - 更新 widget 测试锁定文案与详情信息展示。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/production_assist_approval_page.dart lib/pages/production_order_query_detail_page.dart test/widgets/production_assist_approval_page_test.dart test/widgets/production_order_query_detail_page_test.dart`：通过
  - `cd frontend && flutter test test/widgets/production_assist_approval_page_test.dart test/widgets/production_order_query_detail_page_test.dart`：通过
- 未决项：并行实例追踪页业务化筛选与定位仍待后续批次收口。

#### 原子任务：品质模块首件详情权限链收口

- 处理范围：`backend/app/api/v1/endpoints/quality.py`、`backend/tests/test_quality_module_integration.py`、`frontend/lib/services/quality_service.dart`、`frontend/lib/pages/daily_first_article_page.dart`、`frontend/lib/pages/first_article_disposition_page.dart`、`frontend/test/services/quality_service_test.dart`、`frontend/test/services/quality_service_contract_test.dart`
- 核心改动：
  - 首件详情接口仅绑定详情权限；新增独立处置详情读取接口绑定处置权限。
  - 每日首件列表把“详情”和“处置”入口拆分，不再混合使用一个按钮。
  - 处置弹窗按模式调用不同详情读取接口，并补充前后端契约测试。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_quality_module_integration`：通过
  - `cd frontend && flutter analyze lib/services/quality_service.dart lib/pages/daily_first_article_page.dart lib/pages/first_article_disposition_page.dart test/services/quality_service_test.dart test/services/quality_service_contract_test.dart`：通过
- `cd frontend && flutter test test/services/quality_service_test.dart test/services/quality_service_contract_test.dart`：通过
- 未决项：首件处置仍为弹窗形态，独立页面闭环与分析页增强待后续批次收口。

#### 原子任务：消息模块生命周期与失效语义收口

- 处理范围：`backend/app/services/message_service.py`、`backend/app/api/v1/endpoints/messages.py`、`backend/app/schemas/message.py`、`backend/tests/test_message_module_integration.py`、`frontend/lib/models/message_models.dart`、`frontend/lib/pages/message_center_page.dart`、`frontend/test/services/message_service_test.dart`、`frontend/test/widgets/message_center_page_test.dart`
- 核心改动：
  - 过期消息在默认列表、摘要、未读数中按 `expired` 处理，不再视为有效 active。
  - 消息项新增更细失效原因：`expired`、`archived`、`no_permission`、`source_unavailable`。
  - 消息中心预览与列表改为展示更准确的失效文案。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_message_module_integration`：通过
  - `cd frontend && flutter analyze lib/models/message_models.dart lib/services/message_service.dart lib/pages/message_center_page.dart test/services/message_service_test.dart test/widgets/message_center_page_test.dart`：通过
- `cd frontend && flutter test test/services/message_service_test.dart test/widgets/message_center_page_test.dart`：通过
- 未决项：对象级 payload 跳转与公告最小管理闭环待后续批次收口。

#### 原子任务：生产模块并行实例追踪页业务化收口

- 处理范围：`backend/app/services/production_order_service.py`、`backend/app/api/v1/endpoints/production.py`、`backend/app/schemas/production.py`、`backend/tests/test_production_module_integration.py`、`frontend/lib/models/production_models.dart`、`frontend/lib/services/production_service.dart`、`frontend/lib/pages/production_pipeline_instances_page.dart`、`frontend/lib/pages/production_order_detail_page.dart`、`frontend/test/widgets/production_pipeline_instances_page_test.dart`
- 核心改动：
  - 并行实例接口与页面支持按工序关键字、实例编号筛选。
  - 列表展示改为工序名称 + 工序编码，并新增只读“查看订单”入口。
  - 补齐前后端测试覆盖并收紧生产集成测试查询条件，避免脏数据干扰。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_production_module_integration`：通过
  - `cd frontend && flutter analyze lib/models/production_models.dart lib/services/production_service.dart lib/pages/production_pipeline_instances_page.dart lib/pages/production_order_detail_page.dart test/widgets/production_pipeline_instances_page_test.dart`：通过
  - `cd frontend && flutter test test/widgets/production_pipeline_instances_page_test.dart`：通过
- 未决项：事件日志级联定位仍可后续增强，但不阻断当前生产模块批次验收。

#### 原子任务：产品模块表单字段与前端校验收口

- 处理范围：`frontend/lib/pages/product_management_page.dart`、`frontend/test/widgets/product_module_issue_regression_test.dart`
- 核心改动：
  - 新建/编辑产品弹窗补充“默认状态/当前状态”展示。
  - 补齐产品名称与备注的前端即时校验、最大长度约束与提交值 `trim`。
  - 新增 widget 回归测试锁定表单状态展示与校验行为。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/product_management_page.dart test/widgets/product_module_issue_regression_test.dart`：通过
- `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart`：通过
- 未决项：版本参数列表、启停口径与删除保护覆盖面待后续批次收口。

#### 原子任务：品质模块报废统计精确筛选收口

- 处理范围：`backend/app/services/production_repair_service.py`、`backend/app/api/v1/endpoints/production.py`、`backend/app/schemas/production.py`、`backend/tests/test_production_module_integration.py`、`frontend/lib/services/production_service.dart`、`frontend/lib/pages/production_scrap_statistics_page.dart`、`frontend/test/widgets/production_repair_scrap_pages_test.dart`
- 核心改动：
  - 报废统计列表与导出新增 `product_name`、`process_code` 精确筛选，并保证前后端同口径。
  - 页面筛选栏补充“产品名称（精确）”“工序编码（精确）”输入框。
  - 补充后端集成回归与前端 widget 回归，锁定精确筛选行为。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_production_module_integration`：通过
  - `cd frontend && flutter analyze lib/pages/production_scrap_statistics_page.dart lib/services/production_service.dart lib/models/production_models.dart test/widgets/production_repair_scrap_pages_test.dart`：通过
- `cd frontend && flutter test test/widgets/production_repair_scrap_pages_test.dart`：通过
- 未决项：首件处置独立页面、不良分析增强、质量趋势增强仍待后续批次收口。

#### 原子任务：品质模块不良分析增强收口

- 处理范围：`backend/app/services/quality_service.py`、`backend/app/schemas/quality.py`、`backend/tests/test_quality_module_integration.py`、`frontend/lib/models/quality_models.dart`、`frontend/lib/pages/quality_defect_analysis_page.dart`、`frontend/test/models/quality_models_test.dart`、`frontend/test/services/quality_service_contract_test.dart`
- 核心改动：
  - 不良分析结果新增基于 `RepairCause.reason` 的 Top 缺陷原因排行。
  - 页面新增“产品质量对比”板块，并与原“按产品分布”语义彻底分离。
  - 补充前后端契约与模型测试，锁定新字段解析与返回结构。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_quality_module_integration`：通过
  - `cd frontend && flutter analyze lib/pages/quality_defect_analysis_page.dart lib/models/quality_models.dart lib/services/quality_service.dart test/models/quality_models_test.dart test/services/quality_service_contract_test.dart`：通过
- `cd frontend && flutter test test/models/quality_models_test.dart test/services/quality_service_contract_test.dart`：通过
- 未决项：首件处置独立页面与质量趋势增强仍待后续批次收口。

#### 原子任务：品质模块首件处置独立页面收口

- 处理范围：`frontend/lib/pages/daily_first_article_page.dart`、`frontend/lib/pages/first_article_disposition_page.dart`、`frontend/test/widgets/quality_first_article_page_test.dart`
- 核心改动：
  - 每日首件列表从弹窗改为独立页面承载“详情/处置”。
  - 独立页面区分详情模式与处置模式，并在处置成功后 `pop(true)` 触发列表刷新。
  - 补充 widget 回归锁定页面跳转与返回刷新行为。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/daily_first_article_page.dart lib/pages/first_article_disposition_page.dart lib/pages/quality_page.dart test/widgets/quality_first_article_page_test.dart`：通过
  - `cd frontend && flutter test test/widgets/quality_first_article_page_test.dart`：通过
- 未决项：无

#### 原子任务：品质模块质量趋势增强收口

- 处理范围：`frontend/lib/pages/quality_trend_page.dart`、`frontend/test/widgets/quality_trend_page_test.dart`
- 核心改动：
  - 趋势页并行拉取 trend/overview/product/process/operator 五组数据，新增关键指标摘要卡。
  - 趋势图加入维修维度，并新增按产品/工序/人员维度观察区。
  - 补充 widget 回归锁定摘要卡、维度对比与维修展示。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/quality_trend_page.dart lib/models/quality_models.dart lib/services/quality_service.dart test/widgets/quality_trend_page_test.dart`：通过
- `cd frontend && flutter test test/widgets/quality_trend_page_test.dart`：通过
- 未决项：无

#### 原子任务：产品模块启停口径一致性收口

- 处理范围：`backend/app/services/product_service.py`、`backend/tests/test_product_module_integration.py`、`frontend/lib/pages/product_management_page.dart`、`frontend/lib/pages/product_version_management_page.dart`、`frontend/test/widgets/product_module_issue_regression_test.dart`
- 核心改动：
  - 杜绝 `active + effective_version=0` 灰态，停用最后一个生效版本后产品自动转为 `inactive`。
  - 生命周期 API 继续禁止从 `inactive` 直接重新启用，只能通过版本生效恢复。
  - 前端产品管理/版本管理的状态文案、提示语和默认状态展示同步收口。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_product_module_integration`：通过
  - `cd frontend && flutter analyze lib/pages/product_management_page.dart lib/pages/product_version_management_page.dart test/widgets/product_module_issue_regression_test.dart`：通过
- `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart`：通过
- 未决项：版本参数列表重构与删除保护矩阵扩展待后续批次收口。

#### 原子任务：设备模块来源快照与详情深度收口

- 处理范围：`backend/app/schemas/equipment.py`、`backend/app/api/v1/endpoints/equipment.py`、`backend/tests/test_equipment_module_integration.py`、`frontend/lib/models/equipment_models.dart`、`frontend/lib/pages/maintenance_execution_detail_page.dart`、`frontend/lib/pages/maintenance_record_detail_page.dart`、`frontend/test/models/equipment_models_test.dart`、`frontend/test/services/equipment_service_test.dart`
- 核心改动：
  - 执行详情与记录详情新增 `source_plan_summary` 单一真源字段。
  - 记录详情补齐 `source_equipment_name` 与 `source_execution_process_code`，并在页面中前置展示来源快照。
  - 补充后端 detail 回归与前端模型/服务解析回归。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_equipment_module_integration`：通过
  - `cd frontend && flutter analyze lib/models/equipment_models.dart lib/pages/maintenance_execution_detail_page.dart lib/pages/maintenance_record_detail_page.dart test/models/equipment_models_test.dart test/services/equipment_service_test.dart`：通过
- `cd frontend && flutter test test/models/equipment_models_test.dart test/services/equipment_service_test.dart`：通过
- 未决项：规则/运行参数页一体化与设备详情其它聚合增强待后续批次收口。

#### 原子任务：消息模块品质首件对象级跳转收口

- 处理范围：`backend/app/api/v1/endpoints/quality.py`、`backend/tests/test_quality_module_integration.py`、`frontend/lib/pages/main_shell_page.dart`、`frontend/lib/pages/quality_page.dart`、`frontend/lib/pages/daily_first_article_page.dart`、`frontend/test/widgets/message_center_page_test.dart`、`frontend/test/widgets/quality_first_article_page_test.dart`
- 核心改动：
  - 首件处置结果消息新增 `target_route_payload_json`，对象级指向目标首件记录。
  - `main_shell -> quality_page -> daily_first_article_page` 路由 payload 透传链路打通。
  - 每日首件页消费 payload 后自动打开目标首件详情独立页面，并避免重复消费。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_quality_module_integration`：通过
  - `cd frontend && flutter analyze lib/pages/main_shell_page.dart lib/pages/quality_page.dart lib/pages/daily_first_article_page.dart lib/pages/first_article_disposition_page.dart test/widgets/message_center_page_test.dart test/widgets/quality_first_article_page_test.dart`：通过
- `cd frontend && flutter test test/widgets/message_center_page_test.dart test/widgets/quality_first_article_page_test.dart`：通过
- 未决项：代班审批对象级跳转与公告最小闭环待后续批次收口。

#### 原子任务：工艺模块系统母版步骤主视图收口

- 处理范围：`frontend/lib/pages/process_configuration_page.dart`、`frontend/test/widgets/process_configuration_page_test.dart`
- 核心改动：
  - 工艺模板配置主页面新增只读“系统母版步骤”区块，直接展示当前系统母版完整步骤列表。
  - 页面支持服务注入，便于做页面级回归而不改变线上默认行为。
  - 补充 widget 回归，锁定主页面无需进入弹窗即可看到步骤明细。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/process_configuration_page.dart test/widgets/process_configuration_page_test.dart`：通过
- `cd frontend && flutter test test/widgets/process_configuration_page_test.dart`：通过
- 未决项：记录级跳转承接与回滚目标版本专属影响预览待后续批次收口。

#### 原子任务：产品模块版本删除保护收口

- 处理范围：`backend/app/services/product_service.py`、`backend/tests/test_product_module_integration.py`
- 核心改动：
  - 草稿版本删除前新增版本级引用检查，至少阻断被生产工单引用的版本。
  - 错误提示包含版本标签与命中工单号，语义更清晰。
  - 复用现有前端错误透传，无需额外页面改造。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_product_module_integration`：通过
  - `cd frontend && flutter analyze lib/pages/product_version_management_page.dart test/widgets/product_module_issue_regression_test.dart`：通过
- `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart`：通过
- 未决项：版本参数列表重构待后续批次收口。

#### 原子任务：消息模块公告发布最小闭环

- 处理范围：`backend/app/core/authz_catalog.py`、`backend/app/core/authz_hierarchy_catalog.py`、`backend/app/services/authz_service.py`、`backend/app/schemas/message.py`、`backend/app/services/message_service.py`、`backend/app/api/v1/endpoints/messages.py`、`backend/tests/test_message_module_integration.py`、`frontend/lib/pages/main_shell_page.dart`、`frontend/lib/pages/message_center_page.dart`、`frontend/lib/services/message_service.dart`、`frontend/lib/models/message_models.dart`、`frontend/test/widgets/message_center_page_test.dart`、`frontend/test/services/message_service_test.dart`
- 核心改动：
  - 新增公告发布动作权限与能力码，并为 system_admin 补最小保底权限。
  - 后端新增公告发布接口，支持 `all / roles / users` 三种范围并生成收件记录。
  - 消息中心新增“发布公告”按钮与最小发布弹窗，发布成功后自动刷新列表与概览。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_message_module_integration`：通过
  - `cd frontend && flutter analyze lib/pages/main_shell_page.dart lib/pages/message_center_page.dart lib/services/message_service.dart test/widgets/message_center_page_test.dart test/services/message_service_test.dart`：通过
- `cd frontend && flutter test test/widgets/message_center_page_test.dart test/services/message_service_test.dart`：通过
- 未决项：代班/用户对象级跳转仍待后续批次收口。

#### 原子任务：消息模块代班审批对象级跳转收口

- 处理范围：`backend/app/services/assist_authorization_service.py`、`backend/tests/test_message_module_integration.py`、`frontend/lib/pages/production_page.dart`、`frontend/lib/pages/production_assist_approval_page.dart`、`frontend/test/widgets/message_center_page_test.dart`、`frontend/test/widgets/production_assist_approval_page_test.dart`
- 核心改动：
  - 代班审批结果消息改为跳转 `production_assist_approval` 页签，并补对象级 payload。
  - 生产模块容器将 route payload 透传给代班记录页。
  - 代班记录页消费 payload 后自动切换筛选并打开目标审批详情。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_message_module_integration`：通过
  - `cd frontend && flutter analyze lib/pages/main_shell_page.dart lib/pages/production_page.dart lib/pages/production_assist_approval_page.dart test/widgets/message_center_page_test.dart test/widgets/production_assist_approval_page_test.dart`：通过
  - `cd frontend && flutter test test/widgets/message_center_page_test.dart test/widgets/production_assist_approval_page_test.dart`：通过
- 未决项：用户模块消息精确落位待后续批次收口。

#### 原子任务：工艺模块内链记录级跳转收口

- 处理范围：`frontend/lib/pages/craft_reference_analysis_page.dart`、`frontend/lib/pages/craft_page.dart`、`frontend/lib/pages/process_management_page.dart`、`frontend/lib/pages/process_configuration_page.dart`、`frontend/test/widgets/process_configuration_page_test.dart`
- 核心改动：
  - 工艺引用分析页的工艺内链 jumpTarget 从仅切 Tab 提升为工序/模板/版本/系统母版历史视图承接。
  - `CraftPage` 解析工艺内链参数并继续透传给目标子页。
  - 产品模式引用列表补齐跳转按钮。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/craft_reference_analysis_page.dart lib/pages/craft_page.dart lib/pages/process_management_page.dart lib/pages/process_configuration_page.dart test/widgets/process_configuration_page_test.dart`：通过
  - `cd frontend && flutter test test/widgets/process_configuration_page_test.dart`：通过
- 未决项：回滚目标版本专属影响预览待后续批次收口。

#### 原子任务：设备模块保养记录附件列增强

- 处理范围：`frontend/lib/pages/maintenance_record_page.dart`、`frontend/lib/pages/maintenance_record_detail_page.dart`、`frontend/test/widgets/maintenance_record_page_test.dart`
- 核心改动：
  - 保养记录列表附件列从静态文案改为可点击附件入口。
  - 详情页与列表页复用统一附件动作组件。
  - 新增 widget 回归覆盖有附件/无附件两种状态。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/maintenance_record_page.dart lib/pages/maintenance_record_detail_page.dart test/services/equipment_service_test.dart test/widgets/maintenance_record_page_test.dart`：通过
  - `cd frontend && flutter test test/services/equipment_service_test.dart test/widgets/maintenance_record_page_test.dart`：通过
- 未决项：设备详情风险提示与规则/参数一体化待后续批次收口。

#### 原子任务：产品模块版本参数公开契约收口

- 处理范围：`backend/app/schemas/product.py`、`backend/app/api/v1/endpoints/products.py`、`backend/tests/test_product_module_integration.py`、`frontend/lib/services/product_service.dart`、`frontend/lib/pages/product_parameter_management_page.dart`、`frontend/test/widgets/product_module_issue_regression_test.dart`
- 核心改动：
  - 后端参数接口显式返回 `parameter_scope` 与目标版本信息。
  - 参数管理页主链路改为显式版本参数/生效参数 API。
  - 二次修复后，前端服务层已切断“可空 version 隐式回退旧接口”的默认路径。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_product_module_integration`：通过
  - `cd frontend && flutter analyze lib/services/product_service.dart lib/pages/product_parameter_management_page.dart test/widgets/product_module_issue_regression_test.dart`：通过
- `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart`：通过
- 未决项：版本参数列表主视图待后续批次收口。

#### 原子任务：消息模块用户注册审批精确落位收口

- 处理范围：`backend/app/api/v1/endpoints/auth.py`、`backend/tests/test_message_module_integration.py`、`frontend/lib/pages/main_shell_page.dart`、`frontend/lib/pages/user_page.dart`、`frontend/lib/pages/account_settings_page.dart`、`frontend/test/widgets/message_center_page_test.dart`、`frontend/test/widgets/account_settings_page_test.dart`
- 核心改动：
  - 注册审批通过消息新增 `{"action":"change_password"}` payload。
  - 用户模块容器补 route payload 透传链路。
  - 账号设置页消费 payload 后自动定位到修改密码区域并避免重复触发。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_message_module_integration`：通过
  - `cd frontend && flutter analyze lib/pages/main_shell_page.dart lib/pages/user_page.dart lib/pages/account_settings_page.dart test/widgets/message_center_page_test.dart test/widgets/account_settings_page_test.dart`：通过
  - `cd frontend && flutter test test/widgets/message_center_page_test.dart test/widgets/account_settings_page_test.dart`：通过
- 未决项：无

#### 原子任务：工艺模块回滚目标版本专属影响预览收口

- 处理范围：`backend/app/schemas/craft.py`、`backend/app/services/craft_service.py`、`backend/app/api/v1/endpoints/craft.py`、`backend/tests/test_craft_module_integration.py`、`frontend/lib/models/craft_models.dart`、`frontend/lib/services/craft_service.dart`、`frontend/lib/pages/process_configuration_page.dart`、`frontend/test/widgets/process_configuration_page_test.dart`
- 核心改动：
  - impact-analysis 接口支持并返回 `target_version`。
  - 后端预览逻辑与真正 rollback dry-run 共用目标版本步骤来源。
  - 前端回滚弹窗切换目标版本时会刷新预览并回显当前预览版本。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_craft_module_integration`：通过
  - `cd frontend && flutter analyze lib/models/craft_models.dart lib/services/craft_service.dart lib/pages/process_configuration_page.dart test/widgets/process_configuration_page_test.dart`：通过
  - `cd frontend && flutter test test/widgets/process_configuration_page_test.dart`：通过
- 未决项：无

#### 原子任务：产品模块版本参数列表主视图收口

- 处理范围：`backend/app/schemas/product.py`、`backend/app/services/product_service.py`、`backend/app/api/v1/endpoints/products.py`、`backend/tests/test_product_module_integration.py`、`frontend/lib/models/product_models.dart`、`frontend/lib/services/product_service.dart`、`frontend/lib/pages/product_parameter_management_page.dart`、`frontend/lib/pages/product_page.dart`、`frontend/test/widgets/product_module_issue_regression_test.dart`
- 核心改动：
  - 后端新增版本参数列表聚合契约，参数管理页首屏改为版本维度。
  - 参数管理页行操作全部绑定当前版本行，不再回退 `product.currentVersion`。
  - 产品页入口文案与版本上下文一并收口。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_product_module_integration`：通过
  - `cd frontend && flutter analyze lib/models/product_models.dart lib/services/product_service.dart lib/pages/product_parameter_management_page.dart lib/pages/product_page.dart lib/pages/product_version_management_page.dart test/widgets/product_module_issue_regression_test.dart`：通过
  - `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart`：通过
- 未决项：无

#### 原子任务：设备模块详情风险提示与快捷入口收口

- 处理范围：`frontend/lib/pages/equipment_detail_page.dart`、`frontend/test/widgets/equipment_detail_page_test.dart`
- 核心改动：
  - 设备详情页新增更明确的风险总览卡片。
  - 新增“查看工单/查看记录/查看计划”页内快捷入口，并通过锚点滚动实现可交互跳转。
  - 补充 widget 回归锁定风险提示与快捷入口交互。
- 执行子 agent 自测：
  - `cd frontend && flutter analyze lib/pages/equipment_detail_page.dart lib/pages/equipment_ledger_page.dart test/widgets/equipment_detail_page_test.dart`：通过
- `cd frontend && flutter test test/widgets/equipment_detail_page_test.dart`：通过
- 未决项：规则/运行参数页一体化语义待后续批次收口。

#### 原子任务：设备模块规则与运行参数同范围联动收口

- 处理范围：`backend/app/services/equipment_rule_service.py`、`backend/app/api/v1/endpoints/equipment.py`、`backend/tests/test_equipment_module_integration.py`、`frontend/lib/services/equipment_service.dart`、`frontend/lib/pages/equipment_rule_parameter_page.dart`、`frontend/test/services/equipment_service_test.dart`、`frontend/test/widgets/equipment_rule_parameter_page_test.dart`
- 核心改动：
  - 运行参数列表补 `equipment_type` 过滤，并与 `equipment_id`、`is_enabled` 联合生效。
  - 规则列表新增“查看参数/配置参数”动作，可切到运行参数 Tab 并自动带入规则作用范围。
  - 页面新增“按规则作用范围查看参数”提示条与清除范围入口。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_equipment_module_integration`：通过
  - `cd frontend && flutter analyze lib/pages/equipment_rule_parameter_page.dart lib/services/equipment_service.dart test/services/equipment_service_test.dart test/widgets/equipment_rule_parameter_page_test.dart`：通过
- `cd frontend && flutter test test/services/equipment_service_test.dart test/widgets/equipment_rule_parameter_page_test.dart`：通过
- 未决项：无

#### 原子任务：系统级复查与检查报告

- 处理范围：`evidence/commander_requirement_run_20260321.md`、`evidence/commander_requirement_queue_20260321.csv`、`evidence/mes_system_check_report_20260322.md`、`backend/tests/test_*_integration.py`、`frontend/lib/`、`frontend/test/`
- 核心改动：
  - 发现系统级后端复查中生产模块集成测试与产品激活规则失配，并修复测试前置条件。
  - 重新执行后端模块集成测试组合命令、前端全量 analyze、前端全量 test。
  - 产出最终系统检查报告 `evidence/mes_system_check_report_20260322.md`。
- 执行子 agent 自测：
  - `.venv/bin/python -m unittest backend.tests.test_message_module_integration backend.tests.test_product_module_integration backend.tests.test_quality_module_integration backend.tests.test_equipment_module_integration backend.tests.test_production_module_integration backend.tests.test_craft_module_integration`：通过
  - `cd frontend && flutter analyze lib test`：通过
  - `cd frontend && flutter test`：通过
- 未决项：无

## 6. 验证结果

### 6.1 验证结论总览

| 原子任务 | 验证命令 | 结果 | 结论 | 验证子 agent 备注 |
| --- | --- | --- | --- | --- |
| 用户模块权限特殊规则收口 | `cd frontend && flutter analyze lib/pages/function_permission_config_page.dart lib/pages/user_page.dart test/services/authz_service_test.dart test/services/user_service_test.dart` | 通过 | 通过 | 隐藏能力与系统管理员保底规则已生效 |
| 用户模块权限特殊规则收口 | `cd frontend && flutter test test/services/authz_service_test.dart test/services/user_service_test.dart` | 通过 | 通过 | 前端定向测试通过 |
| 用户模块权限特殊规则收口 | `.venv/bin/python -m compileall backend/app` | 通过 | 通过 | 后端语法与导入通过 |
| 用户模块会话展示与工段实时刷新收口 | `cd frontend && flutter analyze lib/pages/login_session_page.dart lib/pages/user_management_page.dart lib/pages/registration_approval_page.dart test/widgets/user_management_page_test.dart test/widgets/registration_approval_page_test.dart` | 通过 | 通过 | 页面与测试代码静态检查通过 |
| 用户模块会话展示与工段实时刷新收口 | `cd frontend && flutter test test/widgets/user_management_page_test.dart test/widgets/registration_approval_page_test.dart` | 通过 | 通过 | 6 个 widget 测试通过 |
| 生产模块页面文案与执行详情收口 | `cd frontend && flutter analyze lib/pages/production_assist_approval_page.dart lib/pages/production_order_query_detail_page.dart test/widgets/production_assist_approval_page_test.dart test/widgets/production_order_query_detail_page_test.dart` | 通过 | 通过 | 代班文案与详情信息展示校验通过 |
| 生产模块页面文案与执行详情收口 | `cd frontend && flutter test test/widgets/production_assist_approval_page_test.dart test/widgets/production_order_query_detail_page_test.dart` | 通过 | 通过 | 4 个 widget 测试通过 |
| 品质模块首件详情权限链收口 | `.venv/bin/python -m unittest backend.tests.test_quality_module_integration` | 通过 | 通过 | 权限隔离与既有回归通过 |
| 品质模块首件详情权限链收口 | `cd frontend && flutter analyze lib/services/quality_service.dart lib/pages/daily_first_article_page.dart lib/pages/first_article_disposition_page.dart test/services/quality_service_test.dart test/services/quality_service_contract_test.dart` | 通过 | 通过 | 前端服务与页面分析通过 |
| 品质模块首件详情权限链收口 | `cd frontend && flutter test test/services/quality_service_test.dart test/services/quality_service_contract_test.dart` | 通过 | 通过 | 服务与契约测试通过 |
| 消息模块生命周期与失效语义收口 | `.venv/bin/python -m unittest backend.tests.test_message_module_integration` | 通过 | 通过 | 过期消息与失效原因回归通过 |
| 消息模块生命周期与失效语义收口 | `cd frontend && flutter analyze lib/models/message_models.dart lib/services/message_service.dart lib/pages/message_center_page.dart test/services/message_service_test.dart test/widgets/message_center_page_test.dart` | 通过 | 通过 | 前端模型/页面/测试静态检查通过 |
| 消息模块生命周期与失效语义收口 | `cd frontend && flutter test test/services/message_service_test.dart test/widgets/message_center_page_test.dart` | 通过 | 通过 | 消息服务与页面测试通过 |
| 生产模块并行实例追踪页业务化收口 | `.venv/bin/python -m unittest backend.tests.test_production_module_integration` | 通过 | 通过 | 并行实例筛选与生产回归通过 |
| 生产模块并行实例追踪页业务化收口 | `cd frontend && flutter analyze lib/models/production_models.dart lib/services/production_service.dart lib/pages/production_pipeline_instances_page.dart lib/pages/production_order_detail_page.dart test/widgets/production_pipeline_instances_page_test.dart` | 通过 | 通过 | 前端模型/页面/测试静态检查通过 |
| 生产模块并行实例追踪页业务化收口 | `cd frontend && flutter test test/widgets/production_pipeline_instances_page_test.dart` | 通过 | 通过 | 并行实例页面测试通过 |
| 产品模块表单字段与前端校验收口 | `cd frontend && flutter analyze lib/pages/product_management_page.dart test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 产品表单页面与测试静态检查通过 |
| 产品模块表单字段与前端校验收口 | `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 7 个 widget 测试通过 |
| 品质模块报废统计精确筛选收口 | `.venv/bin/python -m unittest backend.tests.test_production_module_integration` | 通过 | 通过 | 报废统计精确筛选后端回归通过 |
| 品质模块报废统计精确筛选收口 | `cd frontend && flutter analyze lib/pages/production_scrap_statistics_page.dart lib/services/production_service.dart lib/models/production_models.dart test/widgets/production_repair_scrap_pages_test.dart` | 通过 | 通过 | 报废统计页面与服务静态检查通过 |
| 品质模块报废统计精确筛选收口 | `cd frontend && flutter test test/widgets/production_repair_scrap_pages_test.dart` | 通过 | 通过 | 报废统计页面测试通过 |
| 品质模块不良分析增强收口 | `.venv/bin/python -m unittest backend.tests.test_quality_module_integration` | 通过 | 通过 | 不良分析增强后端回归通过 |
| 品质模块不良分析增强收口 | `cd frontend && flutter analyze lib/pages/quality_defect_analysis_page.dart lib/models/quality_models.dart lib/services/quality_service.dart test/models/quality_models_test.dart test/services/quality_service_contract_test.dart` | 通过 | 通过 | 不良分析页面与模型/服务静态检查通过 |
| 品质模块不良分析增强收口 | `cd frontend && flutter test test/models/quality_models_test.dart test/services/quality_service_contract_test.dart` | 通过 | 通过 | 不良分析模型与契约测试通过 |
| 品质模块首件处置独立页面收口 | `cd frontend && flutter analyze lib/pages/daily_first_article_page.dart lib/pages/first_article_disposition_page.dart lib/pages/quality_page.dart test/widgets/quality_first_article_page_test.dart` | 通过 | 通过 | 首件独立页面静态检查通过 |
| 品质模块首件处置独立页面收口 | `cd frontend && flutter test test/widgets/quality_first_article_page_test.dart` | 通过 | 通过 | 首件独立页面 widget 测试通过 |
| 品质模块质量趋势增强收口 | `cd frontend && flutter analyze lib/pages/quality_trend_page.dart lib/models/quality_models.dart lib/services/quality_service.dart test/widgets/quality_trend_page_test.dart` | 通过 | 通过 | 质量趋势增强静态检查通过 |
| 品质模块质量趋势增强收口 | `cd frontend && flutter test test/widgets/quality_trend_page_test.dart` | 通过 | 通过 | 质量趋势增强 widget 测试通过 |
| 产品模块启停口径一致性收口 | `.venv/bin/python -m unittest backend.tests.test_product_module_integration` | 通过 | 通过 | 产品启停联动后端回归通过 |
| 产品模块启停口径一致性收口 | `cd frontend && flutter analyze lib/pages/product_management_page.dart lib/pages/product_version_management_page.dart test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 产品管理/版本管理静态检查通过 |
| 产品模块启停口径一致性收口 | `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 产品模块 widget 回归通过 |
| 设备模块来源快照与详情深度收口 | `.venv/bin/python -m unittest backend.tests.test_equipment_module_integration` | 通过 | 通过 | 设备详情来源快照后端回归通过 |
| 设备模块来源快照与详情深度收口 | `cd frontend && flutter analyze lib/models/equipment_models.dart lib/pages/maintenance_execution_detail_page.dart lib/pages/maintenance_record_detail_page.dart test/models/equipment_models_test.dart test/services/equipment_service_test.dart` | 通过 | 通过 | 设备模型/详情页静态检查通过 |
| 设备模块来源快照与详情深度收口 | `cd frontend && flutter test test/models/equipment_models_test.dart test/services/equipment_service_test.dart` | 通过 | 通过 | 设备模型/服务测试通过 |
| 消息模块品质首件对象级跳转收口 | `.venv/bin/python -m unittest backend.tests.test_quality_module_integration` | 通过 | 通过 | 首件消息 payload 后端回归通过 |
| 消息模块品质首件对象级跳转收口 | `cd frontend && flutter analyze lib/pages/main_shell_page.dart lib/pages/quality_page.dart lib/pages/daily_first_article_page.dart lib/pages/first_article_disposition_page.dart test/widgets/message_center_page_test.dart test/widgets/quality_first_article_page_test.dart` | 通过 | 通过 | 消息到品质页跳转链路静态检查通过 |
| 消息模块品质首件对象级跳转收口 | `cd frontend && flutter test test/widgets/message_center_page_test.dart test/widgets/quality_first_article_page_test.dart` | 通过 | 通过 | 消息对象级跳转 widget 测试通过 |
| 工艺模块系统母版步骤主视图收口 | `cd frontend && flutter analyze lib/pages/process_configuration_page.dart test/widgets/process_configuration_page_test.dart` | 通过 | 通过 | 工艺主页面系统母版步骤静态检查通过 |
| 工艺模块系统母版步骤主视图收口 | `cd frontend && flutter test test/widgets/process_configuration_page_test.dart` | 通过 | 通过 | 工艺系统母版步骤 widget 测试通过 |
| 产品模块版本删除保护收口 | `.venv/bin/python -m unittest backend.tests.test_product_module_integration` | 通过 | 通过 | 产品版本删除保护后端回归通过 |
| 产品模块版本删除保护收口 | `cd frontend && flutter analyze lib/pages/product_version_management_page.dart test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 产品版本管理静态检查通过 |
| 产品模块版本删除保护收口 | `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 产品模块回归测试通过 |
| 消息模块公告发布最小闭环 | `.venv/bin/python -m unittest backend.tests.test_message_module_integration` | 通过 | 通过 | 公告发布后端回归通过 |
| 消息模块公告发布最小闭环 | `cd frontend && flutter analyze lib/pages/main_shell_page.dart lib/pages/message_center_page.dart lib/services/message_service.dart test/widgets/message_center_page_test.dart test/services/message_service_test.dart` | 通过 | 通过 | 公告发布前端静态检查通过 |
| 消息模块公告发布最小闭环 | `cd frontend && flutter test test/widgets/message_center_page_test.dart test/services/message_service_test.dart` | 通过 | 通过 | 公告发布前端测试通过 |
| 消息模块代班审批对象级跳转收口 | `.venv/bin/python -m unittest backend.tests.test_message_module_integration` | 通过 | 通过 | 代班审批消息 payload 回归通过 |
| 消息模块代班审批对象级跳转收口 | `cd frontend && flutter analyze lib/pages/main_shell_page.dart lib/pages/production_page.dart lib/pages/production_assist_approval_page.dart test/widgets/message_center_page_test.dart test/widgets/production_assist_approval_page_test.dart` | 通过 | 通过 | 代班审批对象级跳转静态检查通过 |
| 消息模块代班审批对象级跳转收口 | `cd frontend && flutter test test/widgets/message_center_page_test.dart test/widgets/production_assist_approval_page_test.dart` | 通过 | 通过 | 代班审批对象级跳转 widget 测试通过 |
| 工艺模块内链记录级跳转收口 | `cd frontend && flutter analyze lib/pages/craft_reference_analysis_page.dart lib/pages/craft_page.dart lib/pages/process_management_page.dart lib/pages/process_configuration_page.dart test/widgets/process_configuration_page_test.dart` | 通过 | 通过 | 工艺内链记录级跳转静态检查通过 |
| 工艺模块内链记录级跳转收口 | `cd frontend && flutter test test/widgets/process_configuration_page_test.dart` | 通过 | 通过 | 工艺内链记录级跳转 widget 测试通过 |
| 设备模块保养记录附件列增强 | `cd frontend && flutter analyze lib/pages/maintenance_record_page.dart lib/pages/maintenance_record_detail_page.dart test/services/equipment_service_test.dart test/widgets/maintenance_record_page_test.dart` | 通过 | 通过 | 保养记录附件列增强静态检查通过 |
| 设备模块保养记录附件列增强 | `cd frontend && flutter test test/services/equipment_service_test.dart test/widgets/maintenance_record_page_test.dart` | 通过 | 通过 | 保养记录附件列增强测试通过 |
| 产品模块版本参数公开契约收口 | `.venv/bin/python -m unittest backend.tests.test_product_module_integration` | 不通过 | 不通过 | 首次验证发现前端服务层仍保留可空 version 回退旧接口 |
| 产品模块版本参数公开契约收口（二次修复） | `.venv/bin/python -m unittest backend.tests.test_product_module_integration` | 通过 | 通过 | 二次修复后后端单测继续通过 |
| 产品模块版本参数公开契约收口（二次修复） | `cd frontend && flutter analyze lib/services/product_service.dart lib/pages/product_parameter_management_page.dart test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 二次修复后前端静态检查通过 |
| 产品模块版本参数公开契约收口（二次修复） | `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 二次修复后前端回归通过 |
| 消息模块用户注册审批精确落位收口 | `.venv/bin/python -m unittest backend.tests.test_message_module_integration` | 通过 | 通过 | 用户消息对象级 payload 回归通过 |
| 消息模块用户注册审批精确落位收口 | `cd frontend && flutter analyze lib/pages/main_shell_page.dart lib/pages/user_page.dart lib/pages/account_settings_page.dart test/widgets/message_center_page_test.dart test/widgets/account_settings_page_test.dart` | 通过 | 通过 | 用户模块精确落位静态检查通过 |
| 消息模块用户注册审批精确落位收口 | `cd frontend && flutter test test/widgets/message_center_page_test.dart test/widgets/account_settings_page_test.dart` | 通过 | 通过 | 用户模块精确落位 widget 测试通过 |
| 工艺模块回滚目标版本专属影响预览收口 | `.venv/bin/python -m unittest backend.tests.test_craft_module_integration` | 通过 | 通过 | 工艺回滚目标版本预览后端回归通过 |
| 工艺模块回滚目标版本专属影响预览收口 | `cd frontend && flutter analyze lib/models/craft_models.dart lib/services/craft_service.dart lib/pages/process_configuration_page.dart test/widgets/process_configuration_page_test.dart` | 通过 | 通过 | 工艺回滚预览前端静态检查通过 |
| 工艺模块回滚目标版本专属影响预览收口 | `cd frontend && flutter test test/widgets/process_configuration_page_test.dart` | 通过 | 通过 | 工艺回滚预览 widget 测试通过 |
| 产品模块版本参数列表主视图收口 | `.venv/bin/python -m unittest backend.tests.test_product_module_integration` | 通过 | 通过 | 产品版本参数列表后端回归通过 |
| 产品模块版本参数列表主视图收口 | `cd frontend && flutter analyze lib/models/product_models.dart lib/services/product_service.dart lib/pages/product_parameter_management_page.dart lib/pages/product_page.dart lib/pages/product_version_management_page.dart test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 产品版本参数列表前端静态检查通过 |
| 产品模块版本参数列表主视图收口 | `cd frontend && flutter test test/widgets/product_module_issue_regression_test.dart` | 通过 | 通过 | 产品版本参数列表 widget 回归通过 |
| 设备模块详情风险提示与快捷入口收口 | `cd frontend && flutter analyze lib/pages/equipment_detail_page.dart lib/pages/equipment_ledger_page.dart test/widgets/equipment_detail_page_test.dart` | 通过 | 通过 | 设备详情风险提示静态检查通过 |
| 设备模块详情风险提示与快捷入口收口 | `cd frontend && flutter test test/widgets/equipment_detail_page_test.dart` | 通过 | 通过 | 设备详情风险提示 widget 测试通过 |
| 设备模块规则与运行参数同范围联动收口 | `.venv/bin/python -m unittest backend.tests.test_equipment_module_integration` | 通过 | 通过 | 设备规则/参数同范围过滤后端回归通过 |
| 设备模块规则与运行参数同范围联动收口 | `cd frontend && flutter analyze lib/pages/equipment_rule_parameter_page.dart lib/services/equipment_service.dart test/services/equipment_service_test.dart test/widgets/equipment_rule_parameter_page_test.dart` | 通过 | 通过 | 设备规则/参数联动静态检查通过 |
| 设备模块规则与运行参数同范围联动收口 | `cd frontend && flutter test test/services/equipment_service_test.dart test/widgets/equipment_rule_parameter_page_test.dart` | 通过 | 通过 | 设备规则/参数联动测试通过 |
| 系统级复查与检查报告 | `.venv/bin/python -m unittest backend.tests.test_message_module_integration backend.tests.test_product_module_integration backend.tests.test_quality_module_integration backend.tests.test_equipment_module_integration backend.tests.test_production_module_integration backend.tests.test_craft_module_integration` | 通过 | 通过 | 后端模块集成测试全量复查通过 |
| 系统级复查与检查报告 | `cd frontend && flutter analyze lib test` | 通过 | 通过 | 前端全量静态检查通过 |
| 系统级复查与检查报告 | `cd frontend && flutter test` | 通过 | 通过 | 前端全量测试通过 |

### 6.2 详细验证留痕

- 用户模块权限特殊规则收口：独立验证确认两个目标能力已从能力包/角色配置返回中隐藏，且系统管理员 guardrail 保留。
- 用户模块会话展示与工段实时刷新收口：独立验证确认会话主状态为“在线/离线”，且三类弹窗打开前均显式刷新启用工段。
- 生产模块页面文案与执行详情收口：独立验证确认 `approved` 文案为“已审批”，且工单执行详情页已展示补充的基础信息。
- 品质模块首件详情权限链收口：独立验证确认详情接口与处置详情接口权限分离，且每日首件列表入口语义已拆分。
- 消息模块生命周期与失效语义收口：独立验证确认过期消息不计入默认 active 统计，且前后端已支持更细失效原因展示。
- 生产模块并行实例追踪页业务化收口：独立验证确认工序关键字/实例编号筛选、工序业务化展示与只读订单详情入口均已生效。
- 产品模块表单字段与前端校验收口：独立验证确认新建/编辑弹窗状态展示、即时校验与 `trim` 提交逻辑均已生效。
- 品质模块报废统计精确筛选收口：独立验证确认列表与导出同口径支持产品名称、工序编码精确筛选，且页面筛选栏已可用。
- 品质模块不良分析增强收口：独立验证确认后端已返回 Top 缺陷原因，且页面已补“产品质量对比”并与“按产品分布”分离。
- 品质模块首件处置独立页面收口：独立验证确认每日首件列表已改为独立页面承载详情/处置，且处置成功返回会触发刷新。
- 品质模块质量趋势增强收口：独立验证确认趋势页已补齐关键指标、维修可视化和按产品/工序/人员维度观察能力。
- 产品模块启停口径一致性收口：独立验证确认已消除 `active + effective_version=0` 灰态，且恢复启用只能走版本生效链路。
- 设备模块来源快照与详情深度收口：独立验证确认执行详情/记录详情已补齐来源计划摘要、设备快照与执行工段快照。
- 消息模块品质首件对象级跳转收口：独立验证确认首件消息已带对象级 payload，且消息导航后会自动打开目标首件详情页。
- 工艺模块系统母版步骤主视图收口：独立验证确认主页面已直接展示系统母版完整步骤列表，无需进入编辑/历史弹窗。
- 产品模块版本删除保护收口：独立验证确认被生产工单引用的草稿版本已无法删除，且错误提示包含版本标签与工单号。
- 消息模块公告发布最小闭环：独立验证确认后端已支持按范围发布公告，且消息中心有权限时可直接发布并刷新结果。
- 消息模块代班审批对象级跳转收口：独立验证确认代班审批消息已带对象级 payload，且导航后会自动打开目标审批详情。
- 工艺模块内链记录级跳转收口：独立验证确认工艺内链 jumpTarget 已从模块级切换提升为记录级/视图级承接。
- 设备模块保养记录附件列增强：独立验证确认列表附件列已具备可交互入口并覆盖有无附件两种状态。
- 产品模块版本参数公开契约收口：首次验证因前端服务层仍保留默认回退旧接口而不通过；二次修复后已确认显式版本/生效参数 API 收口完成。
- 产品模块版本参数公开契约收口：首次验证因前端服务层仍保留默认回退旧接口而不通过；二次修复后已确认显式版本/生效参数 API 收口完成。
- 消息模块用户注册审批精确落位收口：独立验证确认注册审批消息已带 `change_password` payload，且导航后会自动定位到账号设置的修改密码区域。
- 工艺模块回滚目标版本专属影响预览收口：独立验证确认 impact-analysis 已支持 `target_version`，且回滚弹窗会随目标版本变化刷新预览。
- 产品模块版本参数列表主视图收口：独立验证确认参数管理页首屏已改为版本参数列表，且操作全部绑定当前版本行。
- 设备模块详情风险提示与快捷入口收口：独立验证确认设备详情页已补齐风险总览卡片与可交互快捷入口。
- 设备模块规则与运行参数同范围联动收口：独立验证确认规则页可直接联动到同作用范围运行参数视图，且运行参数支持 `equipment_type` 联合过滤。
- 系统级复查与检查报告：独立复查确认 7 个模块已满足需求说明，且后端模块集成测试、前端全量 analyze、前端全量 test 均已通过。
- 最后验证日期：2026-03-22

## 7. 失败重试记录

### 7.1 重试轮次

- 本轮用户模块 2 个原子任务均一次通过，暂无失败重试。
- 产品模块版本参数公开契约收口：独立验证首次判定不通过，失败点为 `frontend/lib/services/product_service.dart` 仍保留可空 `version` 默认回退旧接口；已重新派发执行子 agent 二次修复并通过复检。

### 7.2 收口结论

- 尚未开始。

## 8. 实际改动

- `evidence/commander_requirement_run_20260321.md`：建立本轮指挥官任务主日志。
- `evidence/commander_requirement_queue_20260321.csv`：建立本轮模块整改总队列。
- `backend/app/core/authz_hierarchy_catalog.py`：补充隐藏能力与角色专属能力元数据。
- `backend/app/services/authz_service.py`：隐藏特殊能力并保持系统管理员 guardrail。
- `frontend/lib/pages/function_permission_config_page.dart`：过滤隐藏能力包项。
- `frontend/lib/pages/user_page.dart`：收口强制下线入口可见规则。
- `frontend/lib/pages/login_session_page.dart`：统一在线会话主状态与颜色。
- `frontend/lib/pages/user_management_page.dart`：统一弹窗打开前刷新工段逻辑。
- `frontend/lib/pages/registration_approval_page.dart`：审批通过弹窗打开前刷新工段并支持测试注入。
- `frontend/test/widgets/user_management_page_test.dart`：新增工段刷新回归测试。
- `frontend/test/widgets/registration_approval_page_test.dart`：新增审批工段刷新回归测试。
- `frontend/lib/pages/production_assist_approval_page.dart`：统一代班状态筛选文案。
- `frontend/lib/pages/production_order_query_detail_page.dart`：补齐执行详情基础信息展示。
- `frontend/test/widgets/production_assist_approval_page_test.dart`：补充状态筛选文案回归。
- `frontend/test/widgets/production_order_query_detail_page_test.dart`：补充执行详情基础信息回归。
- `backend/app/services/production_order_service.py`：补充并行实例业务筛选条件。
- `backend/app/api/v1/endpoints/production.py`：并行实例接口透传工序关键字与实例编号查询条件，并返回工序名称。
- `backend/app/schemas/production.py`：并行实例项新增 `process_name`。
- `backend/tests/test_production_module_integration.py`：补充并行实例业务化回归并收紧删除追溯测试查询条件。
- `frontend/lib/models/production_models.dart`：并行实例模型新增工序名称与业务展示字段。
- `frontend/lib/services/production_service.dart`：透传工序关键字与实例编号查询参数。
- `frontend/lib/pages/production_pipeline_instances_page.dart`：筛选栏与列表展示业务化，并新增只读查看订单入口。
- `frontend/lib/pages/production_order_detail_page.dart`：支持只读模式。
- `frontend/test/widgets/production_pipeline_instances_page_test.dart`：补充并行实例页面回归测试。
- `backend/app/api/v1/endpoints/quality.py`：拆分首件详情与处置详情权限入口。
- `backend/tests/test_quality_module_integration.py`：补充首件权限隔离回归测试。
- `frontend/lib/services/quality_service.dart`：增加处置详情读取方法。
- `frontend/lib/pages/daily_first_article_page.dart`：拆分“详情”和“处置”操作入口。
- `frontend/lib/pages/first_article_disposition_page.dart`：按详情/处置模式切换读取接口。
- `frontend/test/services/quality_service_test.dart`：补充新旧详情读取接口测试。
- `frontend/test/services/quality_service_contract_test.dart`：补充详情接口与处置详情接口契约分离测试。
- `backend/app/services/message_service.py`：补充过期消息与失效原因计算。
- `backend/app/api/v1/endpoints/messages.py`：列表接口透传当前用户上下文用于失效原因判定。
- `backend/app/schemas/message.py`：消息项新增 `inactive_reason`。
- `backend/tests/test_message_module_integration.py`：补充过期消息与失效原因回归。
- `frontend/lib/models/message_models.dart`：解析并映射失效原因文案。
- `frontend/lib/pages/message_center_page.dart`：按更细失效原因展示列表与预览文案。
- `frontend/test/services/message_service_test.dart`：补充失效原因解析测试。
- `frontend/test/widgets/message_center_page_test.dart`：补充页面失效文案回归。
- `frontend/lib/pages/product_management_page.dart`：补充产品表单状态展示与即时校验。
- `frontend/test/widgets/product_module_issue_regression_test.dart`：补充产品表单展示与校验回归。
- `backend/app/services/production_repair_service.py`：补充报废统计产品名称/工序编码精确筛选。
- `backend/app/api/v1/endpoints/production.py`：报废统计列表与导出接口透传精确筛选字段。
- `backend/app/schemas/production.py`：报废统计导出请求新增精确筛选字段。
- `backend/tests/test_production_module_integration.py`：补充报废统计精确筛选与导出回归。
- `frontend/lib/services/production_service.dart`：报废统计列表/导出透传精确筛选参数。
- `frontend/lib/pages/production_scrap_statistics_page.dart`：筛选栏增加产品名称/工序编码精确筛选。
- `frontend/test/widgets/production_repair_scrap_pages_test.dart`：补充报废统计精确筛选回归。
- `backend/app/services/quality_service.py`：补充 Top 缺陷原因与产品质量对比聚合。
- `backend/app/schemas/quality.py`：不良分析结果新增 Top 缺陷原因与产品质量对比字段。
- `backend/tests/test_quality_module_integration.py`：补充不良分析增强回归。
- `frontend/lib/models/quality_models.dart`：解析不良分析新增字段。
- `frontend/lib/pages/quality_defect_analysis_page.dart`：新增 Top 缺陷原因与产品质量对比展示。
- `frontend/test/models/quality_models_test.dart`：补充不良分析模型解析回归。
- `frontend/test/services/quality_service_contract_test.dart`：补充不良分析新契约回归。
- `frontend/lib/pages/daily_first_article_page.dart`：每日首件列表改为独立页面跳转并支持返回刷新。
- `frontend/lib/pages/first_article_disposition_page.dart`：重构为独立首件详情/处置页面。
- `frontend/test/widgets/quality_first_article_page_test.dart`：补充首件独立页面回归。
- `frontend/lib/pages/quality_trend_page.dart`：补充关键指标摘要、维修可视化与多维度观察区。
- `frontend/test/widgets/quality_trend_page_test.dart`：补充质量趋势增强回归。
- `backend/app/services/product_service.py`：统一产品启停与版本生效/停用联动规则。
- `backend/tests/test_product_module_integration.py`：补充产品启停联动回归。
- `frontend/lib/pages/product_management_page.dart`：同步产品状态展示与提示文案。
- `frontend/lib/pages/product_version_management_page.dart`：同步版本生效/停用提示与恢复路径提示。
- `frontend/test/widgets/product_module_issue_regression_test.dart`：补充产品启停口径回归。
- `backend/app/schemas/equipment.py`：设备详情契约新增来源计划摘要与记录快照字段。
- `backend/app/api/v1/endpoints/equipment.py`：设备详情接口统一组装来源计划摘要并补齐记录来源快照。
- `backend/tests/test_equipment_module_integration.py`：补充设备来源快照回归。
- `frontend/lib/models/equipment_models.dart`：解析设备详情新增快照字段。
- `frontend/lib/pages/maintenance_execution_detail_page.dart`：前置展示来源计划、设备快照与执行工段快照。
- `frontend/lib/pages/maintenance_record_detail_page.dart`：前置展示记录详情来源快照。
- `frontend/test/models/equipment_models_test.dart`：补充设备模型快照字段解析回归。
- `frontend/test/services/equipment_service_test.dart`：补充设备详情快照服务回归。
- `backend/app/api/v1/endpoints/quality.py`：首件处置消息增加对象级 route payload。
- `backend/tests/test_quality_module_integration.py`：补充首件消息对象级 payload 回归。
- `frontend/lib/pages/main_shell_page.dart`：新增品质页面 route payload 透传。
- `frontend/lib/pages/quality_page.dart`：将 route payload 继续透传给每日首件页。
- `frontend/lib/pages/daily_first_article_page.dart`：消费消息 payload 并自动打开目标首件详情页。
- `frontend/test/widgets/message_center_page_test.dart`：补充消息中心 route payload 透传断言。
- `frontend/test/widgets/quality_first_article_page_test.dart`：补充品质页自动打开目标首件详情回归。
- `frontend/lib/pages/process_configuration_page.dart`：主页面新增系统母版步骤只读展示区。
- `frontend/test/widgets/process_configuration_page_test.dart`：补充工艺系统母版主视图回归。
- `backend/app/services/product_service.py`：补充产品草稿版本删除引用保护。
- `backend/tests/test_product_module_integration.py`：补充产品版本删除保护回归。
- `backend/app/core/authz_catalog.py`：新增公告发布动作权限。
- `backend/app/core/authz_hierarchy_catalog.py`：新增公告发布能力码。
- `backend/app/services/authz_service.py`：补充公告发布能力的权限中文映射与 system_admin 保底。
- `backend/app/schemas/message.py`：新增公告发布请求/结果契约。
- `backend/app/services/message_service.py`：新增公告发布与收件人解析逻辑。
- `backend/app/api/v1/endpoints/messages.py`：新增公告发布接口。
- `backend/tests/test_message_module_integration.py`：补充公告发布三种范围回归。
- `frontend/lib/pages/message_center_page.dart`：新增公告发布按钮与弹窗。
- `frontend/lib/services/message_service.dart`：新增公告发布 API 调用。
- `frontend/lib/models/message_models.dart`：新增公告发布前端模型。
- `frontend/test/widgets/message_center_page_test.dart`：补充公告发布 UI 回归。
- `frontend/test/services/message_service_test.dart`：补充公告发布服务回归。
- `backend/app/services/assist_authorization_service.py`：代班审批结果消息改为对象级 payload 跳转。
- `frontend/lib/pages/production_page.dart`：透传代班审批 route payload。
- `frontend/lib/pages/production_assist_approval_page.dart`：消费对象级 payload 后自动打开目标审批详情。
- `frontend/lib/pages/craft_reference_analysis_page.dart`：工艺内链与产品模式引用补齐跳转承接。
- `frontend/lib/pages/craft_page.dart`：解析工艺内链 jumpTarget 并继续透传给目标子页。
- `frontend/lib/pages/process_management_page.dart`：承接工序级 jumpTarget 并定位目标记录。
- `frontend/lib/pages/process_configuration_page.dart`：承接模板/版本/系统母版历史视图 jumpTarget。
- `frontend/lib/pages/maintenance_record_page.dart`：保养记录附件列增强为可点击入口。
- `frontend/test/widgets/maintenance_record_page_test.dart`：补充附件列交互回归。
- `backend/app/api/v1/endpoints/products.py`：产品参数接口显式返回作用域与目标版本信息。
- `backend/app/schemas/product.py`：产品参数结果新增 `parameter_scope` 与版本信息。
- `frontend/lib/services/product_service.dart`：产品参数主链路改为显式版本/生效参数 API，并移除默认旧接口回退。
- `frontend/lib/pages/product_parameter_management_page.dart`：参数管理页主链路显式使用版本参数 API。
- `backend/app/api/v1/endpoints/auth.py`：注册审批通过消息新增 `change_password` route payload。
- `frontend/lib/pages/user_page.dart`：用户模块容器透传 route payload 到账号设置页。
- `frontend/lib/pages/account_settings_page.dart`：消费消息 payload 并自动定位修改密码区域。
- `frontend/test/widgets/account_settings_page_test.dart`：补充账号设置精确落位回归。
- `backend/app/schemas/craft.py`：工艺影响分析结果新增 `target_version`。
- `backend/app/services/craft_service.py`：工艺 impact-analysis 与 rollback 共用目标版本步骤来源。
- `backend/app/api/v1/endpoints/craft.py`：工艺 impact-analysis 接口支持 `target_version`。
- `backend/tests/test_craft_module_integration.py`：补充工艺目标版本预览回归。
- `frontend/lib/models/craft_models.dart`：解析工艺 impact-analysis 的 `targetVersion`。
- `frontend/lib/services/craft_service.dart`：请求工艺 impact-analysis 时显式传 `targetVersion`。
- `frontend/lib/pages/equipment_detail_page.dart`：新增设备风险总览卡片与快捷入口。
- `frontend/test/widgets/equipment_detail_page_test.dart`：补充设备详情风险提示与快捷入口回归。
- `backend/app/services/product_service.py`：新增版本参数列表聚合查询。
- `frontend/lib/models/product_models.dart`：新增版本参数列表模型。
- `frontend/lib/pages/product_page.dart`：产品页入口文案改为版本参数管理并显式带目标版本。
- `backend/app/services/equipment_rule_service.py`：运行参数列表新增 `equipment_type` 联合过滤。
- `backend/app/api/v1/endpoints/equipment.py`：运行参数接口透传 `equipment_type` 查询条件。
- `frontend/lib/services/equipment_service.dart`：运行参数列表请求支持 `equipmentType`。
- `frontend/lib/pages/equipment_rule_parameter_page.dart`：规则列表新增“查看参数/配置参数”联动入口，并支持作用范围提示条。
- `frontend/test/widgets/equipment_rule_parameter_page_test.dart`：补充规则到参数联动回归。
- `backend/tests/test_production_module_integration.py`：系统级复查中补充产品激活前置条件，修复全量后端模块集成测试失配。
- `evidence/mes_system_check_report_20260322.md`：新增最终系统检查报告。

## 9. 硬阻塞与限制

### 9.1 硬阻塞

- 阻塞项：无
- 已尝试动作：无
- 当前影响：无
- 建议下一步：继续进入全模块调研与原子任务拆解。

### 9.2 已知限制

- 当前会话未提供 Sequential Thinking MCP；本轮以显式任务拆解、TodoWrite 与 `evidence/` 留痕代替，并在此记录降级原因。
- 是否存在未提交在制改动对个别模块结论的影响，需在后续按模块调研时继续标注。

## 10. 交付判断

- 已完成项：
  - 建立本轮任务日志
  - 建立本轮模块整改总队列
- 用户模块已完成 2 个原子整改任务并通过独立验证
- 生产模块已完成 2 个原子整改任务并通过独立验证
- 品质模块已完成 5 个原子整改任务并通过独立验证
- 设备模块已完成 4 个原子整改任务并通过独立验证
- 工艺模块已完成 3 个原子整改任务并通过独立验证
- 产品模块已完成 5 个原子整改任务并通过独立验证
- 消息模块已完成 5 个原子整改任务并通过独立验证
- 已完成系统级复查与检查报告
- 未完成项：
  - 无
- 是否满足本轮目标：是
- 主 agent 最终结论：可交付

## 11. 输出文件

- `evidence/commander_requirement_run_20260321.md`
- `evidence/commander_requirement_queue_20260321.csv`
- `evidence/mes_system_check_report_20260322.md`

## 12. 迁移说明

- 无迁移，直接替换。

## 13. 后续建议

1. 并行派发 7 个模块调研子 agent，形成统一缺口表。
2. 基于缺口表拆分模块级原子任务，再进入执行/验证闭环。

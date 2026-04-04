# 指挥官流程工具化治理补充

## 1. 文档定位

- 本文档是 `指挥官工作流程.md` 的工具化补充，用于约束“任务分类、工具触发、执行留痕、验证门禁、降级代偿、evidence 输出”六类落地动作。
- 本文档不重复定义主 agent、调研子 agent、执行子 agent、验证子 agent 的角色基线，也不重述指挥官闭环流程；角色职责、闭环顺序、通过条件以 `指挥官工作流程.md` 为准。
- 当主流程文档与本文档同时命中时，按“流程基线优先、工具细则补充”的原则执行。

## 2. 引用关系

- 流程基线：`指挥官工作流程.md`
- 主任务日志模板：`evidence/指挥官任务日志模板.md`
- OpenCode 工具清单：`docs/opencode_tooling_bundle.md`
- 主机辅助工具清单：`docs/host_tooling_bundle.md`
- 工具化验证补充模板：`evidence/指挥官工具化验证模板.md`

## 3. 任务分类表

| 分类编码 | 任务类型 | 典型输入 | 默认执行工具 | 默认验证工具 | 必留痕输出 |
| --- | --- | --- | --- | --- | --- |
| CAT-01 | 后端模型/接口/迁移联动 | FastAPI 模型、Schema、Service、Endpoint、Alembic 变更 | Sequential Thinking、Task、Serena、postgres MCP | postgres MCP、Bruno、openapi-validate、http-probe | 变更文件、迁移影响、接口验证、数据库核对 |
| CAT-02 | 前后端契约同步 | OpenAPI、后端 Schema、Flutter DTO、接口页面联动 | Sequential Thinking、Task、Serena、Context7 | openapi-validate、Bruno、Playwright、flutter-ui | 契约差异、同步范围、接口与页面回归 |
| CAT-03 | Flutter CRUD 页面/交互改造 | 列表、筛选、分页、弹窗、提交流程 | Sequential Thinking、Task、Serena、flutter-ui | flutter-ui、Playwright、WinAppDriver、FlaUInspect | 页面改动点、交互结果、桌面控件定位 |
| CAT-04 | RBAC/页面可见性/权限码联动 | 角色、能力码、菜单、Tab、侧边栏、接口保护 | Sequential Thinking、Task、Serena | Bruno、Playwright、flutter-ui、http-probe | 权限矩阵、显隐结果、接口授权验证 |
| CAT-05 | 本地环境/联调/bootstrap 运行 | 启动链路、NO_PROXY、health、bootstrap、数据库连接 | Sequential Thinking、Task、Serena、postgres MCP | http-probe、Bruno、Playwright、mitmproxy/Fiddler | 启动命令、联调链路、健康检查、抓包证据 |
| CAT-06 | 编码/中文乱码/文案一致性 | 中文文案、编码格式、接口消息、页面显示 | Sequential Thinking、Task、Serena、Context7 | Playwright、flutter-ui、Bruno | 问题样例、修复位置、显示结果、文案对照 |
| CAT-07 | 接口联调/问题复现/抓包排障 | 请求参数、响应体、异常链路、跨端行为差异 | Sequential Thinking、Task、Serena、Bruno | Bruno、mitmproxy/Fiddler、http-probe、Playwright | 请求样本、抓包会话、复现步骤、根因结论 |
| CAT-08 | 发布前审计/供应链与仓库协作 | SBOM、漏洞、PR、Issue、发布前核查 | Sequential Thinking、Task、gh、Syft、Trivy | gh、Syft、Trivy | SBOM、扫描结论、协作记录、发布风险 |

## 4. 角色-工具矩阵

| 角色 | 必选工具 | 按需工具 | 禁止省略的动作 |
| --- | --- | --- | --- |
| 主 agent（指挥官） | Sequential Thinking、evidence | Task、Serena、Context7、gh | 先拆分原子任务，再定义触发工具、验收标准和降级口径 |
| 调研子 agent | Serena | Context7、postgres MCP、gh | 输出文件范围、符号/契约/依赖结论，并可被主 agent 直接代记到 evidence |
| 执行子 agent | Serena | Task、postgres MCP、flutter-ui、Bruno、Playwright、gh | 严守任务边界，记录实际改动、自测命令与未决项 |
| 验证子 agent | evidence | postgres MCP、openapi-validate、flutter-ui、Playwright、WinAppDriver、FlaUInspect、Bruno、http-probe、mitmproxy/Fiddler、Trivy、Syft、gh | 独立复核、真实执行、明确给出通过或不通过结论 |

### 4.1 工具职责说明

| 工具 | 主要职责 | 适用阶段 |
| --- | --- | --- |
| Sequential Thinking | 任务拆解、边界澄清、降级口径预判 | 启动、失败重试前 |
| Task | 主 agent 派发原子任务、组织执行/验证闭环 | 启动、循环、复检 |
| Serena | 代码与文档定位、精确编辑、引用追踪 | 调研、执行 |
| Context7 | 官方文档与外部规范补证 | 调研、验证 |
| postgres MCP | 只读数据库核对、迁移后数据抽检 | 执行、验证 |
| openapi-validate | OpenAPI 文档抓取与契约校验 | 验证 |
| flutter-ui | Flutter 页面、组件、集成测试 | 执行自测、验证 |
| Playwright | Web 页面行为、接口联动、可视回归 | 验证 |
| WinAppDriver | Windows 桌面自动化回归 | 验证 |
| FlaUInspect | Windows 控件树定位与可自动化性确认 | 调研、验证 |
| Bruno | API 调试、集合回归、接口重放 | 执行自测、验证 |
| http-probe | 本地服务健康探测、联调入口确认 | 执行自测、验证 |
| mitmproxy/Fiddler | 抓包、会话回放、链路归因 | 调研、验证 |
| gh | GitHub 协作对象、PR、Issue、远端检查项 | 调研、验证 |
| Trivy | 漏洞扫描 | 验证 |
| Syft | SBOM 生成与依赖盘点 | 验证 |
| evidence | 留痕、证据编号、通过判定、代记责任 | 全阶段 |

## 5. 默认触发规则

### 5.1 启动阶段默认触发

1. 只要进入“指挥官模式”，主 agent 必须先触发一次 Sequential Thinking，产出任务拆分、边界、验收、风险与降级预案。
2. 任务跨两个及以上模块，或包含“实现 + 验证”两个以上口径时，主 agent 默认触发 Task 进行原子任务派发。
3. 需要读代码、查引用、查文档路径、做最小编辑时，默认触发 Serena，不以全文盲读替代。
4. 涉及外部框架、官方契约或工具参数不确定时，默认补一次 Context7；若不可用，转离线保守结论并记降级。

### 5.2 分类触发规则

1. 命中 CAT-01 时：默认补触发 postgres MCP；接口对外暴露时再触发 Bruno 与 openapi-validate。
2. 命中 CAT-02 时：默认触发 openapi-validate；涉及页面联动时再触发 Playwright 或 flutter-ui。
3. 命中 CAT-03 时：默认触发 flutter-ui；若为 Windows 管理端交互问题，再补 WinAppDriver 或 FlaUInspect。
4. 命中 CAT-04 时：默认至少覆盖“接口授权 + 页面显隐”两个验证口径，优先 Bruno + Playwright/flutter-ui 组合。
5. 命中 CAT-05 时：默认先用 http-probe 确认服务入口；需要定位链路差异时补 mitmproxy/Fiddler；涉及数据库初始化时补 postgres MCP。
6. 命中 CAT-06 时：默认要求至少一条真实显示验证，优先页面验证工具；仅代码层修字面量不算完成。
7. 命中 CAT-07 时：默认生成一组可复现请求样本，并保留抓包或会话证据。
8. 命中 CAT-08 时：默认触发 Syft 与 Trivy；涉及远程协作对象时补 gh。

### 5.3 复检触发规则

1. 任何执行子 agent 自测通过但未经过独立验证子 agent 复检的任务，不得标记完成。
2. 只要出现失败重试，复检工具不得简单复用“仅文本检查”；应尽量回到原失败口径做真实复验。
3. 文档类任务若约束的是流程、门禁、模板或制度，验证子 agent 至少要做“章节完整性 + 引用路径存在性 + 与基线关系一致”三项检查。

## 6. 验证门禁清单

| 门禁编号 | 检查项 | 通过标准 | 不通过示例 |
| --- | --- | --- | --- |
| G1 | 任务分类已判定 | 已映射到 CAT-01 至 CAT-08 之一，可多选但必须有主分类 | 未写分类，直接开始实现 |
| G2 | 工具触发有依据 | 已记录默认触发、补充触发或不触发理由 | 仅写“已处理”，无工具口径 |
| G3 | 执行与验证分离 | 存在独立验证子 agent 或等效降级补偿记录 | 执行者自测即视为通过 |
| G4 | 真实验证已执行 | 已有命令、页面行为、抓包、数据库查询或扫描结果 | 只列建议命令，未实际执行 |
| G5 | evidence 已闭环 | 能串起“触发 -> 执行 -> 验证 -> 重试 -> 收口” | 只有结果，没有过程 |
| G6 | 降级已代偿 | 不可用工具、影响范围、替代动作、残余风险齐全 | 只写“工具不可用” |
| G7 | 迁移口径明确 | 已写“无迁移，直接替换”或给出迁移步骤 | 未说明迁移影响 |

### 6.1 分类附加门禁

- CAT-01：有数据库变更时，必须同时说明迁移影响与接口影响。
- CAT-02：有契约变更时，必须同时说明后端与前端是否已收敛。
- CAT-03：有页面交互改动时，必须留一条真实交互验证结果。
- CAT-04：有权限联动时，必须留一条授权成功或拒绝的真实证据。
- CAT-05：有联调或 bootstrap 变更时，必须留一条可访问性或健康检查证据。
- CAT-06：有中文或编码修复时，必须区分“数据源错误”与“显示链路错误”。
- CAT-08：有发布前审计动作时，必须留 SBOM 或扫描结果摘要。

## 7. 工具降级与代偿规则

| 原工具 | 常见不可用场景 | 允许替代 | 最低代偿要求 |
| --- | --- | --- | --- |
| Sequential Thinking | MCP 不可达 | 书面拆解写入 evidence | 记录拆解时间、边界、未覆盖风险 |
| Task | 无法创建子 agent | 由当前 agent 严格按调研/执行/验证分段推进 | 记录独立性缺口与补偿验证 |
| Serena | MCP 不可达 | 使用仓库文件检索与最小 patch 编辑 | 记录为何无法做语义级定位 |
| Context7 | 公网不可达 | 使用仓库既有文档与离线经验结论 | 标注结论时效与不确定性 |
| postgres MCP | 数据库不可达 | 退回迁移脚本、模型代码、接口结果交叉核对 | 标注未完成实库抽检 |
| openapi-validate | 服务未启动或文档不可抓取 | 退回静态契约比对 | 标注未完成真实抓取校验 |
| flutter-ui / Playwright / WinAppDriver | 运行环境缺失 | 退回静态核对 + 人工步骤脚本 | 标注未完成自动化验证 |
| Bruno / http-probe | 本地服务不可达 | 退回请求样本与日志核对 | 标注接口未真实打通 |
| mitmproxy/Fiddler | 代理不可用 | 退回应用日志与请求结果比对 | 标注缺少链路级抓包 |
| Trivy / Syft | 工具未安装或扫描源不可达 | 退回依赖清单静态盘点 | 标注未完成正式扫描 |
| gh | 未鉴权或网络受限 | 退回本地 git 与现有文档信息 | 标注未完成远端对象核对 |

## 8. evidence 输出要求

1. 主任务日志仍以 `evidence/指挥官任务日志模板.md` 为主，记录任务目标、拆分、子 agent 摘要、失败重试与最终交付。
2. 当任务命中本文档任一分类，或存在显式工具触发、降级、抓包、扫描、契约校验、数据库核对时，应同时补一份 `evidence/指挥官工具化验证模板.md`。
3. 工具化补充模板至少要能回答五个问题：
   - 为什么触发该工具。
   - 用工具做了什么。
   - 结果是否通过。
   - 失败后如何重试。
   - 最终如何收口。
4. 只读调研结果若由主 agent 代记，必须在 evidence 中写明“代记责任人、代记时间、原始来源、适用结论”。
5. 若无迁移需求，统一写“无迁移，直接替换”。

## 9. 最小落地示例

### 9.1 示例 A：后端模型/接口/迁移联动

1. 主 agent 用 Sequential Thinking 拆出“模型变更、迁移脚本、接口回归、数据库核对”四个验收点。
2. 执行子 agent 用 Serena 修改后端文件，并补迁移。
3. 验证子 agent 用 postgres MCP 抽查表结构，用 Bruno 回归接口，用 openapi-validate 检查契约。
4. evidence 同时写主任务日志与工具化验证模板，记录触发依据、查询 SQL、接口结果与通过结论。

### 9.2 示例 B：Flutter CRUD 页面/交互改造

1. 主 agent 将任务归类为 CAT-03，并指定 flutter-ui 为默认验证工具。
2. 执行子 agent 用 Serena 改页面，用 flutter-ui 做最小自测。
3. 验证子 agent 用 flutter-ui 复检；若是 Windows 特定控件问题，再用 FlaUInspect 定位控件树，必要时补 WinAppDriver 回归。
4. evidence 必须留下“页面入口、操作步骤、实际结果、失败重试、最终判定”。

## 10. 适用结论

- 本文档生效后，指挥官模式下的工具使用不再依赖临场约定，而应按“先分类、再触发、再留痕、再验证”的固定口径执行。
- 无迁移，直接补充。

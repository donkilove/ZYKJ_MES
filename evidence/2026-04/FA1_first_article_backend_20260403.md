# FA1 执行留痕：首件富表单后端基础

## 1. 任务范围

- 任务编号：FA1
- 任务名称：首件富表单后端基础、提交契约、模板与参与人存储、参数查看只读支撑
- 执行日期：2026-04-03
- 执行角色：执行子 agent

## 2. 工具降级记录

- `Sequential Thinking`：当前会话不可用。
- 降级原因：工具链未提供对应入口。
- 替代措施：先做显式代码检索，再在本文件记录拆解、改动点与验证结果。
- 影响评估：仅影响形式化思考留痕，不影响本次代码实现与定向验证。

## 3. 本次改动摘要

- 扩展 `mes_first_article_record`，新增 `template_id`、`check_content`、`test_value`。
- 新增 `mes_first_article_template` 与 `mes_first_article_participant` 两张表及 ORM 注册。
- 扩展生产首件提交契约，支持模板、检验内容、测试值、结果、参与操作员。
- 新增生产侧只读接口：首件模板、参与操作员候选、参数查看。
- 扩展质量详情读取，返回模板信息、首件内容、测试值、参与操作员。
- 补充最小回归测试，覆盖提交保存、模板查询、参与人保存、质量详情返回。

## 4. 关键实现决策

- 决策 1：为避免前后端切换期间立即阻断旧入口，`FirstArticleRequest` 对新增字段采用最小必要兼容，旧字段仍可继续提交。
  - 结论：这是过渡兼容，不新增长期双轨逻辑；FA2 完成后以前端新契约为准。
- 决策 2：`result=failed` 时仅保存首件记录，不再把工序/子工单推进到“开工中”。
  - 结论：这样更符合“首件不通过”语义，也不会破坏既有品质处置链路。
- 决策 3：参数查看优先复用产品参数能力，但通过生产模块新只读接口输出最小展示结构。
  - 结论：避免生产首件页额外依赖产品参数查看权限。

## 5. 验证记录

- 命令：`python -m compileall backend/app backend/alembic`
  - 结果：通过。
- 命令：`python -m pytest backend/tests/test_production_module_integration.py -k "first_article_rich_submission_and_queries_work"`
  - 结果：通过，`1 passed, 16 deselected`。
- 命令：`python -m pytest backend/tests/test_quality_module_integration.py -k "first_article_detail_includes_rich_fields"`
  - 结果：通过，`1 passed, 10 deselected`。

## 6. 未执行项与局限

- 未执行 Alembic 升级，当前仅提交迁移脚本，未改动本地数据库结构。
- 未补首件模板初始化种子数据；当前仅完成模板表结构与查询能力，具体模板内容仍需后续种子或初始化脚本补齐。
- 未做前端联调与 FA2 页面改造验证。

## 7. 结论

- FA1 后端基础已达到可交接状态。
- 对 FA2 的主要前置阻塞已解除：提交契约、模板查询、参与人候选、参数查看、质量详情回显均已具备后端支撑。

## 8. FA1.2 黄旗收敛补记

- 执行日期：2026-04-03
- 执行角色：执行子 agent
- 目标：收敛独立验证提出的 schema drift 与迁移放行证据不足问题，不做 git 提交。

### 8.1 最小修复

- 文件：`backend/app/models/first_article_participant.py`
- 改动：为 `FirstArticleParticipant.user_id` 补充 `index=True`，使 ORM 声明与迁移脚本 `ix_mes_first_article_participant_user_id` 保持一致。
- 影响：避免后续基于模型的自动比对或新环境建表时产生索引漂移风险。

### 8.2 Alembic 真实执行与数据库核验

- 命令：`python -m alembic current`
  - 结果：`x1y2z3a4b5c6 (head)`。
- 命令：`python -m alembic heads`
  - 结果：`x1y2z3a4b5c6 (head)`。
- 命令：`python -m alembic upgrade head`
  - 结果：真实执行成功，无报错；当前数据库已处于 head，因此本次为 no-op 升级确认。
- 命令：`python -m alembic current`
  - 结果：再次确认为 `x1y2z3a4b5c6 (head)`。
- 命令：`python -c "from sqlalchemy import create_engine, inspect; from app.core.config import settings; engine=create_engine(settings.database_url, future=True); insp=inspect(engine); print(insp.get_indexes('mes_first_article_participant'))"`
  - 结果：返回 `ix_mes_first_article_participant_user_id`，确认当前 head 库中参与人表索引已存在。

### 8.3 回归结果

- 命令：`python -m compileall backend/app backend/alembic`
  - 结果：通过。
- 命令：`python -m pytest backend/tests/test_production_module_integration.py -k first_article_rich_submission_and_queries_work`
  - 结果：通过，`1 passed, 16 deselected`。
- 命令：`python -m pytest backend/tests/test_quality_module_integration.py -k first_article_detail_includes_rich_fields`
  - 结果：通过，`1 passed, 10 deselected`。

### 8.4 本轮结论

- FA1.2 指向的两个黄旗已收敛：ORM/迁移索引声明一致，且 Alembic 已完成真实 `upgrade head` 执行与 head 状态核验。
- 当前结果满足重新进入独立验证的前置条件。

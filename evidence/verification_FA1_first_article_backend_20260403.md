# 独立验证记录（FA1 首件富表单后端）

日期：2026-04-03
角色：独立验证子 agent

## 前置说明
- 仅执行验证，不修改业务实现代码。
- 当前环境未提供 `Sequential Thinking` 与计划工具，本次采用显式书面拆解 + 定向命令验证降级执行。

## 验证范围
- `backend/app/models/first_article_record.py`
- `backend/app/models/first_article_template.py`
- `backend/app/models/first_article_participant.py`
- `backend/app/db/base.py`
- `backend/app/models/__init__.py`
- `backend/alembic/versions/x1y2z3a4b5c6_add_first_article_rich_form_schema.py`
- `backend/app/schemas/production.py`
- `backend/app/schemas/quality.py`
- `backend/app/services/production_execution_service.py`
- `backend/app/services/quality_service.py`
- `backend/app/api/v1/endpoints/production.py`
- `backend/tests/test_production_module_integration.py`
- `backend/tests/test_quality_module_integration.py`

## 验证结论
- 结论：FLAG。
- 说明：首件富表单主链路、质量详情回显、失败不推进开工的核心逻辑已验证成立；但 Alembic 迁移仅做静态审阅，未完成真实升级回归，且 ORM 模型与迁移脚本在 `mes_first_article_participant.user_id` 索引声明上存在漂移风险，现阶段不建议按“已完全放行”收口。

## 关键证据
- 证据#FA1-V1：`backend/app/models/first_article_template.py`、`backend/app/models/first_article_participant.py`、`backend/alembic/versions/x1y2z3a4b5c6_add_first_article_rich_form_schema.py`
  结论：模板表、参与操作员关联表及迁移脚本均已存在，且迁移包含 `template_id/check_content/test_value` 扩展列。
- 证据#FA1-V2：`backend/app/schemas/production.py:258-292`
  结论：生产首件提交契约已支持 `template_id`、`check_content`、`test_value`、`result`、`participant_user_ids`，并对 `result` 与参与人 ID 做基础校验。
- 证据#FA1-V3：`backend/app/services/production_execution_service.py:470-521`
  结论：提交首件时会实际归一化并落库 `template_id/check_content/test_value/result`，随后逐条创建 `FirstArticleParticipant` 记录，不是只吞请求体。
- 证据#FA1-V4：`backend/app/api/v1/endpoints/production.py:896-1051`
  结论：模板查询、参与人候选查询、参数查看接口均已存在；模板与参数接口按工单+工序上下文过滤，参与人接口返回可用用户候选。
- 证据#FA1-V5：`backend/app/services/quality_service.py:927-1031`、`backend/app/schemas/quality.py:60-89,216-220`
  结论：质量详情读取已返回 `template_id/template_name/check_content/test_value/participants`，返回结构与 Schema 对齐。
- 证据#FA1-V6：`backend/app/services/production_execution_service.py:491-499,522-533`
  结论：仅 `result == "passed"` 才会把工序/子工单推进到开工中并写入 `RECORD_TYPE_FIRST_ARTICLE` 生产记录；`failed` 不会推进链路。
- 证据#FA1-V7：临时验证脚本输出 `ORDER_STATUS pending / PROCESS_STATUS pending / SUB_STATUS pending`
  结论：`result=failed` 的真实运行结果未错误推进订单、工序、子工单状态。
- 证据#FA1-V8：`backend/tests/test_production_module_integration.py:1377-1505`、`backend/tests/test_quality_module_integration.py:627-655`
  结论：已有最小回归分别覆盖“生产提交并落库富字段/参与人”与“质量详情返回富字段”。

## 发现的问题
- 中：`backend/app/models/first_article_participant.py:14-17` 对 `user_id` 未声明 `index=True`，但迁移 `backend/alembic/versions/x1y2z3a4b5c6_add_first_article_rich_form_schema.py:116-121` 创建了 `ix_mes_first_article_participant_user_id`。当前代码可运行，但后续自动迁移比对可能持续报 schema drift，属于放行前应知晓的迁移维护风险。
- 中：本次未执行 Alembic 升级/降级实跑，仅完成脚本静态检查与业务回归。迁移脚本是否能在目标数据库无副作用落地，当前证据不足。

## 运行命令
- `python -m compileall backend/app backend/tests`
  结果：PASS，无语法错误输出。
- `python -m pytest backend/tests/test_production_module_integration.py -k first_article_rich_submission_and_queries_work -q`
  结果：PASS，`1 passed, 16 deselected in 4.59s`。
- `python -m pytest backend/tests/test_quality_module_integration.py -k first_article_detail_includes_rich_fields -q`
  结果：PASS，`1 passed, 10 deselected in 3.60s`。
- 复用 `ProductionModuleIntegrationTest` 测试夹具执行一次失败首件提交临时脚本
  结果：PASS，HTTP 200，且提交后 `ORDER_STATUS pending`、`PROCESS_STATUS pending`、`SUB_STATUS pending`，证明失败首件未推进开工链路。

## 放行建议
- 不建议按“FA1 已完全验收通过”直接放行。
- 若仅为 FA2 前端继续对接当前契约，可带着迁移验证风险并行推进；若为合并/发布门禁，建议先补 Alembic 实跑验证并处理索引声明漂移。

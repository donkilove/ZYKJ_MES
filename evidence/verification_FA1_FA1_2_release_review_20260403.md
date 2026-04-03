# 独立验证记录（FA1/FA1.2 放行复核）

日期：2026-04-03
角色：独立验证子 agent

## 前置说明
- 仅执行验证，不修改业务实现代码。
- 当前环境未提供 `Sequential Thinking` 与计划工具，本次采用显式书面拆解 + 命令验证降级执行，并将结果留痕到 `evidence/`。

## 验证范围
- `backend/app/models/first_article_participant.py`
- `backend/alembic/versions/x1y2z3a4b5c6_add_first_article_rich_form_schema.py`
- `backend/app/services/production_execution_service.py`
- `backend/app/services/quality_service.py`
- `backend/tests/test_production_module_integration.py`
- `backend/tests/test_quality_module_integration.py`

## 验证结论
- 结论：PASS。
- 说明：`FirstArticleParticipant.user_id` ORM 声明已与迁移脚本对齐；Alembic 已真实执行并确认当前数据库位于 `x1y2z3a4b5c6 (head)`；`mes_first_article_participant` 用户索引存在；首件富提交、模板查询、参数查询、质量详情联动的关键回归仍成立，可放行到 FA2。

## 关键证据
- 证据#FA1.2-V1：`backend/app/models/first_article_participant.py:10-18`
  结论：`user_id` 为主键列，声明 `ForeignKey("sys_user.id", ondelete="RESTRICT")` 且带 `index=True`。
- 证据#FA1.2-V2：`backend/alembic/versions/x1y2z3a4b5c6_add_first_article_rich_form_schema.py:104-121`
  结论：迁移脚本创建 `mes_first_article_participant(record_id, user_id)` 主键与 `ix_mes_first_article_participant_user_id` 索引，和 ORM 当前声明一致。
- 证据#FA1.2-V3：`python -m alembic upgrade head`、`python -m alembic current`
  结论：Alembic 已真实连接当前 PostgreSQL 数据库并返回 `x1y2z3a4b5c6 (head)`。
- 证据#FA1.2-V4：`python -c ... inspect(engine).get_indexes('mes_first_article_participant')`
  结论：数据库实际存在索引 `ix_mes_first_article_participant_user_id`。
- 证据#FA1.2-V5：`backend/app/services/production_execution_service.py:486-576`
  结论：首件提交会校验参与人、写入 `template_id/check_content/test_value/result`，并逐条创建 `FirstArticleParticipant` 关联。
- 证据#FA1.2-V6：`backend/app/services/quality_service.py:927-1031`
  结论：质量详情读取会回显 `template_id/template_name/check_content/test_value/participants`，联动链路完整。
- 证据#FA1.2-V7：`backend/tests/test_production_module_integration.py:1377-1505`
  结论：生产集成回归覆盖模板查询、参与人查询、参数查询、首件富提交与参与人落库。
- 证据#FA1.2-V8：`backend/tests/test_quality_module_integration.py:627-655`
  结论：质量集成回归覆盖首件详情回显模板、检验内容、测试值与参与人。

## 发现的问题
- 本轮未发现阻断 FA2 放行的问题。

## 运行命令与结果
- `python -m alembic upgrade head`
  结果：PASS，Alembic 成功连接 PostgreSQL，未报错中断。
- `python -m alembic current`
  结果：PASS，输出 `x1y2z3a4b5c6 (head)`。
- `cmd /c python -c "from sqlalchemy import inspect,text; from app.db.session import engine; insp=inspect(engine); conn=engine.connect(); print('ALEMBIC_VERSION', conn.execute(text('select version_num from alembic_version')).scalar()); print('PARTICIPANT_INDEXES', [i['name'] for i in insp.get_indexes('mes_first_article_participant')]); conn.close()"`
  结果：PASS，输出 `ALEMBIC_VERSION x1y2z3a4b5c6` 与 `PARTICIPANT_INDEXES ['ix_mes_first_article_participant_user_id']`。
- `python -m pytest backend/tests/test_production_module_integration.py -k first_article_rich_submission_and_queries_work -q`
  结果：PASS，`1 passed, 16 deselected in 5.33s`。
- `python -m pytest backend/tests/test_quality_module_integration.py -k first_article_detail_includes_rich_fields -q`
  结果：PASS，`1 passed, 10 deselected in 4.12s`。
- `python -m compileall backend/app backend/alembic backend/tests`
  结果：PASS，无语法错误。

## 放行建议
- 允许放行到 FA2。
- 无迁移，直接替换。

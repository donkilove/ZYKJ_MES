# 任务日志：后端 40 并发 P95 第一批执行（production + craft）

- 日期：2026-04-17
- 执行人：Codex 主 agent
- 当前状态：任务 1、任务 2、任务 3 已完成
- 执行方式：子代理驱动开发
- 工作树：`/root/code/ZYKJ_MES/.worktrees/backend-p95-40-production-craft-phase1`

## 1. 输入来源

- 计划文档：`docs/superpowers/plans/2026-04-17-backend-p95-40-production-craft-phase1.md`
- 当前任务：任务 3「场景拆分与契约校准」

## 2. 前置说明

- 当前会话已按 `using-git-worktrees` 建立隔离工作树。
- 工作树分支：`feature/backend-p95-40-production-craft-phase1`
- 已补齐最小测试运行器：`pytest`
- 基线验证：`/root/code/ZYKJ_MES/.venv/bin/python -m pytest backend/tests/test_backend_capacity_gate_unit.py -q` => `7 passed`

## 3. 当前拆解

| 序号 | 任务 | 目标 | 当前状态 |
| --- | --- | --- | --- |
| 1 | 样本资产基础 | 落地稳定主样本、一次性写样本、初始化脚本与基础测试 | 已完成 |
| 2 | 样本上下文与写门禁执行链路 | 接通占位符、`runtime_samples` 与恢复路径 | 已完成 |
| 3 | 场景拆分与契约校准 | 产出模块级场景文件并压 `405/422` | 已完成 |
| 4 | 模块级回归与执行口径 | 补齐集成测试与 evidence 入口 | 待开始 |
| 5 | 回灌 270 场景 | 评估第一批对全链路的真实改善 | 待开始 |

## 4. 迁移说明

- 无迁移，直接替换

## 5. 执行记录

- 子代理驱动通道在本会话里不稳定，已在用户确认后切回内联执行任务 `1`。
- 已完成任务 `1`：
  - 新增 `backend/app/services/perf_sample_seed_service.py`
  - 新增 `backend/scripts/init_perf_production_craft_samples.py`
  - 新增 `backend/tests/test_perf_sample_seed_service_unit.py`
  - 新增 `backend/tests/test_perf_production_craft_samples_integration.py`
  - 更新 `docs/后端P95-40并发全链路覆盖/09-样本资产清单.md`
- 实际落地结果：
  - 稳定主样本编码：
    - `PERF-PRODUCT-STD-01`
    - `PERF-STAGE-STD-01`
    - `PERF-PROCESS-STD-01`
    - `PERF-PROCESS-STD-02`
    - `PERF-SUPPLIER-STD-01`
    - `PERF-TEMPLATE-STD-01`
    - `PERF-ORDER-OPEN-01`
  - 运行时写样本编码：
    - `PERF-RUN-<run_id>-ORDER`
  - 样本上下文输出键：
    - `admin_user_id`
    - `admin_username`
    - `product_id`
    - `product_name`
    - `stage_id`
    - `stage_code`
    - `process_id`
    - `process_code`
    - `secondary_process_id`
    - `secondary_process_code`
    - `supplier_id`
    - `supplier_name`
    - `craft_template_id`
    - `craft_template_name`
    - `production_order_id`
    - `production_order_code`
    - `order_process_id`
    - `secondary_order_process_id`
- 当前 `.tmp_runtime/production_craft_samples.json` 已生成，内容可用于下一任务的样本占位符接线。
- 已完成任务 `2`：
  - 新增 `tools/perf/write_gate/sample_context.py`
  - 新增 `tools/perf/write_gate/sample_registry.py`
  - 修改 `tools/perf/backend_capacity_gate.py`
  - 修改 `backend/tests/test_backend_capacity_gate_unit.py`
  - 修改 `backend/tests/test_write_gate_integration.py`
- 任务 `2` 实际落地结果：
  - 新增 `--sample-context-file` 参数，可在压测执行时加载样本上下文 JSON
  - 新增 `_materialize_scenario_request()`，支持 `{sample:key}` 占位符进入 `path/query/json/form`
  - 新增 `_execute_write_gate_contract()` 与 `_build_write_sample_runtime()`，把 `sample_contract.runtime_samples` 接入执行链路
  - 默认样本注册表当前先接入 `order:create-ready`、`order:line-items-ready`、`supplier:create-ready`、`craft:template-publish-ready`
  - 任务 `2` 相关测试结果：`13 passed`
- 已完成任务 `3`：
  - 新增 `tools/perf/scenarios/production_craft_read_40_scan.json`
  - 新增 `tools/perf/scenarios/production_craft_detail_40_scan.json`
  - 新增 `tools/perf/scenarios/production_craft_write_40_scan.json`
  - 新增 `backend/tests/test_production_craft_scenarios_unit.py`
  - 新增 `docs/后端P95-40并发全链路覆盖/10-405422差异清单_production_craft.md`
  - 更新 `tools/perf/scenarios/combined_40_scan.json`
  - 更新 `docs/后端P95-40并发全链路覆盖/04-执行说明与命令模板.md`
  - 继续扩展 `backend/app/services/perf_sample_seed_service.py` 的样本上下文字段
- 任务 `3` 实际落地结果：
  - 拆出 `production + craft` 的 `read/detail/write` 三组模块级场景文件
  - `combined_40_scan.json` 的核心 production/craft detail、write 场景已切到 `{sample:...}` 占位符与当前 schema payload
  - 新增 production/craft 第一批 `405/422` 差异清单
  - 任务 `3` 相关测试结果：
    - `backend/tests/test_production_craft_scenarios_unit.py` => `4 passed`
    - `backend/tests/test_backend_capacity_gate_unit.py backend/tests/test_write_gate_sample_runtime_unit.py backend/tests/test_write_gate_integration.py` => `13 passed`
    - `backend/tests/test_perf_sample_seed_service_unit.py backend/tests/test_perf_production_craft_samples_integration.py` => `3 passed`

## 6. 失败重试记录

| 轮次 | 阶段 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 红灯转绿灯 | `create_order()` 报 `Template is not published` | 样本模板仅创建为草稿，未满足生产订单创建前置条件 | 将稳定模板提升为 `published`，并同步 `published_version` | 通过 |
| 2 | 集成测试 | 登录 `admin` 时抛 `JWT 密钥配置不安全` | 测试环境沿用默认 `jwt_secret_key`，命中运行时安全门禁 | 在集成测试中临时设置安全 JWT 密钥，并在 `tearDown` 恢复 | 通过 |
| 3 | 测试清理 | 清理稳定样本时触发 `ForeignKeyViolation` | 测试把稳定主样本也一并删除，破坏了模板/订单/工序外键关系 | 改为只清理 `PERF-RUN-*` 运行时订单，稳定样本持续复用 | 通过 |
| 4 | 任务 2 单测 | 旧测试调用 `_execute_scenario()` 缺少 `sample_context` 参数 | 新增样本上下文后，旧测试签名未同步更新 | 更新 fake request 签名并补入 `sample_context={}` | 通过 |
| 5 | 任务 2 集成测试 | `test_write_gate_integration.py` 登录链路再次命中 JWT 安全门禁 | 该测试文件未同步设置安全 JWT 密钥 | 在 `setUp/tearDown` 中临时设置并恢复 JWT 密钥 | 通过 |
| 6 | 任务 3 场景拆分 | `test_production_craft_scenarios_unit.py` 要求样本上下文暴露 `stage_code/process_code/order_process_id` 等键 | 任务 1 初版上下文只能支撑最小 smoke，无法支撑模块级 detail/write 场景 | 扩展 `perf_sample_seed_service` 的上下文字段集合 | 通过 |

## 5. 任务 1 启动记录（样本资产基础）

- 启动时间：2026-04-17 15:30:32 +0800
- 目标：落地 production + craft 的稳定主样本与一次性写样本，形成脚本与测试闭环。
- 本轮范围：
  - `backend/app/services/perf_sample_seed_service.py`
  - `backend/scripts/init_perf_production_craft_samples.py`
  - `backend/tests/test_perf_sample_seed_service_unit.py`
  - `backend/tests/test_perf_production_craft_samples_integration.py`
  - `docs/后端P95-40并发全链路覆盖/09-样本资产清单.md`
- 非目标：
  - 不提前实现任务 2 的 `sample_context` / `sample_registry` / `backend_capacity_gate` 占位接线
- 任务拆解方式：
  - 本会话无独立 `Sequential Thinking` 工具入口，采用 `update_plan` 作为等效拆解，按“红灯测试 -> 绿灯最小实现 -> 验证 -> 提交”执行。
- 指挥官模式补偿：
  - 当前会话未提供可直接派发子 agent 的同仓隔离执行能力，采用“实现阶段与验证阶段显式分离”的降级补偿，所有验证命令独立复跑并留痕。

## 6. 任务 3 启动记录（场景拆分与契约校准）

- 启动时间：2026-04-17 15:58:00 +0800
- 目标：产出 `production + craft` 的 `read/detail/write` 子套件，替换核心场景中的历史硬编码 `id`，并登记 `405/422` 差异。
- 本轮范围：
  - `tools/perf/scenarios/production_craft_read_40_scan.json`
  - `tools/perf/scenarios/production_craft_detail_40_scan.json`
  - `tools/perf/scenarios/production_craft_write_40_scan.json`
  - `tools/perf/scenarios/combined_40_scan.json`
  - `backend/tests/test_production_craft_scenarios_unit.py`
  - `docs/后端P95-40并发全链路覆盖/04-执行说明与命令模板.md`
  - `docs/后端P95-40并发全链路覆盖/10-405422差异清单_production_craft.md`
- 非目标：
  - 不执行模块级 40 并发结果回灌
  - 不处理 `repair/scrap` 之外的其他业务模块

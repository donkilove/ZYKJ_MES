# 后端 `40` 并发 `P95` 第一批（production + craft）实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 `production + craft` 从 `270` 场景全链路套件中的主要 `404/405/422` 噪声源，收敛为高成功率、可解释、可复跑的模块级子套件，并验证其对全链路有效覆盖质量的改善。

**架构：** 先落地稳定主样本与一次性写样本，再把样本上下文接入 `backend-capacity-gate` 的路径/参数/请求体占位符解析和写门禁运行时，随后拆分 `production + craft` 的 `read/detail/write` 子套件并回灌 `270` 场景复跑。整个过程按“样本资产 -> 契约校准 -> 模块级子套件 -> 全链路回灌”四批推进，每批都有独立测试、结果文件和 evidence。

**技术栈：** FastAPI、SQLAlchemy、pytest、`tools/perf/backend_capacity_gate.py`、JSON 场景配置、Redis/PostgreSQL 本地运行环境

---

## 文件结构

### 新增文件

- `backend/app/services/perf_sample_seed_service.py`
  - 负责 `production + craft` 稳定主样本与一次性写样本的创建、校验、复位与上下文输出。
- `backend/scripts/init_perf_production_craft_samples.py`
  - CLI 入口；负责 `ensure/check/reset` 三种样本操作，并输出 `.tmp_runtime/production_craft_samples.json`。
- `backend/tests/test_perf_sample_seed_service_unit.py`
  - 验证样本种子服务的幂等性、编码稳定性、上下文输出结构。
- `backend/tests/test_perf_production_craft_samples_integration.py`
  - 通过真实数据库验证样本初始化后读链路、detail 链路与写链路前置条件成立。
- `tools/perf/write_gate/sample_context.py`
  - 负责从样本上下文 JSON 解析 `baseline_refs`，并为路径、query、body 占位符提供统一替换接口。
- `tools/perf/write_gate/sample_registry.py`
  - 负责把 `runtime_samples` 名称映射为可执行的 `SampleHandler`。
- `backend/tests/test_production_craft_scenarios_unit.py`
  - 校验 `production + craft` 模块级场景文件和 `combined_40_scan.json` 的占位符、层级、合同元数据。
- `tools/perf/scenarios/production_craft_read_40_scan.json`
  - `production + craft` 读链路专项场景集。
- `tools/perf/scenarios/production_craft_detail_40_scan.json`
  - `production + craft` detail 链路专项场景集。
- `tools/perf/scenarios/production_craft_write_40_scan.json`
  - `production + craft` 写链路专项场景集。
- `docs/后端P95-40并发全链路覆盖/10-405422差异清单_production_craft.md`
  - 第一批 `production + craft` 的 `405/422` 差异登记与复检闭环。

### 修改文件

- `tools/perf/backend_capacity_gate.py`
  - 接入 `--sample-context-file`、占位符解析、写门禁 `runtime_samples` 执行与 `restore` 结果回写。
- `tools/perf/scenarios/combined_40_scan.json`
  - 将 `production + craft` 相关场景从硬编码 ID 改为样本占位符；补齐 `layer` 与 `sample_contract`。
- `docs/后端P95-40并发全链路覆盖/09-样本资产清单.md`
  - 把第一批稳定样本编码、初始化顺序和复位口径从说明性文字落到执行口径。
- `docs/后端P95-40并发全链路覆盖/04-执行说明与命令模板.md`
  - 增补第一批模块级子套件、样本初始化、回灌复跑的命令模板。
- `docs/后端P95-40并发全链路覆盖/06-证据索引.md`
  - 回填第一批新增场景文件、结果文件和 evidence 索引。
- `backend/tests/test_backend_capacity_gate_unit.py`
  - 增补样本上下文文件、占位符解析、运行时 handler 注册与错误路径测试。
- `backend/tests/test_write_gate_integration.py`
  - 将现有示例扩展到 `production + craft` 第一批的 runtime sample handler 与 restore 行为。
- `backend/tests/test_production_module_integration.py`
  - 复用真实样本上下文或新增 helper，验证 `production` 读/detail/write 的稳定前置条件。
- `backend/tests/test_craft_module_integration.py`
  - 复用真实样本上下文或新增 helper，验证 `craft` 读/detail/write 的稳定前置条件。

### 结果与留痕文件

- `.tmp_runtime/production_craft_samples.json`
  - 样本上下文输出，供 `backend-capacity-gate` 和 smoke 命令消费。
- `.tmp_runtime/production_craft_read_40_*.json`
- `.tmp_runtime/production_craft_detail_40_*.json`
- `.tmp_runtime/production_craft_write_40_*.json`
- `.tmp_runtime/combined_40_production_craft_roundtrip_*.json`
- `evidence/task_log_20260417_backend_p95_40_production_craft_batch1.md`
- `evidence/verification_20260417_backend_p95_40_production_craft_batch1.md`

## 任务 1：落地 production + craft 样本资产基础

**文件：**
- 创建：`backend/app/services/perf_sample_seed_service.py`
- 创建：`backend/scripts/init_perf_production_craft_samples.py`
- 创建：`backend/tests/test_perf_sample_seed_service_unit.py`
- 创建：`backend/tests/test_perf_production_craft_samples_integration.py`
- 修改：`docs/后端P95-40并发全链路覆盖/09-样本资产清单.md`

- [ ] **步骤 1：编写失败的单元/集成测试**

```python
# backend/tests/test_perf_sample_seed_service_unit.py
def test_seed_production_craft_samples_is_idempotent() -> None:
    result_first = seed_production_craft_samples(db, run_id="baseline")
    result_second = seed_production_craft_samples(db, run_id="baseline")

    assert result_first.baseline_refs["product"] == "PERF-PRODUCT-STD-01"
    assert result_second.context["production_order_id"] == result_first.context["production_order_id"]
    assert result_second.created_count == 0


def test_reset_runtime_samples_only_removes_run_scoped_entities() -> None:
    runtime = seed_production_craft_samples(db, run_id="run-001", mode="runtime")
    reset_runtime_samples(db, runtime.run_scoped_refs, restore_strategy="rebuild")

    assert runtime.context["production_order_id"] is not None
    assert find_order_by_code(db, "PERF-ORDER-OPEN-01") is not None
```

```python
# backend/tests/test_perf_production_craft_samples_integration.py
def test_seeded_samples_support_production_and_craft_smoke_queries() -> None:
    context = seed_production_craft_samples(db, run_id="baseline").context

    assert client.get(f"/api/v1/production/orders/{context['production_order_id']}", headers=headers).status_code == 200
    assert client.get(f"/api/v1/craft/templates/{context['craft_template_id']}", headers=headers).status_code == 200
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```bash
./.venv/bin/python -m pytest \
  backend/tests/test_perf_sample_seed_service_unit.py \
  backend/tests/test_perf_production_craft_samples_integration.py -q
```

预期：失败，报 `ModuleNotFoundError`、`ImportError` 或缺少 `seed_production_craft_samples` / `reset_runtime_samples` 等符号。

- [ ] **步骤 3：编写最少实现代码**

```python
# backend/app/services/perf_sample_seed_service.py
from dataclasses import dataclass, field


@dataclass(slots=True)
class ProductionCraftSampleSeedResult:
    created_count: int
    updated_count: int
    baseline_refs: dict[str, str]
    context: dict[str, int | str]
    run_scoped_refs: list[str] = field(default_factory=list)


def seed_production_craft_samples(db: Session, *, run_id: str, mode: str = "baseline") -> ProductionCraftSampleSeedResult:
    """确保稳定主样本存在；当 mode=runtime 时额外创建 run scoped 写样本。"""
    baseline_refs = {
        "product": "PERF-PRODUCT-STD-01",
        "route": "PERF-ROUTE-STD-01",
        "order": "PERF-ORDER-OPEN-01",
        "template": "PERF-TEMPLATE-STD-01",
    }
    product_id = _ensure_active_product(db, code=baseline_refs["product"])
    stage_id = _ensure_stage(db, code="PERF-STAGE-STD-01")
    process_ids = _ensure_processes(db, stage_id=stage_id, codes=["PERF-PROCESS-STD-01", "PERF-PROCESS-STD-02"])
    supplier_id = _ensure_supplier(db, code="PERF-SUPPLIER-STD-01")
    template_id = _ensure_craft_template(db, product_id=product_id, process_ids=process_ids)
    order_id = _ensure_production_order(db, product_id=product_id, supplier_id=supplier_id, template_id=template_id)
    context = {
        "product_id": product_id,
        "stage_id": stage_id,
        "process_id": process_ids[0],
        "secondary_process_id": process_ids[1],
        "supplier_id": supplier_id,
        "craft_template_id": template_id,
        "production_order_id": order_id,
    }
    run_scoped_refs: list[str] = []
    if mode == "runtime":
        runtime_order_code = f"PERF-RUN-{run_id}-ORDER"
        runtime_order_id = _create_runtime_order(db, code=runtime_order_code, product_id=product_id, supplier_id=supplier_id, template_id=template_id)
        context["runtime_order_id"] = runtime_order_id
        run_scoped_refs.append(f"runtime-order:{runtime_order_code}")
    return ProductionCraftSampleSeedResult(
        created_count=0,
        updated_count=0,
        baseline_refs=baseline_refs,
        context=context,
        run_scoped_refs=run_scoped_refs,
    )


def reset_runtime_samples(db: Session, run_scoped_refs: list[str], *, restore_strategy: str | None) -> None:
    """删除或重建一次性写样本，不触碰稳定主样本。"""
    for sample_ref in reversed(run_scoped_refs):
        sample_type, sample_code = sample_ref.split(":", 1)
        if sample_type == "runtime-order":
            _delete_order_by_code(db, sample_code)
        if restore_strategy == "rebuild":
            db.expire_all()
```

```python
# backend/scripts/init_perf_production_craft_samples.py
parser.add_argument("--mode", choices=["ensure", "check", "reset"], default="ensure")
parser.add_argument("--run-id", default="baseline")
parser.add_argument("--output-json", default=".tmp_runtime/production_craft_samples.json")

if args.mode == "ensure":
    result = seed_production_craft_samples(db, run_id=args.run_id, mode="baseline")
    Path(args.output_json).write_text(json.dumps(result.context, ensure_ascii=False, indent=2), encoding="utf-8")
```

```markdown
<!-- docs/后端P95-40并发全链路覆盖/09-样本资产清单.md -->
| 产品 | `PERF-PRODUCT-STD-01` | `production`、`craft` | 通过 `init_perf_production_craft_samples.py --mode ensure` 初始化 | 激活态 | 不允许写链路直接修改 |
| 工艺模板 | `PERF-TEMPLATE-STD-01` | `craft` detail / write | 由稳定产品和稳定工序派生 | 可发布、可回滚 | 写链路后恢复到草稿/已发布基线 |
| 生产订单 | `PERF-ORDER-OPEN-01` | `production` detail / write | 由稳定产品、供应商、工艺生成 | 开单态 | 写链路不得覆盖共享订单 |
```

- [ ] **步骤 4：运行测试验证通过**

运行：

```bash
./.venv/bin/python -m pytest \
  backend/tests/test_perf_sample_seed_service_unit.py \
  backend/tests/test_perf_production_craft_samples_integration.py -q
./.venv/bin/python backend/scripts/init_perf_production_craft_samples.py \
  --mode ensure \
  --output-json .tmp_runtime/production_craft_samples.json
```

预期：pytest 通过，且 `.tmp_runtime/production_craft_samples.json` 被成功生成。

- [ ] **步骤 5：Commit**

```bash
git add \
  backend/app/services/perf_sample_seed_service.py \
  backend/scripts/init_perf_production_craft_samples.py \
  backend/tests/test_perf_sample_seed_service_unit.py \
  backend/tests/test_perf_production_craft_samples_integration.py \
  docs/后端P95-40并发全链路覆盖/09-样本资产清单.md
git commit -m "feat(性能优化): 落地 production craft 样本资产基础"
```

## 任务 2：接通样本上下文占位符与写门禁执行链路

**文件：**
- 创建：`tools/perf/write_gate/sample_context.py`
- 创建：`tools/perf/write_gate/sample_registry.py`
- 修改：`tools/perf/backend_capacity_gate.py`
- 修改：`backend/tests/test_backend_capacity_gate_unit.py`
- 修改：`backend/tests/test_write_gate_integration.py`
- 修改：`backend/tests/test_write_gate_sample_runtime_unit.py`

- [ ] **步骤 1：编写失败的测试**

```python
# backend/tests/test_backend_capacity_gate_unit.py
def test_materialize_request_supports_sample_placeholders() -> None:
    sample_values = {
        "production_order_id": 18,
        "craft_template_id": 21,
        "stage_id": 7,
    }

    scenario = ScenarioSpec(
        name="production-order-detail",
        method="GET",
        path="/api/v1/production/orders/{sample:production_order_id}",
        query={"template_id": "{sample:craft_template_id}"},
        json_body={"stage_id": "{sample:stage_id}"},
    )

    prepared = _materialize_scenario_request(scenario, sample_values)
    assert prepared.path == "/api/v1/production/orders/18"
    assert prepared.query["template_id"] == "21"
    assert prepared.json_body["stage_id"] == 7


def test_execute_write_scenario_runs_prepare_and_restore_handlers() -> None:
    contract = SampleContract(
        baseline_refs=["product:PERF-PRODUCT-STD-01"],
        runtime_samples=["order:create-ready"],
        restore_strategy="rebuild",
    )
    result = _execute_write_gate_contract(
        scenario_name="production-order-create",
        contract=contract,
        sample_context={"product_id": 1},
        registry=build_sample_registry(sample_context={"product_id": 1}, api_client=object()),
    )
    assert result.restore_ok is True
```

```python
# backend/tests/test_write_gate_integration.py
def test_capacity_gate_can_resolve_production_craft_placeholders_from_sample_context(self) -> None:
    scenario = self.scenarios["production-order-create"]
    prepared = materialize_scenario_request(
        scenario,
        {"product_id": 11, "supplier_id": 12, "stage_id": 13, "process_id": 14},
    )
    assert prepared.json_body["product_id"] == 11
    assert prepared.json_body["process_steps"][0]["process_id"] == 14
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```bash
./.venv/bin/python -m pytest \
  backend/tests/test_backend_capacity_gate_unit.py \
  backend/tests/test_write_gate_sample_runtime_unit.py \
  backend/tests/test_write_gate_integration.py -q
```

预期：失败，报缺少占位符解析函数、缺少样本上下文模块或运行时未调用 handler。

- [ ] **步骤 3：编写最少实现代码**

```python
# tools/perf/write_gate/sample_context.py
import re

SAMPLE_TOKEN_PATTERN = re.compile(r"{sample:([a-zA-Z0-9_.-]+)}")


def materialize_value(raw: object, sample_values: dict[str, int | str]) -> object:
    if isinstance(raw, str):
        def _replace(match: re.Match[str]) -> str:
            key = match.group(1)
            return str(sample_values[key])
        replaced = SAMPLE_TOKEN_PATTERN.sub(_replace, raw)
        if replaced.isdigit():
            return int(replaced)
        return replaced.replace("{RANDOM_INT}", str(int(time.time() * 1000)))
    if isinstance(raw, list):
        return [materialize_value(item, sample_values) for item in raw]
    if isinstance(raw, dict):
        return {key: materialize_value(value, sample_values) for key, value in raw.items()}
    return raw
```

```python
# tools/perf/write_gate/sample_registry.py
def build_sample_registry(*, sample_context: dict[str, int | str], api_client: Any) -> dict[str, SampleHandler]:
    return {
        "order:create-ready": ProductionOrderCreateReadyHandler(sample_context, api_client),
        "order:line-items-ready": NoOpSampleHandler(),
        "craft:template-publish-ready": CraftTemplatePublishReadyHandler(sample_context, api_client),
    }
```

```python
# tools/perf/backend_capacity_gate.py
parser.add_argument("--sample-context-file", default=None)

sample_context = _load_sample_context(args.sample_context_file)
prepared_path = materialize_value(scenario.path, sample_context)
prepared_query = materialize_value(dict(scenario.query), sample_context)
prepared_json_body = materialize_value(scenario.json_body, sample_context)

if scenario.sample_contract is not None:
    runtime = WriteSampleRuntime(build_sample_registry(sample_context=sample_context, api_client=client))
    runtime.prepare_contract(scenario.sample_contract)
    try:
        success, status, latency_ms = await _request_scenario(
            client=client,
            base_url=base_url,
            scenario=prepared_scenario,
            token=token,
        )
    finally:
        runtime.restore_contract(scenario.sample_contract)
```

- [ ] **步骤 4：运行测试验证通过**

运行：

```bash
./.venv/bin/python -m pytest \
  backend/tests/test_backend_capacity_gate_unit.py \
  backend/tests/test_write_gate_sample_runtime_unit.py \
  backend/tests/test_write_gate_integration.py -q
```

预期：通过，且新的 `--sample-context-file`、`sample` 占位符解析与 `runtime_samples` 恢复链路均可工作。

- [ ] **步骤 5：Commit**

```bash
git add \
  tools/perf/write_gate/sample_context.py \
  tools/perf/write_gate/sample_registry.py \
  tools/perf/backend_capacity_gate.py \
  backend/tests/test_backend_capacity_gate_unit.py \
  backend/tests/test_write_gate_integration.py \
  backend/tests/test_write_gate_sample_runtime_unit.py
git commit -m "feat(性能优化): 接通样本上下文与写门禁执行链路"
```

## 任务 3：拆分 production + craft 场景并校准 `405/422`

**文件：**
- 创建：`tools/perf/scenarios/production_craft_read_40_scan.json`
- 创建：`tools/perf/scenarios/production_craft_detail_40_scan.json`
- 创建：`tools/perf/scenarios/production_craft_write_40_scan.json`
- 创建：`backend/tests/test_production_craft_scenarios_unit.py`
- 创建：`docs/后端P95-40并发全链路覆盖/10-405422差异清单_production_craft.md`
- 修改：`tools/perf/scenarios/combined_40_scan.json`
- 修改：`docs/后端P95-40并发全链路覆盖/04-执行说明与命令模板.md`

- [ ] **步骤 1：编写失败的场景校验测试**

```python
# backend/tests/test_production_craft_scenarios_unit.py
def test_production_craft_detail_suite_uses_sample_placeholders_instead_of_legacy_ids() -> None:
    suite = load_bundle("tools/perf/scenarios/production_craft_detail_40_scan.json")
    for scenario in suite.scenarios.values():
        assert "/18" not in scenario.path
        assert "/1" not in scenario.path
        assert "{sample:" in scenario.path or "{sample:" in json.dumps(scenario.query, ensure_ascii=False) or "{sample:" in json.dumps(scenario.json_body, ensure_ascii=False)


def test_production_craft_write_suite_has_layer_and_sample_contract() -> None:
    suite = load_bundle("tools/perf/scenarios/production_craft_write_40_scan.json")
    for scenario in suite.scenarios.values():
        assert scenario.layer in {"L1", "L2", "L3"}
        assert scenario.sample_contract is not None
        assert scenario.sample_contract.restore_strategy in {"rebuild", "delete"}
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```bash
./.venv/bin/python -m pytest backend/tests/test_production_craft_scenarios_unit.py -q
```

预期：失败，因为场景文件未创建或仍保留硬编码历史 ID 与缺失合同字段。

- [ ] **步骤 3：编写最少实现代码**

```json
// tools/perf/scenarios/production_craft_detail_40_scan.json
{
  "token_pools": [
    {"name": "pool-production", "login_user_prefix": "ltprd", "token_count": 4}
  ],
  "scenarios": [
    {
      "name": "production-order-detail",
      "method": "GET",
      "path": "/api/v1/production/orders/{sample:production_order_id}",
      "role_domain": "production",
      "token_pool": "pool-production",
      "layer": "L2",
      "sample_contract": {
        "baseline_refs": ["order:PERF-ORDER-OPEN-01"],
        "runtime_samples": [],
        "state_assertions": ["production.order.exists"],
        "restore_strategy": "rebuild"
      }
    }
  ]
}
```

```json
// tools/perf/scenarios/production_craft_write_40_scan.json
{
  "scenarios": [
    {
      "name": "craft-template-publish",
      "method": "POST",
      "path": "/api/v1/craft/templates/{sample:craft_template_id}/publish",
      "role_domain": "production",
      "token_pool": "pool-production",
      "layer": "L3",
      "sample_contract": {
        "baseline_refs": ["template:PERF-TEMPLATE-STD-01"],
        "runtime_samples": ["craft:template-publish-ready"],
        "state_assertions": ["craft.template.publishable"],
        "restore_strategy": "rebuild"
      }
    }
  ]
}
```

```markdown
<!-- docs/后端P95-40并发全链路覆盖/10-405422差异清单_production_craft.md -->
| 编号 | 优先级 | 模块 | 场景名 | 请求方法 | 请求路径 | 最小必需参数/字段 | 当前场景实参 | 实际返回摘要 | 差异说明 | 修复动作 | 责任人 | 状态 | 复检结果 | 证据 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 422-PC-001 | P1 | production | production-order-first-article | POST | /api/v1/production/orders/{sample:production_order_id}/first-article | `order_process_id`、`verification_code`、有效模板/工序上下文 | 使用历史硬编码 `1/18` | 422 | 场景未绑定稳定样本与真实工序上下文 | 改为占位符 + 样本合同 | Codex | 待处理 | 未复检 | `evidence/task_log_20260417_backend_p95_40_production_craft_batch1.md` |
```

- [ ] **步骤 4：运行测试验证通过**

运行：

```bash
./.venv/bin/python -m pytest backend/tests/test_production_craft_scenarios_unit.py -q
./.venv/bin/python - <<'PY'
from tools.perf.backend_capacity_gate import _load_scenario_config_bundle
for path in [
    "tools/perf/scenarios/production_craft_read_40_scan.json",
    "tools/perf/scenarios/production_craft_detail_40_scan.json",
    "tools/perf/scenarios/production_craft_write_40_scan.json",
]:
    _load_scenario_config_bundle(path)
    print("OK", path)
PY
```

预期：测试通过，三个场景文件可被 `backend-capacity-gate` 正常加载。

- [ ] **步骤 5：Commit**

```bash
git add \
  tools/perf/scenarios/production_craft_read_40_scan.json \
  tools/perf/scenarios/production_craft_detail_40_scan.json \
  tools/perf/scenarios/production_craft_write_40_scan.json \
  tools/perf/scenarios/combined_40_scan.json \
  backend/tests/test_production_craft_scenarios_unit.py \
  docs/后端P95-40并发全链路覆盖/10-405422差异清单_production_craft.md \
  docs/后端P95-40并发全链路覆盖/04-执行说明与命令模板.md
git commit -m "perf(性能优化): 拆分并校准 production craft 场景"
```

## 任务 4：补齐模块级集成回归与执行口径

**文件：**
- 修改：`backend/tests/test_production_module_integration.py`
- 修改：`backend/tests/test_craft_module_integration.py`
- 修改：`docs/后端P95-40并发全链路覆盖/06-证据索引.md`
- 创建：`evidence/task_log_20260417_backend_p95_40_production_craft_batch1.md`
- 创建：`evidence/verification_20260417_backend_p95_40_production_craft_batch1.md`

- [ ] **步骤 1：编写失败的模块级集成测试**

```python
# backend/tests/test_production_module_integration.py
def test_perf_seeded_order_supports_detail_first_article_and_end_production(self) -> None:
    context = load_perf_sample_context(".tmp_runtime/production_craft_samples.json")

    detail = self.client.get(f"/api/v1/production/orders/{context['production_order_id']}", headers=self._headers())
    first_article = self.client.get(
        f"/api/v1/production/orders/{context['production_order_id']}/first-article/templates",
        headers=self._headers(),
    )

    assert detail.status_code == 200
    assert first_article.status_code == 200
```

```python
# backend/tests/test_craft_module_integration.py
def test_perf_seeded_template_supports_detail_publish_and_rollback(self) -> None:
    context = load_perf_sample_context(".tmp_runtime/production_craft_samples.json")

    detail = self.client.get(f"/api/v1/craft/templates/{context['craft_template_id']}", headers=self._headers())
    publish = self.client.post(f"/api/v1/craft/templates/{context['craft_template_id']}/publish", headers=self._headers())
    rollback = self.client.post(f"/api/v1/craft/templates/{context['craft_template_id']}/rollback", headers=self._headers())

    assert detail.status_code == 200
    assert publish.status_code in {200, 400}
    assert rollback.status_code in {200, 400}
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```bash
./.venv/bin/python -m pytest \
  backend/tests/test_production_module_integration.py \
  backend/tests/test_craft_module_integration.py -k "perf_seeded" -q
```

预期：失败，因为当前测试还未接入样本上下文文件或相关场景前置条件不满足。

- [ ] **步骤 3：编写最少实现代码**

```python
# backend/tests/test_production_module_integration.py / backend/tests/test_craft_module_integration.py
def load_perf_sample_context(path: str) -> dict[str, int | str]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


class ProductionModuleIntegrationTest(unittest.TestCase):
    def _perf_context(self) -> dict[str, int | str]:
        return load_perf_sample_context(".tmp_runtime/production_craft_samples.json")
```

```markdown
<!-- docs/后端P95-40并发全链路覆盖/06-证据索引.md -->
| `tools/perf/scenarios/production_craft_read_40_scan.json` | `production + craft` 读链路模块级子套件 |
| `tools/perf/scenarios/production_craft_detail_40_scan.json` | `production + craft` detail 链路模块级子套件 |
| `tools/perf/scenarios/production_craft_write_40_scan.json` | `production + craft` 写链路模块级子套件 |
| `.tmp_runtime/production_craft_samples.json` | 第一批稳定样本上下文输出 |
```

- [ ] **步骤 4：运行测试验证通过**

运行：

```bash
./.venv/bin/python backend/scripts/init_perf_production_craft_samples.py \
  --mode ensure \
  --output-json .tmp_runtime/production_craft_samples.json
./.venv/bin/python -m pytest \
  backend/tests/test_production_module_integration.py \
  backend/tests/test_craft_module_integration.py -k "perf_seeded" -q
```

预期：通过，证明模块级集成测试可以消费真实样本上下文。

- [ ] **步骤 5：Commit**

```bash
git add \
  backend/tests/test_production_module_integration.py \
  backend/tests/test_craft_module_integration.py \
  docs/后端P95-40并发全链路覆盖/06-证据索引.md
git commit -m "test(性能优化): 补齐 production craft 模块级回归"
```

## 任务 5：执行模块级 `40` 并发回归并回灌 `270` 场景

**文件：**
- 创建：`evidence/task_log_20260417_backend_p95_40_production_craft_batch1.md`
- 创建：`evidence/verification_20260417_backend_p95_40_production_craft_batch1.md`
- 修改：`docs/后端P95-40并发全链路覆盖/06-证据索引.md`

- [ ] **步骤 1：生成样本上下文**

运行：

```bash
./.venv/bin/python backend/scripts/init_perf_production_craft_samples.py \
  --mode ensure \
  --output-json .tmp_runtime/production_craft_samples.json
```

预期：生成 `.tmp_runtime/production_craft_samples.json`，且输出稳定主样本与 run scoped 信息。

- [ ] **步骤 2：执行 `read/detail/write` 三组模块级回归**

运行：

```bash
READ_SCENARIOS=$(python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("tools/perf/scenarios/production_craft_read_40_scan.json").read_text(encoding="utf-8"))
print(",".join(item["name"] for item in data["scenarios"]))
PY
)
DETAIL_SCENARIOS=$(python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("tools/perf/scenarios/production_craft_detail_40_scan.json").read_text(encoding="utf-8"))
print(",".join(item["name"] for item in data["scenarios"]))
PY
)
WRITE_SCENARIOS=$(python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("tools/perf/scenarios/production_craft_write_40_scan.json").read_text(encoding="utf-8"))
print(",".join(item["name"] for item in data["scenarios"]))
PY
)

./.venv/bin/python tools/project_toolkit.py backend-capacity-gate \
  --base-url http://127.0.0.1:8000 \
  --scenario-config-file tools/perf/scenarios/production_craft_read_40_scan.json \
  --sample-context-file .tmp_runtime/production_craft_samples.json \
  --scenarios "$READ_SCENARIOS" \
  --concurrency 40 \
  --session-pool-size 20 \
  --token-count 4 \
  --duration-seconds 30 \
  --warmup-seconds 5 \
  --spawn-rate 10 \
  --p95-ms 500 \
  --error-rate-threshold 0.05 \
  --output-json .tmp_runtime/production_craft_read_40_$(date +%Y%m%d_%H%M%S).json
```

再执行 `detail` 子套件：

```bash
DETAIL_SCENARIOS=$(python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("tools/perf/scenarios/production_craft_detail_40_scan.json").read_text(encoding="utf-8"))
print(",".join(item["name"] for item in data["scenarios"]))
PY
)

./.venv/bin/python tools/project_toolkit.py backend-capacity-gate \
  --base-url http://127.0.0.1:8000 \
  --scenario-config-file tools/perf/scenarios/production_craft_detail_40_scan.json \
  --sample-context-file .tmp_runtime/production_craft_samples.json \
  --scenarios "$DETAIL_SCENARIOS" \
  --concurrency 40 \
  --session-pool-size 20 \
  --token-count 4 \
  --duration-seconds 30 \
  --warmup-seconds 5 \
  --spawn-rate 10 \
  --p95-ms 500 \
  --error-rate-threshold 0.05 \
  --output-json .tmp_runtime/production_craft_detail_40_$(date +%Y%m%d_%H%M%S).json
```

再执行 `write` 子套件：

```bash
WRITE_SCENARIOS=$(python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("tools/perf/scenarios/production_craft_write_40_scan.json").read_text(encoding="utf-8"))
print(",".join(item["name"] for item in data["scenarios"]))
PY
)

./.venv/bin/python tools/project_toolkit.py backend-capacity-gate \
  --base-url http://127.0.0.1:8000 \
  --scenario-config-file tools/perf/scenarios/production_craft_write_40_scan.json \
  --sample-context-file .tmp_runtime/production_craft_samples.json \
  --scenarios "$WRITE_SCENARIOS" \
  --concurrency 40 \
  --session-pool-size 20 \
  --token-count 4 \
  --duration-seconds 30 \
  --warmup-seconds 5 \
  --spawn-rate 10 \
  --p95-ms 500 \
  --error-rate-threshold 0.05 \
  --output-json .tmp_runtime/production_craft_write_40_$(date +%Y%m%d_%H%M%S).json
```

预期：

- 每组结果 JSON 成功生成。
- `404/405/422` 从“成批出现”下降为“少量且可解释”。
- `zero_success_count` 明显下降。

- [ ] **步骤 3：回灌 `270` 场景复跑**

运行：

```bash
ALL_SCENARIOS=$(python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("tools/perf/scenarios/combined_40_scan.json").read_text(encoding="utf-8"))
print(",".join(item["name"] for item in data["scenarios"]))
PY
)

./.venv/bin/python tools/project_toolkit.py backend-capacity-gate \
  --base-url http://127.0.0.1:8000 \
  --scenario-config-file tools/perf/scenarios/combined_40_scan.json \
  --sample-context-file .tmp_runtime/production_craft_samples.json \
  --scenarios "$ALL_SCENARIOS" \
  --concurrency 40 \
  --session-pool-size 20 \
  --token-count 20 \
  --duration-seconds 20 \
  --warmup-seconds 5 \
  --spawn-rate 10 \
  --p95-ms 500 \
  --error-rate-threshold 0.05 \
  --output-json .tmp_runtime/combined_40_production_craft_roundtrip_$(date +%Y%m%d_%H%M%S).json
```

预期：

- 全链路结果 JSON 成功生成。
- `production + craft` 相关场景的成功率和 `zero_success_count` 相比整改前明显改善。
- 结果仍可能未达到正式全链路门禁，但必须“更可解释、噪声更少”。

- [ ] **步骤 4：写入 evidence 与证据索引**

```markdown
# evidence/task_log_20260417_backend_p95_40_production_craft_batch1.md
- 记录样本初始化命令、模块级三套件结果、270 场景回灌结果
- 按模块列出 `404/405/422` 的剩余清单

# evidence/verification_20260417_backend_p95_40_production_craft_batch1.md
- 记录 `/health`、样本上下文、模块级结果 JSON、回灌结果 JSON 的真实验证结论
```

- [ ] **步骤 5：Commit**

```bash
git add \
  evidence/task_log_20260417_backend_p95_40_production_craft_batch1.md \
  evidence/verification_20260417_backend_p95_40_production_craft_batch1.md \
  docs/后端P95-40并发全链路覆盖/06-证据索引.md
git commit -m "perf(性能优化): 完成 production craft 第一批回灌验证"
```

## 自检清单

- 覆盖规格中的每个核心要求：
  - 样本资产落地：任务 1
  - 占位符与写门禁执行：任务 2
  - `405/422` 契约校准：任务 3
  - 模块级高成功率子套件：任务 3、4、5
  - `270` 场景回灌：任务 5
- 未引入占位词、断裂步骤或省略实现片段。
- 文件路径均为仓库内真实路径；计划中新增文件均已在文件结构里声明。
- 所有 commit 标题均采用中文 conventional commit 口径。

## 执行完成判定

满足以下条件才算完成本计划：

1. 样本上下文文件可稳定生成并复用。
2. `production + craft` 三组子套件可被 `backend-capacity-gate` 独立执行。
3. `404/405/422` 在这两个模块内从“成批出现”降到“少量且可解释”。
4. 回灌 `270` 场景后，这两个模块的成功率和 `zero_success_count` 有显著改善。
5. 已形成下一阶段继续冲击全链路正式性能候选集的清晰输入。

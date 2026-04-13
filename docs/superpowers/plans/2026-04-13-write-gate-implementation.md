# 后端写链路回归门禁 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立后端写链路分层回归门禁，让 `POST/PUT/PATCH/DELETE` 场景具备分层阈值、样本声明、复位能力、正式结果摘要与 evidence 闭环。

**Architecture:** 在现有 `tools/perf/backend_capacity_gate.py` 与 `tools/perf/scenarios/*.json` 基础上，新增写链路专用的分层配置、样本生命周期执行器、状态校验与复位框架，并通过 `backend/tests/` 的单元/集成测试把门禁 runner 固化下来。结果输出沿用现有 `.tmp_runtime` 与 `evidence/` 习惯，但新增写链路专用摘要字段，避免和读链路结果混写。

**Tech Stack:** Python 3、FastAPI、pytest、现有 `tools/perf/backend_capacity_gate.py`、JSON 场景配置、PostgreSQL 会话、PowerShell 执行命令、项目 evidence 文档体系

---

## 文件结构与职责

### 新增文件

- `tools/perf/write_gate/sample_contract.py`
  - 定义写链路样本声明、复位声明、状态校验声明的数据结构。
- `tools/perf/write_gate/sample_runtime.py`
  - 负责样本准备、复位、失败清理与结果回写。
- `tools/perf/write_gate/result_summary.py`
  - 负责写链路门禁结果聚合、错误结构分类、复位统计、分层汇总。
- `tools/perf/scenarios/write_samples_baseline.json`
  - 记录基线样本与场景样本映射的最小可执行配置。
- `backend/tests/test_write_gate_sample_runtime_unit.py`
  - 覆盖样本声明解析、复位执行和失败归因。
- `backend/tests/test_write_gate_result_summary_unit.py`
  - 覆盖分层结果聚合、错误结构与套件级判定。
- `backend/tests/test_write_gate_integration.py`
  - 覆盖一个最小真实写链路场景的准备、执行、校验、复位闭环。
- `evidence/verification_20260413_write_gate_plan.md`
  - 后续执行计划时的验证模板留痕入口。

### 修改文件

- `tools/perf/backend_capacity_gate.py`
  - 扩展写链路模式、分层阈值、样本执行与结果汇总接入点。
- `tools/perf/scenarios/write_operations_40_scan.json`
  - 为现有写链路场景补 `layer`、`sample_contract`、`restore_strategy`、`state_assertions`。
- `backend/tests/test_backend_capacity_gate_unit.py`
  - 补写链路分层与样本声明解析测试。
- `docs/后端P95-40并发全链路覆盖/07-整改计划.md`
  - 把“写链路门禁”从概念项更新成已计划实施项。
- `evidence/task_log_20260413_superpowers_next_step_recommendation.md`
  - 回填计划文档路径。

---

### Task 1: 固化写链路配置结构

**Files:**
- Create: `tools/perf/write_gate/sample_contract.py`
- Modify: `tools/perf/backend_capacity_gate.py`
- Modify: `backend/tests/test_backend_capacity_gate_unit.py`

- [ ] **Step 1: 先写失败测试，定义写链路场景必须带分层和样本声明**

```python
def test_load_write_scenario_requires_layer_and_sample_contract() -> None:
    config = {
        "scenarios": [
            {
                "name": "production-order-create",
                "method": "POST",
                "path": "/api/v1/production/orders",
                "requires_auth": True,
                "role_domain": "production",
                "token_pool": "pool-production",
                "layer": "L1",
                "sample_contract": {
                    "baseline_refs": ["product:active-default", "supplier:default"],
                    "runtime_samples": ["order:create-ready"],
                    "restore_strategy": "rebuild",
                },
            }
        ]
    }

    bundle = _load_scenario_config_bundle_from_payload(config)

    assert bundle.scenarios["production-order-create"].layer == "L1"
    assert bundle.scenarios["production-order-create"].sample_contract.restore_strategy == "rebuild"
```

- [ ] **Step 2: 运行测试，确认当前能力缺失**

Run: `pytest backend/tests/test_backend_capacity_gate_unit.py -k "layer_and_sample_contract" -v`
Expected: FAIL，报场景对象不存在 `layer` 或 `sample_contract`

- [ ] **Step 3: 增加写链路样本声明结构**

```python
from dataclasses import dataclass, field


@dataclass(slots=True)
class WriteSampleContract:
    baseline_refs: list[str] = field(default_factory=list)
    runtime_samples: list[str] = field(default_factory=list)
    restore_strategy: str = "rebuild"
    state_assertions: list[str] = field(default_factory=list)


@dataclass(slots=True)
class WriteScenarioLayer:
    code: str
    p95_ms: int
    p99_ms: int
    max_error_rate: float
```

- [ ] **Step 4: 在 `backend_capacity_gate.py` 中把 `layer/sample_contract` 接入场景解析**

```python
layer = raw.get("layer")
sample_contract_raw = raw.get("sample_contract") or {}
sample_contract = WriteSampleContract(
    baseline_refs=list(sample_contract_raw.get("baseline_refs") or []),
    runtime_samples=list(sample_contract_raw.get("runtime_samples") or []),
    restore_strategy=str(sample_contract_raw.get("restore_strategy") or "rebuild"),
    state_assertions=list(sample_contract_raw.get("state_assertions") or []),
)
```

- [ ] **Step 5: 复跑测试，确认解析能力通过**

Run: `pytest backend/tests/test_backend_capacity_gate_unit.py -k "layer_and_sample_contract" -v`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add tools/perf/write_gate/sample_contract.py tools/perf/backend_capacity_gate.py backend/tests/test_backend_capacity_gate_unit.py
git commit -m "补齐写链路场景分层与样本声明结构"
```

---

### Task 2: 实现样本准备与复位执行器

**Files:**
- Create: `tools/perf/write_gate/sample_runtime.py`
- Create: `backend/tests/test_write_gate_sample_runtime_unit.py`
- Modify: `tools/perf/scenarios/write_operations_40_scan.json`

- [ ] **Step 1: 先写失败测试，约束准备/复位执行顺序**

```python
def test_sample_runtime_runs_prepare_assert_restore_in_order() -> None:
    runtime = WriteSampleRuntime(registry={
        "order:create-ready": FakeSampleHandler(),
    })

    result = runtime.execute_contract(
        scenario_name="production-order-create",
        contract=WriteSampleContract(
            runtime_samples=["order:create-ready"],
            restore_strategy="rebuild",
            state_assertions=["order.exists"],
        ),
    )

    assert result.prepare_calls == ["order:create-ready"]
    assert result.restore_calls == ["order:create-ready"]
    assert result.failed is False
```

- [ ] **Step 2: 运行测试，确认执行器尚不存在**

Run: `pytest backend/tests/test_write_gate_sample_runtime_unit.py -v`
Expected: FAIL，报 `WriteSampleRuntime` 未定义

- [ ] **Step 3: 实现最小样本执行器**

```python
class WriteSampleRuntime:
    def __init__(self, registry: dict[str, SampleHandler]) -> None:
        self._registry = registry

    def execute_contract(self, scenario_name: str, contract: WriteSampleContract) -> SampleExecutionResult:
        prepared: list[str] = []
        restored: list[str] = []
        for sample_name in contract.runtime_samples:
            self._registry[sample_name].prepare()
            prepared.append(sample_name)
        for sample_name in reversed(contract.runtime_samples):
            self._registry[sample_name].restore(contract.restore_strategy)
            restored.append(sample_name)
        return SampleExecutionResult(
            scenario_name=scenario_name,
            prepare_calls=prepared,
            restore_calls=restored,
            failed=False,
        )
```

- [ ] **Step 4: 为写链路场景补最小样本声明**

```json
{
  "name": "production-order-create",
  "layer": "L1",
  "sample_contract": {
    "baseline_refs": ["product:active-default", "supplier:default"],
    "runtime_samples": ["order:create-ready"],
    "restore_strategy": "rebuild",
    "state_assertions": ["order.created"]
  }
}
```

- [ ] **Step 5: 复跑单测，确认样本执行器通过**

Run: `pytest backend/tests/test_write_gate_sample_runtime_unit.py -v`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add tools/perf/write_gate/sample_runtime.py tools/perf/scenarios/write_operations_40_scan.json backend/tests/test_write_gate_sample_runtime_unit.py
git commit -m "新增写链路样本准备与复位执行器"
```

---

### Task 3: 实现写链路结果汇总与分层判定

**Files:**
- Create: `tools/perf/write_gate/result_summary.py`
- Create: `backend/tests/test_write_gate_result_summary_unit.py`
- Modify: `tools/perf/backend_capacity_gate.py`

- [ ] **Step 1: 写失败测试，约束错误结构与分层汇总**

```python
def test_write_gate_summary_groups_results_by_layer_and_error_type() -> None:
    summary = build_write_gate_summary(
        [
            ScenarioResult(name="production-order-create", layer="L1", success=True, status_code=201, p95_ms=180, restore_ok=True),
            ScenarioResult(name="quality-supplier-create", layer="L2", success=False, status_code=422, p95_ms=90, restore_ok=True),
        ]
    )

    assert summary.by_layer["L1"].success_rate == 1.0
    assert summary.by_layer["L2"].error_types["422"] == 1
    assert summary.overall.restore_success_rate == 1.0
```

- [ ] **Step 2: 运行测试，确认汇总器尚不存在**

Run: `pytest backend/tests/test_write_gate_result_summary_unit.py -v`
Expected: FAIL，报 `build_write_gate_summary` 未定义

- [ ] **Step 3: 实现最小结果汇总器**

```python
def build_write_gate_summary(results: list[ScenarioResult]) -> WriteGateSummary:
    grouped: dict[str, list[ScenarioResult]] = defaultdict(list)
    for result in results:
        grouped[result.layer].append(result)
    return WriteGateSummary(
        overall=_build_bucket(results),
        by_layer={layer: _build_bucket(bucket) for layer, bucket in grouped.items()},
    )
```

- [ ] **Step 4: 在 `backend_capacity_gate.py` 中增加写链路模式输出**

```python
if args.gate_mode == "write":
    summary = build_write_gate_summary(results)
    output_payload["write_gate_summary"] = summary.to_dict()
```

- [ ] **Step 5: 复跑单测，确认分层汇总通过**

Run: `pytest backend/tests/test_write_gate_result_summary_unit.py -v`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add tools/perf/write_gate/result_summary.py tools/perf/backend_capacity_gate.py backend/tests/test_write_gate_result_summary_unit.py
git commit -m "新增写链路分层结果汇总能力"
```

---

### Task 4: 接入最小真实写链路闭环集成测试

**Files:**
- Create: `backend/tests/test_write_gate_integration.py`
- Modify: `backend/tests/test_production_module_integration.py`
- Modify: `backend/tests/test_quality_module_integration.py`

- [ ] **Step 1: 写失败测试，先打通一个真实 L1 写链路**

```python
def test_write_gate_can_prepare_execute_assert_and_restore_order_create() -> None:
    result = run_write_gate_scenario("production-order-create", concurrency=2, duration_seconds=3)

    assert result.success_rate == 1.0
    assert result.error_types == {}
    assert result.restore_success_rate == 1.0
```

- [ ] **Step 2: 运行测试，确认 runner 还未闭环**

Run: `pytest backend/tests/test_write_gate_integration.py::test_write_gate_can_prepare_execute_assert_and_restore_order_create -v`
Expected: FAIL，报 `run_write_gate_scenario` 不存在或结果字段缺失

- [ ] **Step 3: 复用现有集成测试建数逻辑，封装最小写链路 runner**

```python
def run_write_gate_scenario(name: str, concurrency: int, duration_seconds: int) -> WriteGateRunResult:
    scenario = load_write_scenario(name)
    sample_result = sample_runtime.prepare_for_scenario(scenario)
    try:
        raw_result = execute_write_scenario_once(scenario, concurrency=concurrency, duration_seconds=duration_seconds)
        state_check = sample_runtime.assert_state(scenario)
        return build_run_result(raw_result=raw_result, sample_result=sample_result, state_check=state_check)
    finally:
        sample_runtime.restore_for_scenario(scenario)
```

- [ ] **Step 4: 为一个 L2 场景补第二个真实闭环测试**

```python
def test_write_gate_can_restore_quality_supplier_create() -> None:
    result = run_write_gate_scenario("quality-supplier-create", concurrency=2, duration_seconds=3)

    assert result.success_rate == 1.0
    assert result.restore_success_rate == 1.0
```

- [ ] **Step 5: 复跑集成测试，确认最小真实闭环通过**

Run: `pytest backend/tests/test_write_gate_integration.py -v`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add backend/tests/test_write_gate_integration.py backend/tests/test_production_module_integration.py backend/tests/test_quality_module_integration.py
git commit -m "打通写链路门禁最小真实闭环测试"
```

---

### Task 5: 增加正式执行模式与 evidence 输出

**Files:**
- Create: `evidence/verification_20260413_write_gate_plan.md`
- Modify: `tools/perf/backend_capacity_gate.py`
- Modify: `docs/后端P95-40并发全链路覆盖/07-整改计划.md`
- Modify: `evidence/task_log_20260413_superpowers_next_step_recommendation.md`

- [ ] **Step 1: 写失败测试，约束正式输出包含写链路摘要**

```python
def test_write_gate_cli_output_contains_layer_summary_and_restore_rate() -> None:
    payload = run_capacity_gate_cli(["--gate-mode", "write", "--scenario-config-file", "tools/perf/scenarios/write_operations_40_scan.json"])

    assert "write_gate_summary" in payload
    assert "by_layer" in payload["write_gate_summary"]
    assert "restore_success_rate" in payload["write_gate_summary"]["overall"]
```

- [ ] **Step 2: 运行测试，确认 CLI 还没输出写链路摘要**

Run: `pytest backend/tests/test_backend_capacity_gate_unit.py -k "write_gate_cli_output" -v`
Expected: FAIL

- [ ] **Step 3: 在 CLI 输出中接入正式 evidence 结构**

```python
output_payload["write_gate_summary"] = summary.to_dict()
output_payload["evidence_hints"] = {
    "scene_snapshot": scene_snapshot_path,
    "result_summary": result_summary_path,
    "failure_breakdown": failure_breakdown_path,
}
```

- [ ] **Step 4: 回填整改计划与推荐日志中的计划路径**

```markdown
- 计划文档：`docs/superpowers/plans/2026-04-13-write-gate-implementation.md`
- 当前状态：待执行
- 执行模式：待用户选择 subagent-driven 或 inline execution
```

- [ ] **Step 5: 复跑测试，确认正式输出通过**

Run: `pytest backend/tests/test_backend_capacity_gate_unit.py -k "write_gate_cli_output" -v`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add tools/perf/backend_capacity_gate.py docs/后端P95-40并发全链路覆盖/07-整改计划.md evidence/task_log_20260413_superpowers_next_step_recommendation.md evidence/verification_20260413_write_gate_plan.md
git commit -m "补齐写链路门禁正式输出与留痕口径"
```

---

### Task 6: 全量验证与交付收口

**Files:**
- Modify: `evidence/verification_20260413_write_gate_plan.md`
- Modify: `evidence/task_log_20260413_superpowers_next_step_recommendation.md`

- [ ] **Step 1: 运行核心单元测试**

Run: `pytest backend/tests/test_backend_capacity_gate_unit.py backend/tests/test_write_gate_sample_runtime_unit.py backend/tests/test_write_gate_result_summary_unit.py -v`
Expected: PASS

- [ ] **Step 2: 运行最小真实集成测试**

Run: `pytest backend/tests/test_write_gate_integration.py -v`
Expected: PASS

- [ ] **Step 3: 运行一次最小写链路门禁 smoke**

Run: `python tools/perf/backend_capacity_gate.py --gate-mode write --scenario-config-file tools/perf/scenarios/write_operations_40_scan.json --scenario production-order-create --concurrency 2 --duration-seconds 3 --warmup-seconds 1`
Expected: 成功输出 `write_gate_summary`，且 `restore_success_rate` 存在

- [ ] **Step 4: 更新 verification evidence**

```markdown
- 单元测试：通过
- 集成测试：通过
- smoke：通过
- 残余风险：L3 高副作用场景仍需下一轮逐步纳入正式并发压测
```

- [ ] **Step 5: 检查工作区与输出物**

Run: `git status --short`
Expected: 仅出现本计划执行产生的预期改动

- [ ] **Step 6: 提交**

```bash
git add evidence/verification_20260413_write_gate_plan.md evidence/task_log_20260413_superpowers_next_step_recommendation.md
git commit -m "完成写链路门禁首轮实现与验证"
```

---

## Spec 覆盖自检

### 已覆盖的 spec 要点

1. 分层模型：Task 1、Task 3
2. 样本与复位：Task 2、Task 4
3. 指标与通过标准：Task 3、Task 5
4. 运行形态与留痕：Task 5、Task 6
5. 长期可演进性：Task 5 中的正式输出与计划回填为下一阶段统一门禁做准备

### 无占位符检查

1. 未使用 `TODO/TBD/implement later`
2. 每个代码步骤都给出具体代码片段
3. 每个验证步骤都给出具体命令与期望结果

### 一致性检查

1. 分层字段统一使用 `layer`
2. 样本声明统一使用 `sample_contract`
3. 复位策略统一使用 `restore_strategy`
4. 正式结果统一使用 `write_gate_summary`

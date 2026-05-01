# Graphify 图谱质量治理验收清单

## 1. 用途

本清单用于在 DeepSeek 完成 Graphify 质量治理后，由 Codex 做只读验收。

本清单只负责回答三类问题：

1. 这一轮产物是不是同一轮构建出来的。
2. 这一轮图谱质量是不是比当前版本更好。
3. 这一轮导航视图能不能回到源码与真实结构。

对应设计文档见：

- `docs/superpowers/specs/2026-05-01-graphify-quality-governance-design.md`

## 2. 验收输入

验收前应确保以下产物已由实施方提交：

1. `graphify-out/manifest.json`
2. `graphify-out/graph.json`
3. `graphify-out/GRAPH_REPORT.md`
4. `graphify-out/quality/metrics.json`
5. `graphify-out/navigation/entrypoints.md`
6. `graphify-out/navigation/contract-chains.md`
7. `graphify-out/navigation/impact-surfaces.md`
8. `graphify-out/raw/graph.raw.json`
9. `graphify-out/raw/GRAPH_REPORT.raw.md`

若其中任一核心产物缺失，本轮默认不通过。

## 3. 一致性验收

### 3.1 目标

确认所有正式产物来自同一轮构建，而不是中间产物混拼。

### 3.2 检查项

1. `manifest.json` 存在且字段齐全：
   - `run_id`
   - `generated_at`
   - `source_commit`
   - `corpus_hash`
   - `ignore_hash`
2. `graph.json` 与 `metrics.json` 中的 `run_id` 与 `manifest.json` 一致。
3. `GRAPH_REPORT.md` 摘要中的节点数、边数、社区数与 `metrics.json` 一致。
4. `raw/` 产物与正式产物同时存在。

### 3.3 推荐检查命令

```powershell
@'
import json
from pathlib import Path

root = Path(r"c:\Users\Donki\Desktop\ZYKJ_MES\graphify-out")
manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
graph = json.loads((root / "graph.json").read_text(encoding="utf-8"))
metrics = json.loads((root / "quality" / "metrics.json").read_text(encoding="utf-8"))

print("manifest.run_id =", manifest.get("run_id"))
print("graph.run_id    =", graph.get("graph", {}).get("run_id"))
print("metrics.run_id  =", metrics.get("run_id"))
print("nodes           =", len(graph.get("nodes", [])))
print("links           =", len(graph.get("links", [])))
'@ | python -
```

### 3.4 通过标准

1. 三处 `run_id` 相同。
2. `graph.json` 中 `nodes` 与 `links` 数量能被 `metrics.json` 对上。
3. 正式产物和 `raw/` 产物都存在。

## 4. 降噪验收

### 4.1 目标

确认泛节点、框架节点、迁移标题和测试基座不再主导主报告。

### 4.2 检查项

1. Top 10 或 Top 20 中，业务节点占多数。
2. `build`、`main`、`set`、`ValueError` 不再进入 Top 10。
3. Alembic revision 标题不再出现在主报告前列。
4. 迁移、测试、框架噪音若仍存在，也应只保留在 `raw/` 或被降权。

### 4.3 推荐检查命令

```powershell
rg -n "build|main|set|ValueError|package:flutter/material.dart|package:flutter_test/flutter_test.dart" `
  "c:\Users\Donki\Desktop\ZYKJ_MES\graphify-out\GRAPH_REPORT.md"
```

```powershell
rg -n "Revision ID:|Run migrations in 'offline' mode|Run migrations in 'online' mode" `
  "c:\Users\Donki\Desktop\ZYKJ_MES\graphify-out\GRAPH_REPORT.md"
```

### 4.4 通过标准

1. 主报告的 God Nodes 和摘要区不再被上述噪音主导。
2. 文本型迁移节点不再占据 `Knowledge Gaps` 前列。
3. `raw/graph.raw.json` 中仍保留原始事实，说明治理没有直接破坏原始层。

## 5. 业务语义验收

### 5.1 目标

确认社区名称和社区摘要已从编号型产物变成业务可读产物。

### 5.2 检查项

1. 社区不再主要显示为 `Community N`。
2. 至少能看到这些业务域名称：
   - 用户权限
   - 产品
   - 工艺
   - 生产
   - 质量
   - 设备
3. 核心对象所在社区具备可读摘要。

### 5.3 推荐检查命令

```powershell
rg -n "用户权限|产品|工艺|生产|质量|设备|Community " `
  "c:\Users\Donki\Desktop\ZYKJ_MES\graphify-out\GRAPH_REPORT.md"
```

### 5.4 通过标准

1. 前 20 个社区中，大多数已具备业务名称。
2. 至少 6 个主要业务域可直接从报告中读出来。

## 6. 导航视图验收

### 6.1 目标

确认治理后的图谱已经能回答研发中的高频问题，而不是只提供全量节点列表。

### 6.2 检查项

1. `entrypoints.md` 中有后端、前端、脚本、测试四类入口。
2. `contract-chains.md` 中至少有 3 条链路可以回到源码验证。
3. `impact-surfaces.md` 中至少有 3 个对象的上下游文件可被源码检索证实。

### 6.3 推荐抽查对象

1. `EquipmentLedgerItem`
2. `MaintenanceItemEntry`
3. `ProductionOrder`
4. `Role`
5. `AppSession`

### 6.4 推荐检查命令

```powershell
rg -n "EquipmentLedgerItem|MaintenanceItemEntry|ProductionOrder|Role|AppSession" `
  "c:\Users\Donki\Desktop\ZYKJ_MES\graphify-out\navigation\contract-chains.md" `
  "c:\Users\Donki\Desktop\ZYKJ_MES\graphify-out\navigation\impact-surfaces.md"
```

```powershell
rg -n "EquipmentLedgerItem|MaintenanceItemEntry|ProductionOrder|class AppSession|class ApiException|class Role" `
  "c:\Users\Donki\Desktop\ZYKJ_MES\backend" `
  "c:\Users\Donki\Desktop\ZYKJ_MES\frontend"
```

### 6.5 通过标准

1. 导航视图不只是列文件名，而是真能串起对象、接口、页面和测试。
2. 至少 3 条链路可被源码交叉复核。

## 7. 安全边界验收

### 7.1 目标

确认治理结果没有把本地敏感文件、缓存和噪音目录重新纳入图谱。

### 7.2 推荐检查命令

```powershell
$patterns = '\.env|\.tmp_runtime|settings\.local\.json|graphify-out\\cache|node_modules|__pycache__'
rg -n $patterns "c:\Users\Donki\Desktop\ZYKJ_MES\graphify-out\graph.json"
if ($LASTEXITCODE -eq 1) { "NO_MATCH" }
```

### 7.3 通过标准

1. 输出 `NO_MATCH` 或等价无命中结果。
2. `.graphifyignore` 未被放宽或回退。

## 8. 最终判定

满足以下条件则通过：

1. 一致性通过。
2. 降噪通过。
3. 业务语义通过。
4. 导航视图通过。
5. 安全边界通过。

任一项不满足，则本轮判定为“不通过，需补做后重验”。

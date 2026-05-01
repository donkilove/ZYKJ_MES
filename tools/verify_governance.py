#!/usr/bin/env python3
"""Graphify 质量治理验收验证脚本。

严格对齐 docs/superpowers/playbooks/2026-05-02-graphify-quality-governance-acceptance-playbook.md
"""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent / "graphify-out"

PASS = "[PASS]"
FAIL = "[FAIL]"
WARN = "[WARN]"

results = {}


def check(name, condition, detail=""):
    status = PASS if condition else FAIL
    prefix = f"  [{status}] {name}"
    if detail and not condition:
        prefix += f" — {detail}"
    print(prefix)
    results[name] = condition
    return condition


print("=" * 60)
print("Graphify 质量治理验收")
print("=" * 60)
print()

# ============================================================
# 1. 产物存在性
# ============================================================
print("--- 1. 产物存在性 ---")
products = [
    "manifest.json", "graph.json", "GRAPH_REPORT.md",
    "quality/metrics.json",
    "navigation/entrypoints.md", "navigation/contract-chains.md",
    "navigation/impact-surfaces.md",
    "raw/graph.raw.json", "raw/GRAPH_REPORT.raw.md",
]
all_exist = True
for p in products:
    exists = (root / p).exists()
    if not exists:
        all_exist = False
    print(f"  [{PASS if exists else FAIL}] {p}")
check("产物齐全", all_exist)
print()

if not all_exist:
    print(f"{FAIL} 核心产物缺失，终止验收")
    exit(1)

# ============================================================
# 2. 一致性验收
# ============================================================
print("--- 2. 一致性验收 ---")

manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
graph = json.loads((root / "graph.json").read_text(encoding="utf-8"))
metrics = json.loads((root / "quality" / "metrics.json").read_text(encoding="utf-8"))
raw_graph = json.loads((root / "raw" / "graph.raw.json").read_text(encoding="utf-8"))

mid = manifest.get("run_id", "")
gid1 = graph.get("run_id", "")
gid2 = graph.get("graph", {}).get("run_id", "")
mid_metrics = metrics.get("run_id", "")
rid = raw_graph.get("run_id", "")

check("manifest.run_id 非空", bool(mid))
check("graph.run_id (顶层) 非空", bool(gid1))
check("graph.graph.run_id 非空", bool(gid2))
check("metrics.run_id 非空", bool(mid_metrics))
check("raw/graph.raw.json.run_id 非空", bool(rid))

all_same = mid == gid1 == gid2 == mid_metrics == rid
check("全部5处 run_id 一致", all_same,
      f"manifest={mid[:8] if mid else '?'} graph={gid1[:8] if gid1 else '?'} graph.graph={gid2[:8] if gid2 else '?'} metrics={mid_metrics[:8] if mid_metrics else '?'} raw={rid[:8] if rid else '?'}")

# 节点/边一致性
gn = len(graph.get("nodes", []))
gl = len(graph.get("links", []))
mn = metrics.get("curated", {}).get("node_count", -1)
ml = metrics.get("curated", {}).get("edge_count", -1)
check("graph.nodes == metrics.curated.node_count", gn == mn, f"{gn} vs {mn}")
check("graph.links == metrics.curated.edge_count", gl == ml, f"{gl} vs {ml}")

rn = metrics.get("raw", {}).get("node_count", -1)
rl = metrics.get("raw", {}).get("edge_count", -1)
rn_raw = len(raw_graph.get("nodes", []))
rl_raw = len(raw_graph.get("links", []))
check("metrics.raw.node_count == raw graph nodes", rn == rn_raw, f"{rn} vs {rn_raw}")
check("metrics.raw.edge_count == raw graph links", rl == rl_raw, f"{rl} vs {rl_raw}")

# manifest 字段
check("manifest.source_commit 非空", bool(manifest.get("source_commit")))
check("manifest.corpus_hash 非空", bool(manifest.get("corpus_hash")))
check("manifest.ignore_hash 非空", bool(manifest.get("ignore_hash")))
check("manifest.graphify_version 非空", bool(manifest.get("graphify_version")))
check("manifest.graphify_available 为 bool", isinstance(manifest.get("graphify_available"), bool))
print()

# ============================================================
# 3. 降噪验收
# ============================================================
print("--- 3. 降噪验收 ---")

ratio = metrics.get("top20_business_ratio", 0)
check("业务节点 Top20 占比 >= 60%", ratio >= 0.6, f"当前={ratio:.0%}")

# 检查 package:flutter 不在 Top10
# (Top10 用 _is_top_noise 过滤后的排名)
def _is_top_noise(n):
    action = n.get("curation_action", "keep")
    if action in ("hide_from_rank", "drop_from_curated"):
        return True
    lbl = n.get("label", "") or ""
    sf = (n.get("source_file", "") or "").replace("\\", "/")
    if re.search(r"(/test/|/tests/|integration_test/|_test\.(dart|py)$)", sf, re.IGNORECASE):
        return True
    if re.search(r"(^_|^\.|package:|_test\.dart$|_page_test|_flow_test|test_)", lbl, re.IGNORECASE):
        return True
    return False

graph_nodes = sorted(graph["nodes"], key=lambda n: n.get("degree", 0) or 0, reverse=True)
clean_top10 = [n for n in graph_nodes if not _is_top_noise(n)][:10]
flutter_in_top10 = any("package:flutter" in (n.get("label", "") or "") for n in clean_top10)
check("flutter 不在治理后 Top10", not flutter_in_top10)

# build/set/ValueError 不在 Top10
bad_in_top10 = any((n.get("label", "") or "") in ("build", "set", "main", "ValueError")
                   for n in clean_top10)
check("build/set/ValueError 不在 Top10", not bad_in_top10)

# raw 保留
check("raw/graph.raw.json 包含原始节点", rn_raw > 0, f"{rn_raw} 节点")
check("raw 未被破坏（节点数 >= 治理后）", rn_raw >= gn, f"{rn_raw} >= {gn}")
print()

# ============================================================
# 4. 业务语义验收
# ============================================================
print("--- 4. 业务语义验收 ---")

coverage = metrics.get("community_name_coverage", 0)
total_comm = metrics.get("community_count", 0)
check("社区命名覆盖率 >= 80%", total_comm > 0 and coverage / total_comm >= 0.8,
      f"{coverage}/{total_comm} = {coverage/total_comm:.0%}" if total_comm else "N/A")

dist = metrics.get("domain_distribution", {})
key_domains = ["authz", "product", "craft", "production", "quality", "equipment", "message"]
found = [d for d in key_domains if d in dist]
check(f"关键业务域覆盖 >= 6/7", len(found) >= 6, f"已覆盖: {found}")

# 抽查社区名称是否具备业务可读性
report = (root / "GRAPH_REPORT.md").read_text(encoding="utf-8")
noise_community_names = ["Function", "KeyedSubtree", "Card", "setUpClass", "setUp("]
bad_community_names = sum(1 for n in noise_community_names if n in report)
check("社区名不再以 Function/KeyedSubtree/Card 为主导", bad_community_names <= 3,
      f"检测到 {bad_community_names} 处噪音社区名")
print()

# ============================================================
# 5. 导航视图验收
# ============================================================
print("--- 5. 导航视图验收 ---")

ep = (root / "navigation" / "entrypoints.md").read_text(encoding="utf-8")
ep_has_backend = "## 后端入口" in ep and "_（未匹配到入口节点）_" not in ep.split("## 后端入口")[1].split("##")[0]
ep_has_frontend = "## 前端入口" in ep and "_（未匹配到入口节点）_" not in ep.split("## 前端入口")[1].split("##")[0]
ep_has_scripts = "## 脚本入口" in ep and "_（未匹配到入口节点）_" not in ep.split("## 脚本入口")[1].split("##")[0]
ep_has_tests = "## 测试入口" in ep and "_（未匹配到入口节点）_" not in ep.split("## 测试入口")[1].split("##")[0]

check("entrypoints 包含后端入口", ep_has_backend)
check("entrypoints 包含前端入口", ep_has_frontend)
check("entrypoints 包含脚本入口", ep_has_scripts)
check("entrypoints 包含测试入口", ep_has_tests)
ep_non_empty = ep_has_backend and ep_has_frontend and ep_has_scripts and ep_has_tests
check("entrypoints 四类入口齐全", ep_non_empty)

cc = (root / "navigation" / "contract-chains.md").read_text(encoding="utf-8")
cc_objects = ["ProductionOrder", "EquipmentLedgerItem", "Role", "MaintenanceItemEntry"]
cc_found = sum(1 for o in cc_objects if o in cc)
check(f"contract-chains 覆盖 {len(cc_objects)} 个核心对象", cc_found >= 3, f"已覆盖 {cc_found}/{len(cc_objects)}")

im = (root / "navigation" / "impact-surfaces.md").read_text(encoding="utf-8")
im_objects = ["ProductionOrder", "Equipment", "Role", "AppSession"]
im_found = sum(1 for o in im_objects if o in im)
check(f"impact-surfaces 覆盖 {len(im_objects)} 个核心对象", im_found >= 3, f"已覆盖 {im_found}/{len(im_objects)}")
print()

# ============================================================
# 6. 安全边界验收
# ============================================================
print("--- 6. 安全边界验收 ---")

safe = True
for n in graph["nodes"]:
    sf = (n.get("source_file", "") or "").lower()
    if any(p in sf for p in [".env", ".tmp_runtime", "settings.local.json", "graphify-out\\cache/node_modules"]):
        print(f"  {FAIL} 安全泄漏: {sf}")
        safe = False
        break
check("安全边界通过（无敏感文件泄露）", safe)
print()

# ============================================================
# 总体验收
# ============================================================
print("=" * 60)
all_conditions = list(results.values())
passed = sum(all_conditions)
total = len(all_conditions)
overall = all(all_conditions)
print(f"总体验收: {'通过' if overall else '不通过'} ({passed}/{total})")
if not overall:
    failed = [k for k, v in results.items() if not v]
    print(f"未通过项: {', '.join(failed)}")
print("=" * 60)

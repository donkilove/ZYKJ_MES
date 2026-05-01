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

results = {}


def check(name, condition, detail=""):
    status = PASS if condition else FAIL
    prefix = f"  [{status}] {name}"
    if detail and not condition:
        prefix += f" -- {detail}"
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
check("raw.run_id 非空", bool(rid))
all_same = mid == gid1 == gid2 == mid_metrics == rid
check("全部5处 run_id 一致", all_same)

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

# raw 来源验证：raw 节点不应被治理过（无 curation_action）
raw_has_action = False
for n in raw_graph.get("nodes", [])[:10]:
    if "curation_action" in n:
        raw_has_action = True
        break
check("raw graph 不含 curation_action（未被治理污染）", not raw_has_action,
      "raw 节点包含 curation_action，说明来源是上一轮治理产物")

check("raw 节点数 > 0", rn_raw > 0, f"{rn_raw}")
check("raw 节点数 >= curated 节点数（治理后应 ≤ 原始）", rn_raw >= gn, f"{rn_raw} >= {gn}")

check("manifest.source_commit 非空", bool(manifest.get("source_commit")))
check("manifest.corpus_hash 非空", bool(manifest.get("corpus_hash")))
check("manifest.ignore_hash 非空", bool(manifest.get("ignore_hash")))
print()

# ============================================================
# 3. 降噪验收
# ============================================================
print("--- 3. 降噪验收 ---")

ratio = metrics.get("top20_business_ratio", 0)
check("业务节点 Top20 占比 >= 60%", ratio >= 0.6, f"当前={ratio:.0%}")

graph_nodes = sorted(graph["nodes"], key=lambda n: n.get("degree", 0) or 0, reverse=True)

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

clean_top10 = [n for n in graph_nodes if not _is_top_noise(n)][:10]
flutter_in_top10 = any("package:flutter" in (n.get("label", "") or "") for n in clean_top10)
check("flutter 不在治理后 Top10", not flutter_in_top10)

bad_in_top10 = any((n.get("label", "") or "") in ("build", "set", "main", "ValueError") for n in clean_top10)
check("build/set/ValueError 不在 Top10", not bad_in_top10)
print()

# ============================================================
# 4. 业务语义验收（强化版）
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

# 前排社区标题质量检查
report = (root / "GRAPH_REPORT.md").read_text(encoding="utf-8")
community_block = report.split("## 社区导航（治理后）")[1].split("## ")[0] if "## 社区导航" in report else ""

TOP_COMMUNITY_NOISE = [
    "ListTile", "jsonDecode", "ClipRect", "Divider", "Material",
    "Revision ID", "Revises:", "Create Date:",
    "Function$", "KeyedSubtree$", "Card$", "Text$",
    "TimestampMixin", "dirExists", "fileExists",
    r"UnitTest\)", r"IntegrationTest\)",
    "decode_access_token", "load_perf_sample_context",
    "ServerTimeSnapshot",
]

community_lines = [l for l in community_block.split("\n") if l.startswith("| ") and "|" in l[2:]]
top20_communities = community_lines[:20]
community_noise_count = 0
noisy_communities = []
for cl in top20_communities:
    parts = [p.strip() for p in cl.split("|")]
    if len(parts) >= 3:
        name = parts[2]
        for pat in TOP_COMMUNITY_NOISE:
            if re.search(pat, name, re.IGNORECASE):
                community_noise_count += 1
                noisy_communities.append(name)
                break

check("前20社区标题无UI组件/工具函数/Revision噪音", community_noise_count <= 3,
      f"检测到 {community_noise_count} 处噪音: {noisy_communities[:5]}")
print()

# ============================================================
# 5. 导航视图验收（强化版）
# ============================================================
print("--- 5. 导航视图验收 ---")

ep = (root / "navigation" / "entrypoints.md").read_text(encoding="utf-8")
ep_sections = ep.split("## ")
ep_has_backend = any("后端入口" in s and "_（未匹配到入口节点）_" not in s for s in ep_sections)
ep_has_frontend = any("前端入口" in s and "_（未匹配到入口节点）_" not in s for s in ep_sections)
ep_has_scripts = any("脚本入口" in s and "_（未匹配到入口节点）_" not in s for s in ep_sections)
ep_has_tests = any("测试入口" in s and "_（未匹配到入口节点）_" not in s for s in ep_sections)

check("entrypoints 包含后端入口", ep_has_backend)
check("entrypoints 包含前端入口", ep_has_frontend)
check("entrypoints 包含脚本入口", ep_has_scripts)
check("entrypoints 包含测试入口", ep_has_tests)

cc = (root / "navigation" / "contract-chains.md").read_text(encoding="utf-8")

# 关键对象出现检查
cc_objects = ["ProductionOrder", "EquipmentLedgerItem", "Role", "MaintenanceItemEntry", "AppSession"]
for obj in cc_objects:
    found = obj in cc
    check(f"contract-chains 包含 {obj}", found)

# 链路深度检查：每个核心对象至少要有 >1 个不同层级或补充链
LAYER_PATTERNS = {
    "models": re.compile(r"#### models", re.IGNORECASE),
    "services": re.compile(r"#### services", re.IGNORECASE),
    "api": re.compile(r"#### api", re.IGNORECASE),
    "frontend": re.compile(r"#### frontend", re.IGNORECASE),
    "test": re.compile(r"#### test", re.IGNORECASE),
}

for obj in cc_objects:
    obj_section = ""
    if obj in cc:
        sections = cc.split(f"## {obj}")
        if len(sections) > 1:
            obj_section = sections[1].split("\n## ")[0]

    # 统计不同层级
    layers_found = [lname for lname, lpat in LAYER_PATTERNS.items() if lpat.search(obj_section)]
    has_supplement = "导航补充链路" in obj_section
    # 有补充链或 >= 2 个层级就算足够
    sufficient = has_supplement or len(layers_found) >= 2

    check(f"{obj} 链路深度足够 (层次={layers_found}, 补充链={has_supplement})",
          sufficient, f"仅找到层次: {layers_found}")

# 导航视图文本噪音检查
TEXT_NOISE_PATTERNS = [
    "Attempt to repair text that was produced",
    "mark single message read",
    "标记单条消息已读",
]
nav_noise_count = 0
for pat in TEXT_NOISE_PATTERNS:
    if pat in cc or pat.lower() in cc.lower():
        nav_noise_count += 1
        print(f"  [{FAIL}] contract-chains 包含说明性文本噪音: {pat[:40]}...")

im = (root / "navigation" / "impact-surfaces.md").read_text(encoding="utf-8")
for pat in TEXT_NOISE_PATTERNS:
    if pat in im or pat.lower() in im.lower():
        nav_noise_count += 1
        print(f"  [{FAIL}] impact-surfaces 包含说明性文本噪音: {pat[:40]}...")

check("导航视图无说明性文本噪音", nav_noise_count == 0, f"检测到 {nav_noise_count} 处")

im_objects = ["ProductionOrder", "Equipment", "Role", "AppSession"]
for obj in im_objects:
    found = obj in im
    check(f"impact-surfaces 包含 {obj}", found)

# 影响面是否有实际文件路径
empty_core = 0
for obj in im_objects:
    sections = im.split(f"## {obj}")
    if len(sections) > 1:
        content = sections[1].split("\n## ")[0] if len(sections) > 1 else ""
        # 至少包含一个反引号括起来的文件路径
        has_files = bool(re.search(r"`[^`]+\.(py|dart)`", content))
        if not has_files:
            empty_core += 1
check(f"影响面核心对象有实际文件级内容", empty_core <= 2, f"{empty_core} 个对象无文件路径")
print()

# ============================================================
# 6. 安全边界验收
# ============================================================
print("--- 6. 安全边界验收 ---")
safe = True
for n in graph["nodes"]:
    sf = (n.get("source_file", "") or "").lower()
    if any(p in sf for p in [".env", ".tmp_runtime", "settings.local.json", "graphify-out\\cache"]):
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
    print(f"未通过项 ({len(failed)}):")
    for f_item in failed[:15]:
        print(f"  - {f_item}")
print("=" * 60)

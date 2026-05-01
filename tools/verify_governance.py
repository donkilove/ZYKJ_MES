#!/usr/bin/env python3
"""Graphify 质量治理验收验证脚本。"""
import json
from pathlib import Path

root = Path(r"C:\Users\Donki\Desktop\ZYKJ_MES\graphify-out")

print("=" * 60)
print("Graphify 质量治理验收")
print("=" * 60)

# 1. 产物存在性
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
    status = "OK" if exists else "MISSING"
    if not exists:
        all_exist = False
    print(f"  [{status}] {p}")
print(f"\n产物齐全: {all_exist}")
print()

# 2. 一致性
manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
graph = json.loads((root / "graph.json").read_text(encoding="utf-8"))
metrics = json.loads((root / "quality" / "metrics.json").read_text(encoding="utf-8"))
raw_graph = json.loads((root / "raw" / "graph.raw.json").read_text(encoding="utf-8"))

same_run_id = manifest["run_id"] == graph.get("run_id") == metrics.get("run_id")
nodes_match = len(graph["nodes"]) == metrics["curated_nodes"]
links_match = len(graph["links"]) == metrics["curated_links"]
raw_preserved = len(raw_graph["nodes"]) == 7642

print("一致性:")
print(f"  run_id相同: {same_run_id} ({manifest['run_id'][:8]}...)")
print(f"  节点数匹配: {nodes_match} ({len(graph['nodes'])} == {metrics['curated_nodes']})")
print(f"  边数匹配:   {links_match} ({len(graph['links'])} == {metrics['curated_links']})")
print(f"  raw保留:    {raw_preserved} (原始7642节点)")
print(f"  source_commit: {manifest.get('source_commit')}")
print(f"  corpus_hash:   {manifest.get('corpus_hash')}")
print(f"  ignore_hash:   {manifest.get('ignore_hash')}")
print()

# 3. 降噪
print("降噪:")
print(f"  业务节点Top20占比: {metrics['top20_business_ratio']:.0%}")
print(f"  已滤除节点: {metrics['nodes_dropped']}")
print(f"  已隐藏节点: {metrics['nodes_hidden_from_rank']}")
print(f"  已降权节点: {metrics['nodes_downweighted']}")

# 检查 package:flutter 不在 Top 10
graph_nodes = sorted(graph["nodes"], key=lambda n: n.get("degree", 0) or 0, reverse=True)
top10_has_flutter = any("package:flutter" in (n.get("label", "") or "") for n in graph_nodes[:10])
print(f"  flutter不在Top10: {not top10_has_flutter}")
print()

# 4. 语义
print("业务语义:")
print(f"  社区命名覆盖率: {metrics['community_name_coverage']}/{metrics['community_count']}")

# Check key business domains in distribution
dist = metrics.get("domain_distribution", {})
key_domains = ["authz", "product", "craft", "production", "quality", "equipment", "message"]
found_domains = [d for d in key_domains if d in dist]
print(f"  关键业务域覆盖: {len(found_domains)}/7 {found_domains}")
print()

# 5. 导航视图
print("导航视图:")
for nav in ["entrypoints.md", "contract-chains.md", "impact-surfaces.md"]:
    content = (root / "navigation" / nav).read_text(encoding="utf-8")
    lines = len(content.split("\n"))
    print(f"  {nav}: {lines} 行")

# Check key objects in contract-chains
cc = (root / "navigation" / "contract-chains.md").read_text(encoding="utf-8")
key_objects = ["ProductionOrder", "EquipmentLedgerItem", "Role", "MaintenanceItemEntry"]
for obj in key_objects:
    found = obj in cc
    print(f"  contract-chains含{obj}: {found}")

is_content = (root / "navigation" / "impact-surfaces.md").read_text(encoding="utf-8")
for obj in ["ProductionOrder", "Equipment", "Role", "AppSession"]:
    found = obj in is_content
    print(f"  impact-surfaces含{obj}: {found}")
print()

# 6. 安全边界
safe = True
for n in graph["nodes"]:
    sf = (n.get("source_file", "") or "").lower()
    if any(p in sf for p in [".env", ".tmp_runtime", "settings.local.json", "graphify-out\\cache"]):
        print(f"  SAFETY FAIL: {sf}")
        safe = False
        break
print(f"安全边界: {'通过' if safe else '失败'}")

print()
print("=" * 60)
overall = all_exist and same_run_id and nodes_match and links_match and raw_preserved and safe
print(f"总体验收: {'通过' if overall else '未通过'}")
print("=" * 60)

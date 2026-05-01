#!/usr/bin/env python3
"""Graphify 知识图谱语义增强脚本。

基于 project-memory 中的语义知识，修复 graph.json 中的核心实体关系：
1. 查找核心业务模型节点
2. 添加已验证的语义边（EXTRACTED, confidence_score=1.0）
3. 删除核心节点上错误的 INFERRED 边（测试/Handler/无关文件）
4. 统一核心业务实体社区
"""
import json
import os
import sys

GRAPH_PATH = "graphify-out/graph.json"
CORE_COMMUNITY = 4  # ProductionOrder 所在的社区

# =============================================================================
# Step 1: 加载并构建节点查找表
# =============================================================================
print("=" * 60)
print("Step 1: 加载 graph.json 并构建 id -> node 查找字典")
print("=" * 60)

with open(GRAPH_PATH, "r", encoding="utf-8") as f:
    g = json.load(f)

node_by_id = {n["id"]: n for n in g["nodes"]}
print(f"已加载 {len(g['nodes'])} 个节点, {len(g['links'])} 条边")

# =============================================================================
# Step 2: 查找核心业务节点
# =============================================================================
print("\n" + "=" * 60)
print("Step 2: 搜索核心业务模型节点")
print("=" * 60)

# (label, source_file_suffix, must_exist)
targets = [
    ("ProductionOrder", "production_order.py", True),
    ("ProductionOrderProcess", "production_order_process.py", True),
    ("ProductionSubOrder", "production_sub_order.py", False),
    ("ProductionRecord", "production_record.py", False),
    ("ProductionScrapStatistics", "production_scrap_statistics.py", False),
    ("ProductionAssistAuthorization", "production_assist_authorization.py", False),
    ("Equipment", "equipment.py", True),
    ("FirstArticleRecord", "first_article_record.py", False),
    ("RepairOrder", "repair_order.py", False),
    ("Product", "product.py", False),
    ("Process", "process.py", False),
    ("User", "user.py", False),
    ("Role", "role.py", False),
    ("PermissionCatalog", "permission_catalog.py", False),
    ("MaintenancePlan", "maintenance_plan.py", False),
    ("MaintenanceWorkOrder", "maintenance_work_order.py", False),
    ("MaintenanceItem", "maintenance_item.py", False),
    ("MaintenanceRecord", "maintenance_record.py", False),
]

core_nodes = {}  # label -> node dict
missing_targets = []

for label, file_suffix, must_exist in targets:
    matches = []
    for n in g["nodes"]:
        sf = n.get("source_file", "")
        if sf.endswith(file_suffix) and n["label"] == label:
            matches.append(n)
    
    if matches:
        # 取第一个匹配（模型类节点通常在 models/ 下）
        model_matches = [n for n in matches if "models" in n.get("source_file", "")]
        chosen = model_matches[0] if model_matches else matches[0]
        core_nodes[label] = chosen
        print(f"  [OK] {label}: id={chosen['id']}, community={chosen.get('community')}, file={chosen.get('source_file')}")
    else:
        # 宽泛搜索
        for n in g["nodes"]:
            sf = n.get("source_file", "")
            if file_suffix in sf and n["label"] == label:
                core_nodes[label] = n
                print(f"  [OK-broad] {label}: id={n['id']}, community={n.get('community')}, file={n.get('source_file')}")
                break
        else:
            if must_exist:
                print(f"  [ERR] {label}: 必须存在但未找到!")
                sys.exit(1)
            else:
                print(f"  [MISS] {label}: 图中缺失 (file_suffix={file_suffix})")
                missing_targets.append(label)

# 检查 QualityInspection 和 PagePermission 是否实际存在源文件
quality_inspection_file = os.path.join("backend", "app", "models", "quality_inspection.py")
page_permission_file = os.path.join("backend", "app", "models", "authz_page_permission.py")

print(f"\n  QualityInspection 源文件存在: {os.path.exists(quality_inspection_file)}")
print(f"  PagePermission 源文件存在: {os.path.exists(page_permission_file)}")

# =============================================================================
# Step 3: 创建缺失的关键节点
# =============================================================================
print("\n" + "=" * 60)
print("Step 3: 创建缺失的关键节点")
print("=" * 60)

added_nodes = 0

# QualityInspection - 源文件不存在，不创建
if os.path.exists(quality_inspection_file):
    new_q = {
        "id": "models_quality_inspection_qualityinspection",
        "label": "QualityInspection",
        "file_type": "code",
        "source_file": "backend\\app\\models\\quality_inspection.py",
        "source_location": "L1",
        "community": CORE_COMMUNITY,
        "norm_label": "QualityInspection",
    }
    g["nodes"].append(new_q)
    node_by_id[new_q["id"]] = new_q
    core_nodes["QualityInspection"] = new_q
    added_nodes += 1
    print(f"  [ADD] QualityInspection (id={new_q['id']})")
else:
    print("  [SKIP] QualityInspection: 源文件不存在，不创建虚构节点")

# PagePermission - 源文件不存在，使用 PermissionCatalog
if os.path.exists(page_permission_file):
    new_pp = {
        "id": "models_authz_page_permission_pagepermission",
        "label": "PagePermission",
        "file_type": "code",
        "source_file": "backend\\app\\models\\authz_page_permission.py",
        "source_location": "L1",
        "community": CORE_COMMUNITY,
        "norm_label": "PagePermission",
    }
    g["nodes"].append(new_pp)
    node_by_id[new_pp["id"]] = new_pp
    core_nodes["PagePermission"] = new_pp
    added_nodes += 1
    print(f"  [ADD] PagePermission (id={new_pp['id']})")
else:
    print("  [SKIP] PagePermission: 源文件不存在，使用 PermissionCatalog 代替")

# =============================================================================
# Step 4: 添加已验证的语义边
# =============================================================================
print("\n" + "=" * 60)
print("Step 4: 添加已验证的语义边 (EXTRACTED, confidence=1.0)")
print("=" * 60)

# 构建现有边集合（用于去重，用冻结集）
existing_edges = set()
for link in g["links"]:
    existing_edges.add((link["source"], link["target"], link.get("relation", "")))

def add_edge(src_label, tgt_label, relation):
    """添加一条 EXTRACTED 边，如果源和目标都存在且边不存在则添加"""
    src_id = core_nodes[src_label]["id"] if src_label in core_nodes else None
    tgt_id = core_nodes[tgt_label]["id"] if tgt_label in core_nodes else None
    
    if src_id is None:
        print(f"  [SKIP] {src_label} -[{relation}]-> {tgt_label}: 源节点不存在")
        return False
    if tgt_id is None:
        print(f"  [SKIP] {src_label} -[{relation}]-> {tgt_label}: 目标节点不存在")
        return False
    
    # 检查是否已存在
    key = (src_id, tgt_id, relation)
    if key in existing_edges:
        print(f"  [DUP] {src_label} -[{relation}]-> {tgt_label}: 已存在，跳过")
        return False
    
    new_link = {
        "source": src_id,
        "target": tgt_id,
        "relation": relation,
        "confidence": "EXTRACTED",
        "confidence_score": 1.0,
        "source_file": "docs/project-memory/backend-models.md",
        "source_location": "semantic_enrichment",
    }
    g["links"].append(new_link)
    existing_edges.add(key)
    print(f"  [ADD] {src_label} -[{relation}]-> {tgt_label}")
    return True

added_edges = 0

# 生产执行链
print("\n--- 生产执行链 ---")
added_edges += add_edge("ProductionOrder", "ProductionOrderProcess", "has_many")
added_edges += add_edge("ProductionOrder", "ProductionSubOrder", "has_many")
added_edges += add_edge("ProductionOrder", "ProductionRecord", "has_many")
added_edges += add_edge("ProductionOrder", "ProductionScrapStatistics", "has_one")
added_edges += add_edge("ProductionOrder", "FirstArticleRecord", "has_one")
added_edges += add_edge("ProductionOrder", "RepairOrder", "has_many")

# 生产辅助
print("\n--- 生产辅助 ---")
added_edges += add_edge("ProductionOrder", "ProductionAssistAuthorization", "has_one")

# 工艺关联
print("\n--- 工艺关联 ---")
added_edges += add_edge("ProductionOrder", "Product", "belongs_to")
added_edges += add_edge("ProductionOrder", "Process", "belongs_to")

# 设备关联 - 仅在存在 equipment_id 外键时添加
# ProductionOrder 没有 equipment_id 外键，跳过
print("\n--- 设备关联 ---")
print("  [SKIP] ProductionOrder --belongs_to--> Equipment: ProductionOrder 无 equipment_id 外键")

# 权限链
print("\n--- 权限链 ---")
added_edges += add_edge("User", "Role", "has_one")
# Role -> PermissionCatalog (使用 PermissionCatalog 代替 PagePermission)
added_edges += add_edge("Role", "PermissionCatalog", "has_many")

# 设备维保链
print("\n--- 设备维保链 ---")
added_edges += add_edge("Equipment", "MaintenancePlan", "has_many")
added_edges += add_edge("Equipment", "MaintenanceWorkOrder", "has_many")

# 工序维保链补充
print("\n--- 工序维保补充 ---")
added_edges += add_edge("MaintenancePlan", "MaintenanceItem", "belongs_to")
added_edges += add_edge("MaintenanceWorkOrder", "MaintenancePlan", "belongs_to")

print(f"\n共添加 {added_edges} 条语义边")

# =============================================================================
# Step 5: 清理错误推断边
# =============================================================================
print("\n" + "=" * 60)
print("Step 5: 清理核心业务节点上的错误 INFERRED 边")
print("=" * 60)

core_id_set = set(n["id"] for n in core_nodes.values())

new_links = []
removed_edges = 0
removed_details = []

for link in g["links"]:
    # 只清理 INFERRED 边
    if link.get("confidence") != "INFERRED":
        new_links.append(link)
        continue
    
    # 只清理涉及核心节点的边
    if link["source"] not in core_id_set and link["target"] not in core_id_set:
        new_links.append(link)
        continue
    
    # 判断目标节点是否为"坏"节点
    target_id = link["target"] if link["source"] in core_id_set else link["source"]
    tgt_node = node_by_id.get(target_id)
    if tgt_node is None:
        new_links.append(link)
        continue
    
    sf = tgt_node.get("source_file", "")
    label = tgt_node.get("label", "")
    
    is_bad = False
    reason = ""
    if "test" in sf.lower() or "tests" in sf.lower() or "integration_test" in sf.lower():
        is_bad = True
        reason = "test_file"
    elif "Handler" in label:
        is_bad = True
        reason = "Handler"
    elif "Fake" in label or "Mock" in label or "_Fake" in label:
        is_bad = True
        reason = "Fake/Mock"
    elif "alembic" in sf.lower():
        is_bad = True
        reason = "alembic"
    
    if is_bad:
        removed_edges += 1
        if removed_edges <= 30:
            src_node = node_by_id.get(link["source"], {})
            src_label = src_node.get("label", "?")
            rel = link.get("relation", "?")
            print(f"  [DEL] {src_label} -[{rel}]-> {label} ({reason}: {sf})")
        removed_details.append({
            "source": link["source"],
            "target": link["target"],
            "source_label": node_by_id.get(link["source"], {}).get("label", "?"),
            "target_label": label,
            "relation": link.get("relation", "?"),
            "reason": reason,
        })
    else:
        new_links.append(link)

g["links"] = new_links
print(f"\n共删除 {removed_edges} 条错误 INFERRED 边")
if removed_edges > 30:
    print(f"  (仅显示前 30 条详情)")

# =============================================================================
# Step 6: 统一核心社区
# =============================================================================
print("\n" + "=" * 60)
print("Step 6: 统一核心业务实体社区")
print("=" * 60)

# 获取 ProductionOrder 的社区（应该已经是 community=4）
core_community = CORE_COMMUNITY
if "ProductionOrder" in core_nodes:
    core_community = core_nodes["ProductionOrder"].get("community", CORE_COMMUNITY)
    print(f"ProductionOrder 当前社区: {core_community}")

community_changes = 0
for label, node in core_nodes.items():
    old_community = node.get("community")
    if old_community != core_community:
        node["community"] = core_community
        community_changes += 1
        print(f"  [MOV] {label}: community {old_community} -> {core_community}")

if community_changes == 0:
    print("  所有核心节点已在同一社区，无需更改")
else:
    print(f"  共 {community_changes} 个节点的社区被统一为 {core_community}")

# =============================================================================
# Step 7: 保存并输出统计
# =============================================================================
print("\n" + "=" * 60)
print("Step 7: 保存增强后的图谱并输出统计")
print("=" * 60)

with open(GRAPH_PATH, "w", encoding="utf-8") as f:
    json.dump(g, f, indent=2, ensure_ascii=False)

extracted = sum(1 for e in g["links"] if e.get("confidence") == "EXTRACTED")
inferred = sum(1 for e in g["links"] if e.get("confidence") == "INFERRED")
total = len(g["links"])

print(f"Added {added_nodes} nodes")
print(f"Added {added_edges} edges")
print(f"Removed {removed_edges} bad INFERRED edges")
print(f"Total nodes: {len(g['nodes'])}, Total edges: {len(g['links'])}")
print(f"EXTRACTED: {extracted}, INFERRED: {inferred}, INFERRED ratio: {inferred/total*100:.1f}%" if total > 0 else "No edges")

# 验证增强结果
print("\n" + "=" * 60)
print("Step 8: 验证增强结果")
print("=" * 60)

if "ProductionOrder" in core_nodes:
    po_id = core_nodes["ProductionOrder"]["id"]
    po_edges = [e for e in g["links"] if e["source"] == po_id or e["target"] == po_id]
    extracted_po = [e for e in po_edges if e.get("confidence") == "EXTRACTED"]
    print(f"ProductionOrder 总边数: {len(po_edges)}, EXTRACTED: {len(extracted_po)}")

# 检查关键边是否存在
key_checks = [
    ("ProductionOrder", "ProductionOrderProcess", "has_many"),
    ("ProductionOrder", "Product", "belongs_to"),
    ("User", "Role", "has_one"),
    ("Role", "PermissionCatalog", "has_many"),
    ("Equipment", "MaintenancePlan", "has_many"),
    ("Equipment", "MaintenanceWorkOrder", "has_many"),
]

print("\n关键边验证:")
for src_label, tgt_label, rel in key_checks:
    src_id = core_nodes[src_label]["id"] if src_label in core_nodes else None
    tgt_id = core_nodes[tgt_label]["id"] if tgt_label in core_nodes else None
    if src_id and tgt_id:
        found = any(
            e["source"] == src_id and e["target"] == tgt_id and e.get("relation") == rel
            for e in g["links"]
        )
        status = "OK" if found else "MISSING"
        print(f"  [{status}] {src_label} -[{rel}]-> {tgt_label}")
    else:
        print(f"  [SKIP] {src_label} -[{rel}]-> {tgt_label} (节点缺失)")

# 显示最终 EXTRACTED 边中涉及核心节点的数量
print(f"\n核心业务节点 ({len(core_nodes)} 个) 涉及的 EXTRACTED 边检查:")
core_extracted = sum(
    1 for e in g["links"]
    if e.get("confidence") == "EXTRACTED"
    and (e["source"] in core_id_set or e["target"] in core_id_set)
)
print(f"  核心节点参与的 EXTRACTED 边: {core_extracted}")

print("\n" + "=" * 60)
print("语义增强完成!")
print("=" * 60)

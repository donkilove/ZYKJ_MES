#!/usr/bin/env python3
"""Graphify 导航视图生成模块。

职责：基于治理后图谱生成三类导航视图：
1. entrypoints.md - 后端/前端/脚本/测试入口
2. contract-chains.md - 核心对象契约链路
3. impact-surfaces.md - 核心对象影响面分析
"""
import json
import re
from pathlib import Path
from collections import defaultdict


def _load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _find_nodes_by_label(graph, label_substr):
    """模糊搜索节点标签。"""
    results = []
    for n in graph.get("nodes", []):
        lbl = n.get("label", "") or ""
        if label_substr.lower() in lbl.lower():
            results.append(n)
    return results


def _find_nodes_by_file(graph, file_substr):
    """按源文件路径搜索节点。"""
    results = []
    for n in graph.get("nodes", []):
        sf = n.get("source_file", "") or ""
        if file_substr.lower() in sf.lower():
            results.append(n)
    return results


def _get_node_neighbors(graph, node_id, max_hops=2):
    """获取节点的邻居（按跳数）。"""
    neighbors = {1: [], 2: []}
    visited = {node_id}

    # 1-hop
    for l in graph.get("links", []):
        src = l.get("source")
        tgt = l.get("target")
        if src == node_id and tgt not in visited:
            neighbors[1].append({"id": tgt, "relation": l.get("relation", ""),
                                 "direction": "out"})
            visited.add(tgt)
        elif tgt == node_id and src not in visited:
            neighbors[1].append({"id": src, "relation": l.get("relation", ""),
                                 "direction": "in"})
            visited.add(src)

    # 2-hop
    hop1_ids = set(n["id"] for n in neighbors[1])
    for l in graph.get("links", []):
        src = l.get("source")
        tgt = l.get("target")
        if src in hop1_ids and tgt not in visited and tgt != node_id:
            neighbors[2].append({"id": tgt, "relation": l.get("relation", ""),
                                 "direction": "out", "via": src})
            visited.add(tgt)
        elif tgt in hop1_ids and src not in visited and src != node_id:
            neighbors[2].append({"id": src, "relation": l.get("relation", ""),
                                 "direction": "in", "via": tgt})
            visited.add(src)

    return neighbors


def _build_node_map(graph):
    return {n["id"]: n for n in graph.get("nodes", [])}


def _generate_entrypoints(graph, rules, node_map):
    """生成入口导航视图。"""
    ep_rules = rules["navigation_rules"]["entrypoints"]

    lines = []
    lines.append("# 入口导航")
    lines.append("")
    lines.append("> 自动生成，基于治理后图谱")
    lines.append("")

    # 后端入口
    lines.append("## 后端入口")
    lines.append("")
    for pat in ep_rules["backend"]:
        nodes = _find_nodes_by_file(graph, pat)
        for n in nodes[:5]:
            lbl = n.get("label", "?")
            sf = n.get("source_file", "")
            dom = n.get("domain_tag", "?")
            lines.append(f"- `{lbl}` — `{sf}` — 域:`{dom}`")
        if len(nodes) > 5:
            lines.append(f"- ... 共 {len(nodes)} 个节点")
    lines.append("")

    # 前端入口
    lines.append("## 前端入口")
    lines.append("")
    for pat in ep_rules["frontend"]:
        nodes = _find_nodes_by_file(graph, pat)
        for n in nodes[:5]:
            lbl = n.get("label", "?")
            sf = n.get("source_file", "")
            dom = n.get("domain_tag", "?")
            lines.append(f"- `{lbl}` — `{sf}` — 域:`{dom}`")
        if len(nodes) > 5:
            lines.append(f"- ... 共 {len(nodes)} 个节点")
    lines.append("")

    # 脚本入口
    lines.append("## 脚本入口")
    lines.append("")
    for pat in ep_rules["scripts"]:
        nodes = _find_nodes_by_file(graph, pat)
        for n in nodes[:5]:
            lbl = n.get("label", "?")
            sf = n.get("source_file", "")
            dom = n.get("domain_tag", "?")
            lines.append(f"- `{lbl}` — `{sf}` — 域:`{dom}`")
    lines.append("")

    # 测试入口
    lines.append("## 测试入口")
    lines.append("")
    for pat in ep_rules["tests"]:
        nodes = _find_nodes_by_file(graph, pat)
        for n in nodes[:10]:
            lbl = n.get("label", "?")
            sf = n.get("source_file", "")
            dom = n.get("domain_tag", "?")
            lines.append(f"- `{lbl}` — `{sf}` — 域:`{dom}`")
        if len(nodes) > 10:
            lines.append(f"- ... 共 {len(nodes)} 个节点")
    lines.append("")

    return "\n".join(lines)


def _generate_contract_chains(graph, rules, node_map):
    """生成契约链路视图。"""
    contract_objects = rules["navigation_rules"]["contract_objects"]

    lines = []
    lines.append("# 契约链路")
    lines.append("")
    lines.append("> 自动生成，基于治理后图谱")
    lines.append("> 每条链路追溯：数据模型 → 服务层 → API端点 → 前端页面 → 测试")
    lines.append("")

    for obj_name in contract_objects:
        nodes = _find_nodes_by_label(graph, obj_name)
        if not nodes:
            lines.append(f"## {obj_name}")
            lines.append(f"")
            lines.append(f"> 图谱中未找到 `{obj_name}` 节点，可能已被降噪滤除或不在当前扫描范围")
            lines.append("")
            continue

        # 取 models 目录下的节点作为主节点
        model_nodes = [n for n in nodes if "models" in (n.get("source_file", "") or "")]
        main_node = model_nodes[0] if model_nodes else nodes[0]

        lines.append(f"## {obj_name}")
        lines.append(f"")
        lines.append(f"- 主节点: `{main_node['id']}`")
        lines.append(f"- 源文件: `{main_node.get('source_file', '?')}`")
        lines.append(f"- 域: `{main_node.get('domain_tag', '?')}`")
        lines.append(f"")

        neighbors = _get_node_neighbors(graph, main_node["id"], max_hops=2)
        links_by_node = defaultdict(list)
        for l in graph.get("links", []):
            src = l.get("source")
            tgt = l.get("target")
            if src == main_node["id"]:
                links_by_node[tgt].append(l)
            elif tgt == main_node["id"]:
                links_by_node[src].append(l)

        lines.append(f"### 直接关联 ({len(links_by_node)} 条边)")
        lines.append(f"")

        # 分组显示：models, services, api, frontend
        groups = {"models": [], "services": [], "api": [], "frontend": [], "other": []}
        for target_id, edge_list in links_by_node.items():
            tgt = node_map.get(target_id, {})
            sf = tgt.get("source_file", "") or ""
            if "models" in sf:
                groups["models"].append((target_id, edge_list, tgt))
            elif "services" in sf:
                groups["services"].append((target_id, edge_list, tgt))
            elif "api" in sf or "endpoints" in sf:
                groups["api"].append((target_id, edge_list, tgt))
            elif "frontend" in sf:
                groups["frontend"].append((target_id, edge_list, tgt))
            else:
                groups["other"].append((target_id, edge_list, tgt))

        for gname, items in groups.items():
            if not items:
                continue
            lines.append(f"#### {gname}")
            lines.append(f"")
            for target_id, edge_list, tgt in items[:10]:
                lbl = tgt.get("label", "?")
                sf = tgt.get("source_file", "?")
                rels = ", ".join(set(e.get("relation", "?") for e in edge_list))
                lines.append(f"- `{lbl}` — `{sf}` — [{rels}]")
            lines.append("")

        lines.append("")

    return "\n".join(lines)


def _generate_impact_surfaces(graph, rules, node_map):
    """生成影响面视图。"""
    impact_objects = rules["navigation_rules"]["impact_objects"]

    lines = []
    lines.append("# 影响面分析")
    lines.append("")
    lines.append("> 自动生成，基于治理后图谱")
    lines.append("> 以核心对象为中心，列出上下游 1-2 跳的文件和模块")
    lines.append("")

    for obj_name in impact_objects:
        nodes = _find_nodes_by_label(graph, obj_name)
        if not nodes:
            lines.append(f"## {obj_name}")
            lines.append(f"")
            lines.append(f"> 图谱中未找到 `{obj_name}` 节点")
            lines.append("")
            continue

        model_nodes = [n for n in nodes if "models" in (n.get("source_file", "") or "")]
        # 对于 Equipment，尝试多种匹配
        if not model_nodes:
            model_nodes = [n for n in nodes if "models" in (n.get("source_file", "") or "")
                           or "services" in (n.get("source_file", "") or "")]
        main_nodes = model_nodes[:3] if model_nodes else nodes[:3]

        lines.append(f"## {obj_name}")
        lines.append(f"")

        for main_node in main_nodes:
            lines.append(f"### `{main_node.get('label', '?')}` — `{main_node.get('source_file', '?')}`")
            lines.append(f"")

            neighbors = _get_node_neighbors(graph, main_node["id"], max_hops=2)

            # 1-hop
            lines.append(f"#### 直接影响 (1-hop: {len(neighbors[1])} 个节点)")
            lines.append(f"")

            # 按文件分组
            hop1_files = defaultdict(list)
            for nb in neighbors[1]:
                tgt = node_map.get(nb["id"], {})
                sf = tgt.get("source_file", "?")
                hop1_files[sf].append(nb)

            for sf, nbs in sorted(hop1_files.items()):
                lbls = []
                for nb2 in nbs[:5]:
                    tgt2 = node_map.get(nb2["id"], {})
                    lbls.append(f"`{tgt2.get('label', '?')}`")
                ext = f" +{len(nbs)-5} more" if len(nbs) > 5 else ""
                lines.append(f"- `{sf}`: {', '.join(lbls)}{ext}")

            lines.append(f"")

            # 2-hop
            lines.append(f"#### 间接影响 (2-hop: {len(neighbors[2])} 个节点)")
            lines.append(f"")

            hop2_files = defaultdict(list)
            for nb in neighbors[2]:
                tgt = node_map.get(nb["id"], {})
                sf = tgt.get("source_file", "?")
                hop2_files[sf].append(nb)

            for sf, nbs in sorted(hop2_files.items())[:15]:
                lbls = []
                for nb2 in nbs[:3]:
                    tgt2 = node_map.get(nb2["id"], {})
                    lbls.append(f"`{tgt2.get('label', '?')}`")
                ext = f" +{len(nbs)-3} more" if len(nbs) > 3 else ""
                lines.append(f"- `{sf}`: {', '.join(lbls)}{ext}")

            if len(hop2_files) > 15:
                lines.append(f"- ... 共 {len(hop2_files)} 个文件")

            lines.append(f"")

        lines.append(f"---")
        lines.append(f"")

    return "\n".join(lines)


def generate_navigation(graph_path, rules_path, manifest, output_dir):
    """生成所有导航视图。

    返回 dict: {entrypoints: bool, contract_chains: bool, impact_surfaces: bool}
    """
    graph = _load_json(graph_path)
    rules = _load_json(rules_path)
    node_map = _build_node_map(graph)

    output_dir = Path(output_dir)

    # 入口导航
    print("  生成 entrypoints.md ...")
    entrypoints_content = _generate_entrypoints(graph, rules, node_map)
    (output_dir / "entrypoints.md").write_text(entrypoints_content, encoding="utf-8")

    # 契约链路
    print("  生成 contract-chains.md ...")
    contract_content = _generate_contract_chains(graph, rules, node_map)
    (output_dir / "contract-chains.md").write_text(contract_content, encoding="utf-8")

    # 影响面
    print("  生成 impact-surfaces.md ...")
    impact_content = _generate_impact_surfaces(graph, rules, node_map)
    (output_dir / "impact-surfaces.md").write_text(impact_content, encoding="utf-8")

    return {
        "entrypoints": True,
        "contract_chains": True,
        "impact_surfaces": True,
    }

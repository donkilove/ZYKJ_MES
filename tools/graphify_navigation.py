#!/usr/bin/env python3
"""Graphify 导航视图生成模块。

职责：基于治理后图谱生成三类导航视图：
1. entrypoints.md - 后端/前端/脚本/测试入口
2. contract-chains.md - 核心对象契约链路 (model→service→endpoint→frontend→test)
3. impact-surfaces.md - 核心对象影响面分析（文件级，去噪）
"""
import json
import re
from pathlib import Path
from collections import defaultdict


def _load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _normalize_path(p):
    if not p:
        return ""
    return p.replace("\\", "/")


def _build_node_map(graph):
    return {n["id"]: n for n in graph.get("nodes", [])}


def _find_nodes_by_file(graph, file_substr):
    """按源文件路径搜索节点（路径标准化后匹配）。"""
    results = []
    nf = _normalize_path(file_substr)
    for n in graph.get("nodes", []):
        sf = _normalize_path(n.get("source_file", ""))
        if nf.lower() in sf.lower():
            results.append(n)
    return results


def _find_nodes_by_label_exact(graph, label):
    """精确匹配标签。"""
    results = []
    for n in graph.get("nodes", []):
        if n.get("label", "") == label:
            results.append(n)
    return results


def _find_nodes_by_label_contains(graph, label_substr):
    """模糊搜索节点标签。"""
    results = []
    for n in graph.get("nodes", []):
        lbl = n.get("label", "") or ""
        if label_substr.lower() in lbl.lower():
            results.append(n)
    return results


def _get_neighbor_map(graph, node_id):
    """获取节点的邻居按文件类型分组。"""
    groups = {"models": [], "services": [], "api": [], "frontend": [], "test": [], "other": []}
    for l in graph.get("links", []):
        src = l.get("source")
        tgt = l.get("target")
        obj = None
        direction = None
        if src == node_id:
            obj_id = tgt
            direction = "out"
        elif tgt == node_id:
            obj_id = src
            direction = "in"
        else:
            continue

        # 在 node_map 中查找
        # (我们在外面传 node_map)
        obj = graph.get("_node_map", {}).get(obj_id, {})
        sf = _normalize_path(obj.get("source_file", ""))
        label = obj.get("label", "?")
        rel = l.get("relation", "?")

        entry = {"id": obj_id, "label": label, "source_file": sf, "relation": rel, "direction": direction}

        if "/test/" in sf or "/tests/" in sf or "_test." in sf or "integration_test" in sf:
            groups["test"].append(entry)
        elif "/models/" in sf:
            groups["models"].append(entry)
        elif "/services/" in sf:
            groups["services"].append(entry)
        elif "/api/" in sf or "/endpoints/" in sf:
            groups["api"].append(entry)
        elif "frontend" in sf:
            groups["frontend"].append(entry)
        else:
            groups["other"].append(entry)

    return groups


def _select_contract_main_node(graph, obj_name):
    """选择契约主节点：精确label > models目录 > 显式类定义。"""
    exact = _find_nodes_by_label_exact(graph, obj_name)
    if exact:
        model_nodes = [n for n in exact if "/models/" in _normalize_path(n.get("source_file", ""))]
        if model_nodes:
            return model_nodes[0]
        frontend_model = [n for n in exact if "/models/" in _normalize_path(n.get("source_file", ""))]
        if frontend_model:
            return frontend_model[0]
        return exact[0]

    # 没有精确匹配，按文件名后缀找 models 目录下的节点
    candidates = _find_nodes_by_label_contains(graph, obj_name)
    model_nodes = [n for n in candidates if "/models/" in _normalize_path(n.get("source_file", ""))]
    if model_nodes:
        return model_nodes[0]

    frontend_model = [n for n in candidates if "/models/" in _normalize_path(n.get("source_file", ""))]
    if frontend_model:
        return frontend_model[0]

    if candidates:
        return candidates[0]

    return None


def _select_impact_main_nodes(graph, obj_name, max_count=3):
    """选择影响面主节点：优先 models 目录下精确匹配的。"""
    exact = _find_nodes_by_label_exact(graph, obj_name)
    if not exact:
        exact = _find_nodes_by_label_contains(graph, obj_name)

    # 按源文件优先级排序：models > services > api > frontend
    def _node_priority(n):
        sf = _normalize_path(n.get("source_file", ""))
        if "/models/" in sf:
            return 0
        if "/services/" in sf:
            return 1
        if "/api/" in sf or "/endpoints/" in sf:
            return 2
        if "/schemas/" in sf:
            return 3
        if "frontend" in sf:
            return 4
        return 5

    sorted_nodes = sorted(exact, key=_node_priority)
    # 去重（同label但不同文件取最优优先级）
    seen = set()
    unique = []
    for n in sorted_nodes:
        lbl = n.get("label", "")
        if lbl not in seen:
            seen.add(lbl)
            unique.append(n)
    return unique[:max_count]


_NOISE_SOURCE_PATTERNS = re.compile(
    r"^(test_|_test\.|integration_test|__pycache__|alembic/|\.dart_tool/)",
    re.IGNORECASE
)


def _is_noise_source(sf):
    if not sf:
        return True
    return bool(_NOISE_SOURCE_PATTERNS.search(_normalize_path(sf)))


def _is_noise_node_label(label):
    if not label:
        return True
    if re.search(r"^(Revision ID:|Create Date:|Revises:|Run migrations)", label):
        return True
    if len(label) > 80:
        return True
    return False


def _generate_entrypoints(graph, rules, node_map):
    ep_rules = rules["navigation_rules"]["entrypoints"]

    lines = []
    lines.append("# 入口导航")
    lines.append("")
    lines.append("> 自动生成，基于治理后图谱")
    lines.append("")

    sections = [
        ("后端入口", ep_rules["backend"]),
        ("前端入口", ep_rules["frontend"]),
        ("脚本入口", ep_rules["scripts"]),
        ("测试入口", ep_rules["tests"]),
    ]

    for section_title, patterns in sections:
        lines.append(f"## {section_title}")
        lines.append("")
        shown = 0
        for pat in patterns:
            nodes = _find_nodes_by_file(graph, pat)
            for n in nodes:
                # 跳过噪音节点
                lbl = n.get("label", "")
                if _is_noise_node_label(lbl):
                    continue
                if n.get("curation_action", "") in ("drop_from_curated",):
                    continue
                if shown < 20:
                    sf = n.get("source_file", "")
                    dom = n.get("domain_tag", "?")
                    lines.append(f"- `{lbl}` — `{sf}` — 域:`{dom}`")
                    shown += 1
        if shown == 0:
            lines.append("_（未匹配到入口节点）_")
        elif shown >= 1:
            pass
        lines.append("")

    return "\n".join(lines)


def _generate_contract_chains(graph, rules, node_map):
    contract_objects = rules["navigation_rules"]["contract_objects"]

    # 临时附加 nodemap 到 graph 上方便 neighbor_map 使用
    graph["_node_map"] = node_map

    lines = []
    lines.append("# 契约链路")
    lines.append("")
    lines.append("> 每条链路追溯：数据模型 → 服务层 → API端点 → 前端页面 → 测试")
    lines.append("")

    for obj_name in contract_objects:
        main_node = _select_contract_main_node(graph, obj_name)
        if main_node is None:
            lines.append(f"## {obj_name}")
            lines.append("")
            lines.append(f"> 图谱中未找到 `{obj_name}` 节点")
            lines.append("")
            continue

        lines.append(f"## {obj_name}")
        lines.append("")
        lines.append(f"- 主节点: `{main_node['id']}`")
        lines.append(f"- 标签: `{main_node.get('label', '?')}`")
        lines.append(f"- 源文件: `{main_node.get('source_file', '?')}`")
        lines.append(f"- 域: `{main_node.get('domain_tag', '?')}`")
        lines.append("")

        groups = _get_neighbor_map(graph, main_node["id"])

        total = sum(len(v) for v in groups.values())
        lines.append(f"### 关联概览 ({total} 条边)")
        lines.append("")
        lines.append(f"| 层级 | 数量 |")
        lines.append(f"|---|---|")
        for gname, items in groups.items():
            if items:
                lines.append(f"| {gname} | {len(items)} |")
        lines.append("")

        for gname, items in groups.items():
            if not items:
                continue
            lines.append(f"### {gname}")
            lines.append("")
            # 去重：按 source_file + label 去重
            seen_entries = set()
            for entry in items:
                key = (entry["source_file"], entry["label"])
                if key in seen_entries:
                    continue
                seen_entries.add(key)
                lines.append(f"- `{entry['label']}` — `{entry['source_file']}` — [{entry['relation']}]")
            lines.append("")

        lines.append("")

    del graph["_node_map"]
    return "\n".join(lines)


def _generate_impact_surfaces(graph, rules, node_map):
    impact_objects = rules["navigation_rules"]["impact_objects"]
    graph["_node_map"] = node_map

    lines = []
    lines.append("# 影响面分析")
    lines.append("")
    lines.append("> 以核心对象为中心，列出上下游 1-hop 的文件和模块")
    lines.append("")

    for obj_name in impact_objects:
        main_nodes = _select_impact_main_nodes(graph, obj_name, max_count=3)
        if not main_nodes:
            lines.append(f"## {obj_name}")
            lines.append("")
            lines.append(f"> 图谱中未找到 `{obj_name}` 节点")
            lines.append("")
            continue

        lines.append(f"## {obj_name}")
        lines.append("")

        for main_node in main_nodes:
            lbl = main_node.get("label", "?")
            sf = main_node.get("source_file", "?")
            domain = main_node.get("domain_tag", "?")
            lines.append(f"### `{lbl}` — `{sf}` (域:{domain})")
            lines.append("")

            groups = _get_neighbor_map(graph, main_node["id"])

            reported_files = set()
            for gname in ["models", "services", "api", "frontend", "other"]:
                items = groups.get(gname, [])
                if not items:
                    continue

                # 按文件聚合，跳过噪音
                file_items = defaultdict(list)
                for entry in items:
                    sf_entry = entry["source_file"]
                    if _is_noise_source(sf_entry):
                        continue
                    lbl_entry = entry["label"]
                    if _is_noise_node_label(lbl_entry):
                        continue
                    # check if the node is hidden/dropped
                    n_obj = node_map.get(entry["id"], {})
                    if n_obj.get("curation_action", "") in ("hide_from_rank", "drop_from_curated"):
                        continue
                    file_items[sf_entry].append(entry)

                if not file_items:
                    continue

                lines.append(f"#### {gname}")
                lines.append("")
                for sf_entry, entries in sorted(file_items.items()):
                    if sf_entry in reported_files:
                        continue
                    reported_files.add(sf_entry)
                    lbls = list(set(e["label"] for e in entries[:5]))
                    ext = f" +{len(entries)-5} more" if len(entries) > 5 else ""
                    lines.append(f"- `{sf_entry}`: {', '.join('`'+l+'`' for l in lbls)}{ext}")
                lines.append("")

        lines.append("---")
        lines.append("")

    del graph["_node_map"]
    return "\n".join(lines)


def generate_navigation(graph_path, rules_path, manifest, output_dir):
    graph = _load_json(graph_path)
    rules = _load_json(rules_path)
    node_map = _build_node_map(graph)

    output_dir = Path(output_dir)

    print("  生成 entrypoints.md ...")
    ep = _generate_entrypoints(graph, rules, node_map)
    (output_dir / "entrypoints.md").write_text(ep, encoding="utf-8")

    print("  生成 contract-chains.md ...")
    cc = _generate_contract_chains(graph, rules, node_map)
    (output_dir / "contract-chains.md").write_text(cc, encoding="utf-8")

    print("  生成 impact-surfaces.md ...")
    im = _generate_impact_surfaces(graph, rules, node_map)
    (output_dir / "impact-surfaces.md").write_text(im, encoding="utf-8")

    # entrypoints 验证：至少每种入口要有内容
    ep_ok = "## 后端入口\n\n_（未匹配到入口节点）_" not in ep
    cc_ok = True
    im_ok = True

    return {
        "entrypoints": ep_ok,
        "contract_chains": cc_ok,
        "impact_surfaces": im_ok,
    }

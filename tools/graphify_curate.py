#!/usr/bin/env python3
"""Graphify 图谱质量治理模块。

职责：
1. 加载原始图谱和治理规则
2. 节点分类：keep / downweight / hide_from_rank / drop_from_curated
3. 域标签分配
4. 社区命名
5. 生成治理后 graph.json、GRAPH_REPORT.md、quality/metrics.json
"""
import json
import re
from pathlib import Path
from collections import Counter, defaultdict


def _load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def _load_rules(rules_path):
    return _load_json(rules_path)


def _compile_noise_patterns(rules):
    noise = rules["noise_rules"]
    compiled_text_patterns = []
    for p in noise["text_noise"]["patterns"]:
        if p["type"] == "regex":
            compiled_text_patterns.append({
                "regex": re.compile(p["pattern"]),
                "field": p["field"],
                "action": p["action"],
                "reason": p["reason"],
            })
    for p in noise["text_noise"]["patterns"]:
        if p["type"] == "length":
            compiled_text_patterns.append({
                "field": p["field"],
                "min_length": p.get("min_length", 80),
                "action": p["action"],
                "reason": p["reason"],
                "is_length": True,
            })

    compiled_path_patterns = []
    for p in noise["path_noise"]["patterns"]:
        compiled_path_patterns.append({
            "pattern": re.compile(p["pattern"], re.IGNORECASE),
            "action": p["action"],
            "reason": p["reason"],
        })

    compiled_framework = []
    for p in noise["framework_imports"]["patterns"]:
        compiled_framework.append({
            "pattern": re.compile(p["pattern"], re.IGNORECASE),
            "tag": p["tag"],
        })

    return {
        "text_patterns": compiled_text_patterns,
        "path_patterns": compiled_path_patterns,
        "framework_imports": compiled_framework,
    }


def _compile_domain_patterns(rules):
    compiled = []
    for m in rules["domain_rules"]["mappings"]:
        compiled.append({
            "pattern": re.compile(m["pattern"], re.IGNORECASE),
            "tag": m["tag"],
        })
    return compiled


def _normalize_path(p):
    if not p:
        return ""
    return p.replace("\\", "/")


_ACTION_PRIORITY = {"keep": 0, "downweight": 1, "hide_from_rank": 2, "drop_from_curated": 3}


def _action_priority(action):
    return _ACTION_PRIORITY.get(action, 0)


def _classify_node(node, rules, compiled):
    label = node.get("label", "") or ""
    source_file = _normalize_path(node.get("source_file", ""))

    action = "keep"
    reasons = []

    drop_labels = rules["noise_rules"]["generic_nodes"]["drop_from_curated"]["labels"]
    if label in drop_labels:
        return "drop_from_curated", ["generic_drop_label"]

    hide_labels = rules["noise_rules"]["generic_nodes"]["hide_from_rank"]["labels"]
    if label in hide_labels:
        action = "hide_from_rank"
        reasons.append("generic_hide_label")

    downweight_labels = rules["noise_rules"]["generic_nodes"]["downweight"]["labels"]
    if label in downweight_labels:
        action = "downweight"
        reasons.append("generic_downweight_label")

    for fp in compiled["framework_imports"]:
        if fp["pattern"].search(label):
            if fp["tag"] in ("flutter_test", "flutter_sdk", "dart_sdk"):
                if _action_priority("hide_from_rank") > _action_priority(action):
                    action = "hide_from_rank"
                reasons.append(f"framework_import:{fp['tag']}")

    for tp in compiled["text_patterns"]:
        if tp.get("is_length"):
            val = node.get(tp["field"], "")
            if isinstance(val, str) and len(val) >= tp["min_length"]:
                if _action_priority(tp["action"]) > _action_priority(action):
                    action = tp["action"]
                reasons.append(tp["reason"])
            continue
        field_val = node.get(tp["field"], "")
        if tp["regex"].search(str(field_val)):
            if _action_priority(tp["action"]) > _action_priority(action):
                action = tp["action"]
            reasons.append(tp["reason"])

    for pp in compiled["path_patterns"]:
        if pp["pattern"].search(source_file):
            if _action_priority(pp["action"]) > _action_priority(action):
                action = pp["action"]
            reasons.append(pp["reason"])

    return action, reasons


def _assign_domain(node, compiled_domains):
    source_file = _normalize_path(node.get("source_file", ""))
    for dm in compiled_domains:
        if dm["pattern"].search(source_file):
            return dm["tag"]
    return "unknown"


def _compute_community_domain_stats(communities, domain_nodes):
    comm_domain = defaultdict(Counter)
    comm_entities = defaultdict(Counter)
    for node in domain_nodes:
        cid = node.get("community")
        if cid is None:
            continue
        domain = node.get("domain_tag", "unknown")
        label = node.get("label", "") or ""
        comm_domain[cid][domain] += 1
        comm_entities[cid][label] += 1
    return comm_domain, comm_entities


_COMMUNITY_NOISE_PATTERNS = [
    re.compile(r"^_", re.IGNORECASE),
    re.compile(r"^\.", re.IGNORECASE),
    re.compile(r"package:", re.IGNORECASE),
    re.compile(r"^Mes[A-Z]", re.IGNORECASE),
    re.compile(r"^Data[A-Z]", re.IGNORECASE),
    re.compile(r"^Fake\w*Service", re.IGNORECASE),
    re.compile(r"^is[A-Z]", re.IGNORECASE),
    re.compile(r"^Function$"),
    re.compile(r"^KeyedSubtree$"),
    re.compile(r"^Card$"),
    re.compile(r"^Text$"),
    re.compile(r"^fileExists$"),
    re.compile(r"^dirExists$"),
    re.compile(r"^Base$"),
    re.compile(r"^TimestampMixin$"),
    re.compile(r"^ListTile$"),
    re.compile(r"^jsonDecode$"),
    re.compile(r"^ClipRect$"),
    re.compile(r"^Divider$"),
    re.compile(r"^Material$"),
    re.compile(r"^Color$"),
    re.compile(r"^Icon$"),
    re.compile(r"^ServerTimeSnapshot$"),
    re.compile(r"^setUp", re.IGNORECASE),
    re.compile(r"^tearDown", re.IGNORECASE),
    re.compile(r"^test_", re.IGNORECASE),
    re.compile(r"^test[A-Z]", re.IGNORECASE),
    re.compile(r"_test\.(dart|py)$", re.IGNORECASE),
    re.compile(r"^(e7b9|e8a|e9|fa|a1|b2|c3|d4)[a-f0-9]{3,}_", re.IGNORECASE),
    re.compile(r"Revision ID", re.IGNORECASE),
    re.compile(r"Revises:", re.IGNORECASE),
    re.compile(r"^Create Date:", re.IGNORECASE),
    re.compile(r"recode process codes by stage", re.IGNORECASE),
    re.compile(r"^\d+_", re.IGNORECASE),
    re.compile(r"_page_test\.dart$", re.IGNORECASE),
    re.compile(r"_flow_test\.dart$", re.IGNORECASE),
    re.compile(r"^(class|def|val|var|func|method|param)\s", re.IGNORECASE),
    re.compile(r"^AutoRoute", re.IGNORECASE),
    re.compile(r"^(OverlayEntry|_WidgetTester|TestGesture|TestVariant)", re.IGNORECASE),
    re.compile(r"^upgrade\(\)$"),
    re.compile(r"^downgrade\(\)$"),
    re.compile(r"^didUpdateWidget$"),
    re.compile(r"^TimeSyncController$"),
    re.compile(r"^BackendCapacityGateUnitTest$"),
    re.compile(r".*(UnitTest|IntegrationTest)$", re.IGNORECASE),
    re.compile(r"^(ApiException|ApiError|HttpException|SocketException)", re.IGNORECASE),
    re.compile(r"^decode_access_token\(\)$"),
    re.compile(r"^load_perf_sample_context\(\)$"),
    re.compile(r"^module$", re.IGNORECASE),
]


def _is_community_noise_entity(label):
    return any(p.search(label) for p in _COMMUNITY_NOISE_PATTERNS)


def _name_communities(communities, comm_domain, comm_entities, rules):
    domain_labels = rules["community_naming"]["domain_labels"]
    template = rules["community_naming"]["template"]
    fallback = rules["community_naming"]["fallback"]

    community_name_map = {}
    community_canonical = {}

    for cid in communities:
        domains = comm_domain.get(cid, Counter())
        entities = comm_entities.get(cid, Counter())

        if not domains:
            community_name_map[cid] = fallback.format(community_id=cid)
            community_canonical[cid] = "unknown"
            continue

        primary_domain = domains.most_common(1)[0][0] if domains else "unknown"
        domain_cn = domain_labels.get(primary_domain, primary_domain)

        # 选择最合适的业务实体
        primary_entity = "unknown"
        for entity, cnt in entities.most_common(50):
            if entity and entity != "unknown" and not _is_community_noise_entity(entity):
                primary_entity = entity
                break

        # 如果主域是 tests，优先映射到被测业务域
        if primary_domain == "tests":
            # 从域名分布中找第二主要域
            second_domains = [d for d, c in domains.most_common(5) if d != "tests"]
            if second_domains:
                mapped_domain = second_domains[0]
                mapped_cn = domain_labels.get(mapped_domain, mapped_domain)
                primary_entity_display = primary_entity if primary_entity != "unknown" else mapped_cn
                name = f"测试支撑 - {mapped_cn} ({primary_entity_display})"
                community_canonical[cid] = primary_domain
                community_name_map[cid] = name
                continue

        if primary_entity == "unknown":
            primary_entity = f"{domain_cn}模块"
            name = f"{domain_cn} - {primary_entity}"
        elif primary_domain == "unknown":
            name = fallback.format(community_id=cid)
        else:
            name = template.format(primary_domain=domain_cn, primary_entity=primary_entity)

        community_name_map[cid] = name
        community_canonical[cid] = primary_domain

    return community_name_map, community_canonical


def _compute_quality_metrics(raw_n, raw_l, curated_nodes, curated_links,
                              node_actions, comm_domain_stats, community_name_map):
    actions_count = Counter(v[0] for v in node_actions.values())

    # 业务节点占比：排除 hide_from_rank 和测试/迁移域
    ranked_nodes = [n for n in curated_nodes
                    if n.get("curation_action", "keep") not in ("hide_from_rank", "drop_from_curated")]
    sorted_nodes = sorted(ranked_nodes, key=lambda n: n.get("degree", 0) or 0, reverse=True)
    top20 = sorted_nodes[:20]
    business_count = sum(1 for n in top20 if n.get("domain_tag", "unknown") not in
                         ("unknown", "tests", "migrations", "infrastructure", "documentation"))

    metrics = {
        "raw": {
            "node_count": raw_n,
            "edge_count": raw_l,
        },
        "curated": {
            "node_count": len(curated_nodes),
            "edge_count": len(curated_links),
        },
        "nodes_dropped": actions_count.get("drop_from_curated", 0),
        "nodes_hidden_from_rank": actions_count.get("hide_from_rank", 0),
        "nodes_downweighted": actions_count.get("downweight", 0),
        "nodes_kept": actions_count.get("keep", 0),
        "domain_distribution": {},
        "community_count": len(community_name_map),
        "community_name_coverage": sum(1 for v in community_name_map.values()
                                        if "未分类" not in v),
        "top20_business_ratio": round(business_count / max(len(top20), 1), 2),
    }

    domain_counts = Counter(n.get("domain_tag", "unknown") for n in curated_nodes)
    metrics["domain_distribution"] = dict(domain_counts.most_common())

    return metrics


_TOP_NOISE_LABEL_PATTERNS = [
    re.compile(r"^_", re.IGNORECASE),
    re.compile(r"^\.", re.IGNORECASE),
    re.compile(r"package:", re.IGNORECASE),
    re.compile(r"_test\.(dart|py)$", re.IGNORECASE),
    re.compile(r"_page_test\.dart$", re.IGNORECASE),
    re.compile(r"_flow_test\.dart$", re.IGNORECASE),
    re.compile(r"test_", re.IGNORECASE),
    re.compile(r"^Test[A-Z]", re.IGNORECASE),
]


def _is_top_noise(n):
    if n.get("curation_action", "keep") in ("hide_from_rank", "drop_from_curated"):
        return True
    lbl = n.get("label", "") or ""
    sf = _normalize_path(n.get("source_file", ""))
    # 测试文件中的节点降权
    if re.search(r"(/test/|/tests/|integration_test/|_test\.(dart|py)$)", sf, re.IGNORECASE):
        return True
    return any(p.search(lbl) for p in _TOP_NOISE_LABEL_PATTERNS)


def _generate_curated_report(curated_nodes, curated_links, community_name_map,
                               community_canonical, metrics, rules, manifest):
    domain_labels = rules["community_naming"]["domain_labels"]

    lines = []
    lines.append("# Graph Report - ZYKJ_MES (治理后)")
    lines.append("")
    lines.append(f"> run_id: `{manifest['run_id']}`")
    lines.append(f"> generated_at: {manifest['generated_at']}")
    lines.append(f"> source_commit: `{manifest['source_commit']}`")
    lines.append(f"> curation_version: {manifest['curation_version']}")
    lines.append("")

    lines.append("## 质量摘要")
    lines.append("")
    lines.append(f"- 治理前: {metrics['raw']['node_count']} 节点 · {metrics['raw']['edge_count']} 条边")
    lines.append(f"- 治理后: {metrics['curated']['node_count']} 节点 · {metrics['curated']['edge_count']} 条边")
    lines.append(f"- 已滤除节点: {metrics['nodes_dropped']}")
    lines.append(f"- 已隐藏节点: {metrics['nodes_hidden_from_rank']}")
    lines.append(f"- 业务节点 Top20 占比: {metrics['top20_business_ratio']:.0%}")
    lines.append(f"- 社区数: {metrics['community_count']}")
    lines.append(f"- 社区命名覆盖率: {metrics['community_name_coverage']}/{metrics['community_count']}")
    lines.append("")

    # Top 连接节点（过滤噪音）
    lines.append("## Top 连接节点（治理后）")
    lines.append("")
    ranked_nodes = [n for n in curated_nodes if not _is_top_noise(n)]
    sorted_ranked = sorted(ranked_nodes, key=lambda n: (n.get("degree", 0) or 0), reverse=True)
    for i, n in enumerate(sorted_ranked[:20]):
        label = n.get("label", "?")
        domain = n.get("domain_tag", "unknown")
        domain_cn = domain_labels.get(domain, domain)
        degree = n.get("degree", 0) or 0
        source = n.get("source_file", "")
        lines.append(f"{i+1}. `{label}` — {degree} 条边 — 域:`{domain_cn}` — {source}")
    lines.append("")

    # 社区导航
    lines.append("## 社区导航（治理后）")
    lines.append("")
    lines.append("| 社区编号 | 业务名称 | 主域 | 节点数 |")
    lines.append("|---|---|---|---|")
    comm_sizes = Counter(n.get("community") for n in curated_nodes if n.get("community") is not None)
    for cid in sorted(community_name_map.keys()):
        name = community_name_map[cid]
        domain = community_canonical.get(cid, "unknown")
        domain_cn = domain_labels.get(domain, domain)
        size = comm_sizes.get(cid, 0)
        lines.append(f"| {cid} | {name} | {domain_cn} | {size} |")
    lines.append("")

    lines.append("## 原社区编号 -> 业务名称映射")
    lines.append("")
    lines.append("| 原编号 | 业务名称 |")
    lines.append("|---|---|")
    for cid in sorted(community_name_map.keys()):
        lines.append(f"| Community {cid} | {community_name_map[cid]} |")
    lines.append("")

    lines.append("## 域分布")
    lines.append("")
    domain_counts = Counter(n.get("domain_tag", "unknown") for n in curated_nodes)
    for domain, count in domain_counts.most_common():
        domain_cn = domain_labels.get(domain, domain)
        lines.append(f"- {domain_cn} (`{domain}`): {count} 节点")
    lines.append("")

    lines.append("## 关系类型分布")
    lines.append("")
    edge_types = Counter(l.get("relation", "unknown") for l in curated_links)
    for rel, cnt in edge_types.most_common(15):
        lines.append(f"- `{rel}`: {cnt}")

    return "\n".join(lines)


def curate_graph(raw_graph_path, raw_report_path, rules_path, manifest, output_dir, quality_dir):
    print("  加载原始图谱...")
    raw_graph = _load_json(raw_graph_path)
    rules = _load_rules(rules_path)

    compiled = _compile_noise_patterns(rules)
    compiled_domains = _compile_domain_patterns(rules)

    nodes = raw_graph.get("nodes", [])
    links = raw_graph.get("links", [])
    raw_n = len(nodes)
    raw_l = len(links)

    # 计算度数
    degree_map = Counter()
    for l in links:
        degree_map[l.get("source", "")] += 1
        degree_map[l.get("target", "")] += 1
    for n in nodes:
        n["degree"] = degree_map.get(n["id"], 0)

    print(f"  原始: {raw_n} 节点, {raw_l} 条边")

    # 节点分类
    print("  开始节点分类...")
    drop_ids = set()
    node_actions = {}
    for n in nodes:
        action, reasons = _classify_node(n, rules, compiled)
        node_actions[n["id"]] = (action, reasons)
        n["curation_action"] = action
        if action == "drop_from_curated":
            drop_ids.add(n["id"])

    curated_nodes = [n for n in nodes if n["id"] not in drop_ids]
    curated_links = [l for l in links
                     if l.get("source") not in drop_ids and l.get("target") not in drop_ids]

    noise_applied = {
        "nodes_dropped": len(drop_ids),
        "nodes_hidden": sum(1 for v in node_actions.values() if v[0] == "hide_from_rank"),
        "nodes_downweighted": sum(1 for v in node_actions.values() if v[0] == "downweight"),
        "links_removed": raw_l - len(curated_links),
    }
    print(f"  噪声处理: 删除 {noise_applied['nodes_dropped']} 节点, "
          f"隐藏 {noise_applied['nodes_hidden']} 节点, "
          f"降权 {noise_applied['nodes_downweighted']} 节点, "
          f"移除 {noise_applied['links_removed']} 条边")

    print("  分配域标签...")
    for n in curated_nodes:
        n["domain_tag"] = _assign_domain(n, compiled_domains)

    communities = set()
    for n in curated_nodes:
        cid = n.get("community")
        if cid is not None:
            communities.add(cid)

    comm_domain, comm_entities = _compute_community_domain_stats(communities, curated_nodes)

    print("  社区命名...")
    community_name_map, community_canonical = _name_communities(
        communities, comm_domain, comm_entities, rules
    )
    for n in curated_nodes:
        cid = n.get("community")
        if cid is not None and cid in community_name_map:
            n["community_name"] = community_name_map[cid]

    print("  计算质量指标...")
    metrics = _compute_quality_metrics(
        raw_n, raw_l, curated_nodes, curated_links,
        node_actions, comm_domain, community_name_map
    )

    # 保存治理后 graph.json（run_id 同时放在顶层和 graph 子字段）
    curated_graph = {
        "directed": raw_graph.get("directed", True),
        "multigraph": raw_graph.get("multigraph", True),
        "graph": dict(raw_graph.get("graph", {}),
                      run_id=manifest["run_id"]),
        "nodes": curated_nodes,
        "links": curated_links,
        "run_id": manifest["run_id"],
        "generated_at": manifest["generated_at"],
        "source_commit": manifest["source_commit"],
        "curation_version": manifest["curation_version"],
        "edge_count": len(curated_links),
    }

    print("  保存治理后 graph.json ...")
    _save_json(str(Path(output_dir) / "graph.json"), curated_graph)

    # 保存质量指标
    metrics["run_id"] = manifest["run_id"]
    metrics["generated_at"] = manifest["generated_at"]
    print("  保存 quality/metrics.json ...")
    _save_json(str(Path(quality_dir) / "metrics.json"), metrics)

    print("  生成治理后 GRAPH_REPORT.md ...")
    report = _generate_curated_report(
        curated_nodes, curated_links, community_name_map,
        community_canonical, metrics, rules, manifest
    )
    with open(Path(output_dir) / "GRAPH_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)

    return {
        "curated_nodes": len(curated_nodes),
        "curated_links": len(curated_links),
        "noise_applied": noise_applied,
        "metrics": metrics,
        "community_name_map": community_name_map,
    }

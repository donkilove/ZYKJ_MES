#!/usr/bin/env python3
"""Graphify 图谱质量治理流水线入口。

职责：
1. 复制原始 Graphify 产物到 raw/
2. 生成 run_id、manifest.json
3. 调用 curate 做降噪和语义治理
4. 调用 navigation 生成导航视图
5. 原子替换正式产物

使用方式：
  python tools/graphify_pipeline.py
"""
import json
import os
import sys
import hashlib
import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GRAPHIFY_OUT = REPO_ROOT / "graphify-out"
RAW_DIR = GRAPHIFY_OUT / "raw"
QUALITY_DIR = GRAPHIFY_OUT / "quality"
NAV_DIR = GRAPHIFY_OUT / "navigation"
RULES_PATH = REPO_ROOT / "tools" / "graphify_rules.json"

CURATION_VERSION = "1.0.0"
PIPELINE_VERSION = "1.0.0"


def _ensure_dirs():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    QUALITY_DIR.mkdir(parents=True, exist_ok=True)
    NAV_DIR.mkdir(parents=True, exist_ok=True)


def _get_source_commit():
    import subprocess
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, cwd=str(REPO_ROOT), timeout=10
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return "unknown"


def _compute_corpus_hash():
    ignore_path = REPO_ROOT / ".graphifyignore"
    ignore_hash = _hash_file(ignore_path) if ignore_path.exists() else "no-ignore"

    files_meta = []
    for root, dirs, files in os.walk(str(REPO_ROOT)):
        rel = os.path.relpath(root, str(REPO_ROOT))
        rel = rel.replace("\\", "/")
        if any(rel.startswith(d) for d in [".git", ".graphify-venv", "__pycache__",
                                             "node_modules", ".dart_tool",
                                             "graphify-out", ".claude", ".tmp_runtime"]):
            continue
        for f in sorted(files):
            fp = os.path.join(root, f)
            try:
                st = os.stat(fp)
                files_meta.append(f"{rel}/{f}:{st.st_size}:{st.st_mtime}")
            except OSError:
                pass

    meta_str = "\n".join(sorted(files_meta))
    return hashlib.sha256(meta_str.encode("utf-8")).hexdigest()[:16], ignore_hash


def _hash_file(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()[:16]


def _get_graphify_version():
    import subprocess
    try:
        result = subprocess.run(
            [sys.executable, "-m", "graphify", "--version"],
            capture_output=True, text=True, timeout=10
        )
        out = result.stdout.strip() or result.stderr.strip()
        if out:
            return out
    except Exception:
        pass
    try:
        import graphify
        return getattr(graphify, "__version__", "unknown")
    except ImportError:
        return "unknown"


def step_copy_raw():
    """将 Graphify 原始产物复制到 raw/，作为原始事实底座。
    仅在 raw/ 不存在时执行首次复制，避免后续重跑覆盖原始数据。
    """
    raw_graph = RAW_DIR / "graph.raw.json"
    raw_report = RAW_DIR / "GRAPH_REPORT.raw.md"
    if raw_graph.exists() and raw_report.exists():
        print("[P0] raw/ 已有原始产物，跳过复制（保护原始数据）")
        return True

    print("[P0] 复制原始产物到 raw/ ...")
    for src_name in ["graph.json", "GRAPH_REPORT.md"]:
        src = GRAPHIFY_OUT / src_name
        if src.exists():
            dst = RAW_DIR / src_name.replace(".json", ".raw.json").replace(".md", ".raw.md")
            shutil.copy2(src, dst)
            print(f"  {src_name} -> {dst.name}")
        else:
            print(f"  [WARN] {src_name} 不存在，跳过")
    return True


def step_generate_manifest():
    """生成 manifest.json，包含 run_id 等元数据。"""
    print("[P0] 生成 manifest.json ...")
    corpus_hash, ignore_hash = _compute_corpus_hash()

    manifest = {
        "run_id": str(uuid.uuid4()),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_commit": _get_source_commit(),
        "corpus_hash": corpus_hash,
        "ignore_hash": ignore_hash,
        "graphify_version": _get_graphify_version(),
        "curation_version": CURATION_VERSION,
        "pipeline_version": PIPELINE_VERSION,
        "repo_root": str(REPO_ROOT),
    }

    with open(GRAPHIFY_OUT / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"  run_id: {manifest['run_id']}")
    return manifest


def step_curate(manifest):
    """调用治理模块，产出 curated graph.json 和 GRAPH_REPORT.md。"""
    print("[P1/P2] 执行图谱治理 ...")
    try:
        from graphify_curate import curate_graph
        raw_graph_path = RAW_DIR / "graph.raw.json"
        raw_report_path = RAW_DIR / "GRAPH_REPORT.raw.md"

        if not raw_graph_path.exists():
            print("  [ERROR] raw/graph.raw.json 不存在，无法治理")
            return False

        result = curate_graph(
            raw_graph_path=str(raw_graph_path),
            raw_report_path=str(raw_report_path),
            rules_path=str(RULES_PATH),
            manifest=manifest,
            output_dir=str(GRAPHIFY_OUT),
            quality_dir=str(QUALITY_DIR),
        )
        print(f"  curated nodes: {result['curated_nodes']}, links: {result['curated_links']}")
        print(f"  noise applied: {result['noise_applied']}")
        return result
    except Exception as e:
        print(f"  [ERROR] 治理失败: {e}")
        import traceback
        traceback.print_exc()
        return None


def step_navigation(manifest):
    """生成导航视图。"""
    print("[P3] 生成导航视图 ...")
    try:
        from graphify_navigation import generate_navigation

        curated_graph_path = GRAPHIFY_OUT / "graph.json"
        if not curated_graph_path.exists():
            print("  [ERROR] 治理后 graph.json 不存在，无法生成导航视图")
            return False

        result = generate_navigation(
            graph_path=str(curated_graph_path),
            rules_path=str(RULES_PATH),
            manifest=manifest,
            output_dir=str(NAV_DIR),
        )
        print(f"  entrypoints: {'OK' if result.get('entrypoints') else 'FAIL'}")
        print(f"  contract_chains: {'OK' if result.get('contract_chains') else 'FAIL'}")
        print(f"  impact_surfaces: {'OK' if result.get('impact_surfaces') else 'FAIL'}")
        return result
    except Exception as e:
        print(f"  [ERROR] 导航视图生成失败: {e}")
        import traceback
        traceback.print_exc()
        return None


def main():
    print("=" * 60)
    print("Graphify 图谱质量治理流水线")
    print(f"仓库根目录: {REPO_ROOT}")
    print(f"治理版本: {CURATION_VERSION}")
    print("=" * 60)

    _ensure_dirs()

    if not step_copy_raw():
        print("[失败] 原始产物复制失败，终止")
        sys.exit(1)

    manifest = step_generate_manifest()

    result = step_curate(manifest)
    if result is None:
        print("[失败] 图谱治理失败，raw/ 已保留，正式产物未被覆盖")
        sys.exit(1)

    nav_result = step_navigation(manifest)
    if nav_result is None:
        print("[失败] 导航视图生成失败（metadata 和 curated 已生成）")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("流水线执行完成")
    print(f"  run_id: {manifest['run_id']}")
    print(f"  nodes: {result['curated_nodes']}, links: {result['curated_links']}")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())

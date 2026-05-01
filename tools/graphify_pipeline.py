#!/usr/bin/env python3
"""Graphify 图谱质量治理流水线入口。

职责：
1. 生成 run_id 和 manifest.json
2. 通过 staging 目录实现原子构建：本轮产物先进 staging/，成功后再替换正式目录
3. 调用 curate 做降噪和语义治理
4. 调用 navigation 生成导航视图
5. 失败不污染上一轮正式产物

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
STAGING_DIR = GRAPHIFY_OUT / "staging"
RULES_PATH = REPO_ROOT / "tools" / "graphify_rules.json"

CURATION_VERSION = "1.0.0"
PIPELINE_VERSION = "1.0.0"


def _ensure_staging_dirs():
    for d in [
        STAGING_DIR / "raw",
        STAGING_DIR / "quality",
        STAGING_DIR / "navigation",
    ]:
        d.mkdir(parents=True, exist_ok=True)


def _ensure_output_dirs():
    for d in [
        GRAPHIFY_OUT / "raw",
        GRAPHIFY_OUT / "quality",
        GRAPHIFY_OUT / "navigation",
    ]:
        d.mkdir(parents=True, exist_ok=True)


def _get_source_commit():
    import subprocess
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True, text=True, cwd=str(REPO_ROOT), timeout=10
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
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
    """获取 Graphify 版本，返回结构化 dict。"""
    import subprocess
    version = None
    version_source = "unknown"
    available = False

    try:
        result = subprocess.run(
            [sys.executable, "-m", "graphify", "--version"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout.strip():
            version = result.stdout.strip()
            version_source = "graphify --version"
            available = True
    except Exception:
        pass

    if not version:
        try:
            import graphify
            version = getattr(graphify, "__version__", None)
            if version:
                version_source = "graphify.__version__"
                available = True
        except ImportError:
            pass

    return {
        "version": version or "unknown",
        "source": version_source,
        "available": available,
    }


def step_copy_raw(manifest):
    """将 Graphify 原始产物复制到 staging/raw/，注入 run_id。"""
    print("[P0] 复制原始产物到 staging/raw/ ...")
    for src_name in ["graph.json", "GRAPH_REPORT.md"]:
        src = GRAPHIFY_OUT / src_name
        if not src.exists():
            print(f"  [WARN] {src_name} 不存在，跳过")
            continue

        dst_name = src_name.replace(".json", ".raw.json").replace(".md", ".raw.md")
        dst = STAGING_DIR / "raw" / dst_name
        shutil.copy2(src, dst)
        print(f"  {src_name} -> staging/raw/{dst_name}")

        # 对 raw graph.json 注入 run_id
        if src_name == "graph.json":
            raw_data = json.loads(dst.read_text(encoding="utf-8"))
            raw_data["run_id"] = manifest["run_id"]
            raw_data["generated_at"] = manifest["generated_at"]
            raw_data["source_commit"] = manifest["source_commit"]
            raw_data["edge_count"] = len(raw_data.get("links", []))
            if "graph" in raw_data:
                raw_data["graph"]["run_id"] = manifest["run_id"]
            dst.write_text(json.dumps(raw_data, indent=2, ensure_ascii=False), encoding="utf-8")
            print(f"    run_id 已注入")

    return True


def step_generate_manifest():
    """生成 manifest.json 到 staging/。"""
    print("[P0] 生成 manifest.json ...")
    corpus_hash, ignore_hash = _compute_corpus_hash()
    gv = _get_graphify_version()

    manifest = {
        "run_id": str(uuid.uuid4()),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_commit": _get_source_commit(),
        "corpus_hash": corpus_hash,
        "ignore_hash": ignore_hash,
        "graphify_version": gv["version"],
        "graphify_version_source": gv["source"],
        "graphify_available": gv["available"],
        "curation_version": CURATION_VERSION,
        "pipeline_version": PIPELINE_VERSION,
        "repo_root": str(REPO_ROOT),
    }

    with open(STAGING_DIR / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"  run_id: {manifest['run_id']}")
    print(f"  source_commit: {manifest['source_commit']}")
    print(f"  graphify: {manifest['graphify_version']} (available={manifest['graphify_available']})")
    return manifest


def step_curate(manifest):
    """调用治理模块，产出 curated graph.json 到 staging/。"""
    print("[P1/P2] 执行图谱治理 ...")
    try:
        from graphify_curate import curate_graph
        raw_graph_path = STAGING_DIR / "raw" / "graph.raw.json"
        raw_report_path = STAGING_DIR / "raw" / "GRAPH_REPORT.raw.md"

        if not raw_graph_path.exists():
            print("  [ERROR] staging/raw/graph.raw.json 不存在，无法治理")
            return False

        result = curate_graph(
            raw_graph_path=str(raw_graph_path),
            raw_report_path=str(raw_report_path),
            rules_path=str(RULES_PATH),
            manifest=manifest,
            output_dir=str(STAGING_DIR),
            quality_dir=str(STAGING_DIR / "quality"),
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
    """生成导航视图到 staging/。"""
    print("[P3] 生成导航视图 ...")
    try:
        from graphify_navigation import generate_navigation

        curated_graph_path = STAGING_DIR / "graph.json"
        if not curated_graph_path.exists():
            print("  [ERROR] staging/graph.json 不存在，无法生成导航视图")
            return False

        result = generate_navigation(
            graph_path=str(curated_graph_path),
            rules_path=str(RULES_PATH),
            manifest=manifest,
            output_dir=str(STAGING_DIR / "navigation"),
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


def step_atomic_replace():
    """将 staging 产物原子替换到正式 graphify-out 目录。"""
    print("[P0] 原子替换正式产物 ...")

    # 删除旧正式产物（已确保 staging 成功才进入此步骤）
    for sub in ["raw", "quality", "navigation"]:
        target = GRAPHIFY_OUT / sub
        if target.exists():
            shutil.rmtree(target, ignore_errors=True)

    # 移动 staging 产物到正式目录
    for entry in STAGING_DIR.iterdir():
        dst = GRAPHIFY_OUT / entry.name
        if dst.exists():
            if dst.is_dir():
                shutil.rmtree(dst, ignore_errors=True)
            else:
                dst.unlink()
        shutil.move(str(entry), str(dst))

    # 清理 staging 目录
    shutil.rmtree(STAGING_DIR, ignore_errors=True)
    print("  原子替换完成")
    return True


def main():
    print("=" * 60)
    print("Graphify 图谱质量治理流水线")
    print(f"仓库根目录: {REPO_ROOT}")
    print(f"治理版本: {CURATION_VERSION}")
    print("=" * 60)

    # 确保正式输出目录存在
    _ensure_output_dirs()

    # 清理旧 staging
    if STAGING_DIR.exists():
        shutil.rmtree(STAGING_DIR, ignore_errors=True)

    # 创建 staging 目录
    _ensure_staging_dirs()

    # Step 1: 生成 manifest
    manifest = step_generate_manifest()

    # Step 2: 复制原始产物到 staging/raw
    if not step_copy_raw(manifest):
        print("[失败] 原始产物复制失败，终止")
        sys.exit(1)

    # Step 3: 治理
    result = step_curate(manifest)
    if result is None:
        print("[失败] 图谱治理失败，staging 已保留，正式产物未被覆盖")
        sys.exit(1)

    # Step 4: 导航视图
    nav_result = step_navigation(manifest)
    if nav_result is None:
        print("[失败] 导航视图生成失败，staging 已保留，正式产物未被覆盖")
        sys.exit(1)

    # Step 5: 原子替换
    step_atomic_replace()

    print("\n" + "=" * 60)
    print("流水线执行完成")
    print(f"  run_id: {manifest['run_id']}")
    print(f"  nodes: {result['curated_nodes']}, links: {result['curated_links']}")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())

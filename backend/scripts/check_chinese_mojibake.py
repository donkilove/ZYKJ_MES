from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re


CJK_RUN_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]{2,}")
DEFAULT_SCAN_PATHS = ("backend/app", "backend/scripts")


@dataclass(slots=True)
class Finding:
    path: Path
    line: int
    column: int
    kind: str
    source: str
    repaired: str | None = None


def _contains_cjk(value: str) -> bool:
    return any("\u4e00" <= char <= "\u9fff" for char in value)


def _repair_chunk_with_gbk_utf8(chunk: str) -> str | None:
    try:
        repaired = chunk.encode("gbk").decode("utf-8")
    except UnicodeError:
        return None
    if repaired == chunk or not _contains_cjk(repaired):
        return None
    return repaired


def _iter_scan_files(paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for raw_path in paths:
        root = Path(raw_path)
        if not root.exists():
            continue
        if root.is_file():
            if root.suffix == ".py":
                files.append(root)
            continue
        for file_path in root.rglob("*.py"):
            if "__pycache__" in file_path.parts:
                continue
            files.append(file_path)
    return sorted(set(files))


def scan_file(path: Path) -> list[Finding]:
    findings: list[Finding] = []
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        findings.append(
            Finding(
                path=path,
                line=error.start + 1,
                column=1,
                kind="decode_error",
                source=str(error),
                repaired=None,
            )
        )
        return findings

    for line_no, line_text in enumerate(text.splitlines(), start=1):
        if "\ufffd" in line_text:
            findings.append(
                Finding(
                    path=path,
                    line=line_no,
                    column=line_text.index("\ufffd") + 1,
                    kind="replacement_char",
                    source=line_text.strip(),
                )
            )
        for match in CJK_RUN_RE.finditer(line_text):
            source = match.group(0)
            repaired = _repair_chunk_with_gbk_utf8(source)
            if repaired is None:
                continue
            findings.append(
                Finding(
                    path=path,
                    line=line_no,
                    column=match.start() + 1,
                    kind="gbk_utf8_mojibake",
                    source=source,
                    repaired=repaired,
                )
            )
    return findings


def _repair_line(line_text: str) -> tuple[str, bool]:
    changed = False
    chunks: list[str] = []
    cursor = 0
    for match in CJK_RUN_RE.finditer(line_text):
        source = match.group(0)
        repaired = _repair_chunk_with_gbk_utf8(source)
        if repaired is None:
            continue
        chunks.append(line_text[cursor : match.start()])
        chunks.append(repaired)
        cursor = match.end()
        changed = True

    if not changed:
        return line_text, False

    chunks.append(line_text[cursor:])
    return "".join(chunks), True


def repair_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    changed = False
    new_lines: list[str] = []
    for line_text in text.splitlines(keepends=True):
        content = line_text[:-1] if line_text.endswith("\n") else line_text
        suffix = "\n" if line_text.endswith("\n") else ""
        repaired, line_changed = _repair_line(content)
        if line_changed:
            changed = True
        new_lines.append(repaired + suffix)

    if changed:
        path.write_text("".join(new_lines), encoding="utf-8")
    return changed


def scan_paths(paths: list[str]) -> list[Finding]:
    findings: list[Finding] = []
    for path in _iter_scan_files(paths):
        findings.extend(scan_file(path))
    return findings


def _print_findings(findings: list[Finding]) -> None:
    for item in findings:
        location = f"{item.path}:{item.line}:{item.column}"
        if item.repaired is None:
            print(f"[{item.kind}] {location} -> {item.source}")
            continue
        print(f"[{item.kind}] {location} -> {item.source} => {item.repaired}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Scan backend Python source for Chinese mojibake text."
    )
    parser.add_argument(
        "--path",
        action="append",
        dest="paths",
        help="Path to scan. Can be specified multiple times.",
    )
    parser.add_argument(
        "--fix",
        action="store_true",
        help="Auto-repair GBK/UTF-8 mojibake when possible, then re-scan.",
    )
    args = parser.parse_args(argv)

    paths = args.paths or list(DEFAULT_SCAN_PATHS)
    findings = scan_paths(paths)

    if args.fix and findings:
        files_to_repair = sorted(
            {item.path for item in findings if item.kind == "gbk_utf8_mojibake"}
        )
        fixed_count = 0
        for file_path in files_to_repair:
            if repair_file(file_path):
                fixed_count += 1
        if fixed_count:
            print(f"Auto-repaired files: {fixed_count}")
        findings = scan_paths(paths)

    if findings:
        _print_findings(findings)
        print(f"Detected potential mojibake issues: {len(findings)}")
        return 1

    print("No Chinese mojibake detected.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

from scripts.check_chinese_mojibake import scan_paths


def test_backend_has_no_chinese_mojibake() -> None:
    findings = scan_paths(["backend/app", "backend/scripts"])
    assert findings == []

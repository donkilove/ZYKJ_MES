from __future__ import annotations

from scripts.check_frontend_chinese_mojibake import scan_paths


def test_frontend_has_no_chinese_mojibake() -> None:
    findings = scan_paths(["mes_client/lib", "mes_client/test"])
    assert findings == []

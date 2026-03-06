from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select

from app.core import equipment_process, page_catalog
from app.core.security import create_access_token, decode_access_token, get_password_hash, verify_password
from app.models.process import Process
from app.services import maintenance_scheduler_service, online_status_service, process_code_rule


def test_security_password_hash_and_token_roundtrip() -> None:
    hashed = get_password_hash("Secret123!")
    assert verify_password("Secret123!", hashed)
    assert not verify_password("Wrong", hashed)

    token = create_access_token("42", extra_claims={"role": "system_admin"})
    payload = decode_access_token(token)
    assert payload["sub"] == "42"
    assert payload["role"] == "system_admin"


def test_security_decode_invalid_token_raises_value_error() -> None:
    with pytest.raises(ValueError, match="Invalid or expired token"):
        decode_access_token("this-is-not-a-jwt")


def test_equipment_process_helpers() -> None:
    assert equipment_process.is_valid_equipment_process_code(equipment_process.PROCESS_CODE_LASER_MARKING)
    assert not equipment_process.is_valid_equipment_process_code("unknown")

    code = equipment_process.PROCESS_CODE_PRODUCT_TESTING
    assert equipment_process.get_equipment_process_name(code)
    assert equipment_process.map_location_to_process_code(None) == equipment_process.PROCESS_CODE_LASER_MARKING
    assert equipment_process.map_location_to_process_code("unknown") == equipment_process.PROCESS_CODE_LASER_MARKING


def test_page_catalog_helpers() -> None:
    assert page_catalog.is_valid_page_code(page_catalog.PAGE_HOME)
    assert not page_catalog.is_valid_page_code("missing")
    assert page_catalog.is_always_visible_page(page_catalog.PAGE_HOME)
    assert page_catalog.default_page_visible("operator", page_catalog.PAGE_HOME)


def test_process_code_rule_validates_prefix_and_serial(db, factory) -> None:
    stage = factory.stage(code="01", name="stage01")
    normalized = process_code_rule.validate_process_code_matches_stage(code="01-02", stage=stage)
    assert normalized == "01-02"

    with pytest.raises(ValueError, match="must start"):
        process_code_rule.validate_process_code_matches_stage(code="XX-02", stage=stage)

    with pytest.raises(ValueError, match="01-99"):
        process_code_rule.validate_process_code_matches_stage(code="01-00", stage=stage)


def test_process_code_rule_stage_lookup_and_unique(db, factory) -> None:
    stage = factory.stage(code="02", is_enabled=True)
    process = factory.process(stage=stage, code="02-01")

    found = process_code_rule.get_stage_for_process_write(db, stage_id=stage.id, require_enabled=True)
    assert found.id == stage.id

    with pytest.raises(ValueError, match="already exists"):
        process_code_rule.ensure_process_code_unique(db, code=process.code)

    process_code_rule.ensure_process_code_unique(db, code=process.code, exclude_process_id=process.id)


def test_online_status_touch_snapshot_and_clear(monkeypatch) -> None:
    online_status_service._last_seen_by_user_id.clear()
    now = datetime.now(UTC)
    monkeypatch.setattr(online_status_service, "_now_utc", lambda: now)

    online_status_service.touch_user(1)
    is_online, seen_at = online_status_service.get_user_online_snapshot(1)
    assert is_online is True
    assert seen_at == now

    online_status_service.clear_user(1)
    is_online, seen_at = online_status_service.get_user_online_snapshot(1)
    assert is_online is False
    assert seen_at is None


def test_online_status_prunes_expired(monkeypatch) -> None:
    online_status_service._last_seen_by_user_id.clear()
    base = datetime.now(UTC)
    online_status_service._last_seen_by_user_id[100] = base - timedelta(days=1)

    monkeypatch.setattr(online_status_service, "_now_utc", lambda: base)
    is_online, _ = online_status_service.get_user_online_snapshot(100)
    assert is_online is False
    assert 100 not in online_status_service._last_seen_by_user_id


def test_maintenance_scheduler_target_clock_and_next_run(monkeypatch) -> None:
    monkeypatch.setattr(
        maintenance_scheduler_service.settings,
        "maintenance_auto_generate_time",
        "09:30",
    )
    hour, minute = maintenance_scheduler_service._resolve_target_clock()
    assert (hour, minute) == (9, 30)

    now = datetime(2026, 1, 1, 9, 29, 0)
    seconds = maintenance_scheduler_service._seconds_until_next_run(now, hour, minute)
    assert 59 < seconds < 61

    later = datetime(2026, 1, 1, 9, 31, 0)
    next_seconds = maintenance_scheduler_service._seconds_until_next_run(later, hour, minute)
    assert next_seconds > 23 * 3600


def test_maintenance_scheduler_invalid_clock_and_timezone(monkeypatch) -> None:
    monkeypatch.setattr(
        maintenance_scheduler_service.settings,
        "maintenance_auto_generate_time",
        "88:77",
    )
    assert maintenance_scheduler_service._resolve_target_clock() == (0, 5)

    monkeypatch.setattr(
        maintenance_scheduler_service.settings,
        "maintenance_auto_generate_timezone",
        "Invalid/Timezone",
    )
    tz = maintenance_scheduler_service._resolve_timezone()
    assert tz.key == "UTC"

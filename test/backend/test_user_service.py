from __future__ import annotations

import pytest

from app.core.rbac import (
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.core.security import verify_password
from app.schemas.user import UserCreate, UserUpdate
from app.services import user_service


def test_create_user_validations(db, factory) -> None:
    factory.ensure_default_roles()
    stage = factory.stage(code="20")
    process = factory.process(stage=stage, code="20-01")

    user, error = user_service.create_user(
        db,
        UserCreate(
            username="u1",
            full_name="u1",
            password="Passw0rd!",
            role_codes=["invalid"],
            process_codes=[],
        ),
    )
    assert user is None
    assert "Invalid role codes" in (error or "")

    user, error = user_service.create_user(
        db,
        UserCreate(
            username="u2",
            full_name="u2",
            password="Passw0rd!",
            role_codes=[ROLE_OPERATOR],
            process_codes=[],
        ),
    )
    assert user is None
    assert "Operator role must be assigned a stage" in (error or "")

    user, error = user_service.create_user(
        db,
        UserCreate(
            username="u3",
            full_name="u3",
            password="Passw0rd!",
            role_codes=[ROLE_SYSTEM_ADMIN],
            process_codes=[process.code],
        ),
    )
    assert user is None
    assert "Only operator role can be assigned processes" in (error or "")


def test_create_and_update_user_success(db, factory) -> None:
    factory.ensure_default_roles()
    stage = factory.stage(code="21")
    process = factory.process(stage=stage, code="21-01")

    user, error = user_service.create_user(
        db,
        UserCreate(
            username="operator1",
            full_name="op",
            password="Passw0rd!",
            role_codes=[ROLE_OPERATOR],
            process_codes=[process.code],
            stage_id=stage.id,
        ),
    )
    assert error is None
    assert user is not None
    assert [role.code for role in user.roles] == [ROLE_OPERATOR]
    assert [p.code for p in user.processes] == [process.code]

    updated, error = user_service.update_user(
        db,
        user=user,
        payload=UserUpdate(password="NewPass1!", full_name="operator two"),
    )
    assert error is None
    assert updated is not None
    assert verify_password("NewPass1!", updated.password_hash)


def test_list_users_and_all_usernames(db, factory) -> None:
    factory.ensure_default_roles()
    factory.user(username="alice", role_codes=[ROLE_SYSTEM_ADMIN])
    factory.user(username="bob", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    total, rows = user_service.list_users(db, page=1, page_size=10, keyword=None)
    assert total == 2
    assert len(rows) == 2

    usernames = user_service.list_all_usernames(db)
    assert usernames == ["alice", "bob"]


def test_registration_submit_approve_reject_flow(db, factory) -> None:
    factory.ensure_default_roles()
    stage = factory.stage(code="22")
    process = factory.process(stage=stage, code="22-01")

    req, error = user_service.submit_registration_request(db, account="new_user", password="Passw0rd!")
    assert error is None
    assert req is not None

    req2, error = user_service.submit_registration_request(db, account="new_user", password="Passw0rd!")
    assert req2 is None
    assert "pending" in (error or "")

    user, error = user_service.approve_registration_request(
        db,
        request=req,
        account="new_user",
        password=None,
        role_codes=[ROLE_OPERATOR],
        process_codes=[process.code],
        stage_id=stage.id,
        reviewer=None,
    )
    assert error is None
    assert user is not None
    assert user.username == "new_user"

    req3, error = user_service.submit_registration_request(db, account="to_reject", password="Passw0rd!")
    assert req3 is not None
    assert error is None
    user_service.reject_registration_request(db, request=req3, reason=None, reviewer=None)
    rejected_req = user_service.get_registration_request_by_id(db, req3.id)
    assert rejected_req is not None
    assert rejected_req.status == "rejected"


def test_ensure_admin_account_and_normalize_single_role(db, factory) -> None:
    factory.ensure_default_roles()
    operator_role = user_service.get_roles_by_codes(db, [ROLE_OPERATOR])[0][0]
    prod_role = user_service.get_roles_by_codes(db, [ROLE_PRODUCTION_ADMIN])[0][0]

    multi_role_user = factory.user(username="multi", role_codes=[ROLE_OPERATOR])
    multi_role_user.roles = [prod_role, operator_role]
    stage = factory.stage(code="23")
    process = factory.process(stage=stage, code="23-01")
    multi_role_user.processes = [process]
    db.commit()

    normalized_count = user_service.normalize_users_to_single_role(db)
    assert normalized_count == 1

    db.refresh(multi_role_user)
    assert len(multi_role_user.roles) == 1
    assert multi_role_user.roles[0].code == ROLE_PRODUCTION_ADMIN
    assert multi_role_user.processes == []

    admin, created, repaired = user_service.ensure_admin_account(db, password="Admin@123")
    assert admin.username == "admin"
    assert created is True
    assert repaired is False

    admin_again, created_again, repaired_again = user_service.ensure_admin_account(db, password="Admin@123")
    assert admin_again.id == admin.id
    assert created_again is False
    assert repaired_again is False


def test_update_user_conflict_and_invalid_processes(db, factory) -> None:
    factory.ensure_default_roles()
    stage = factory.stage(code="24")
    process = factory.process(stage=stage, code="24-01")

    user1, _ = user_service.create_user(
        db,
        UserCreate(
            username="u100",
            full_name="u100",
            password="Passw0rd!",
            role_codes=[ROLE_OPERATOR],
            process_codes=[process.code],
            stage_id=stage.id,
        ),
    )
    user2, _ = user_service.create_user(
        db,
        UserCreate(
            username="u101",
            full_name="u101",
            password="Passw1rd!",
            role_codes=[ROLE_QUALITY_ADMIN],
            process_codes=[],
        ),
    )
    assert user1 and user2

    updated, error = user_service.update_user(db, user=user2, payload=UserUpdate(username="u100"))
    assert updated is None
    assert "Only system administrator can modify username" in (error or "")

    updated, error = user_service.update_user(
        db,
        user=user1,
        payload=UserUpdate(role_codes=[ROLE_SYSTEM_ADMIN], process_codes=[process.code]),
    )
    assert updated is None
    assert "Only operator role" in (error or "")

from __future__ import annotations

import base64
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.api.v1.endpoints import auth, audits, me, roles, sessions, users
from app.core.rbac import ROLE_OPERATOR, ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.core.security import create_access_token, verify_password
from app.models.role import Role
from app.models.user import User
from app.models.user_session import UserSession
from app.schemas.auth import ApproveRegistrationRequest, RegisterRequest, RejectRegistrationRequest
from app.schemas.me import ChangePasswordRequest
from app.schemas.role import RoleCreate, RoleUpdate
from app.schemas.session import BatchForceOfflineRequest, ForceOfflineRequest
from app.schemas.user import UserCreate, UserResetPasswordRequest, UserUpdate
from app.services.audit_service import write_audit_log
from app.services.session_service import create_login_log, create_user_session


def _mock_request(ip: str = "127.0.0.1", user_agent: str = "pytest-user-module") -> SimpleNamespace:
    return SimpleNamespace(
        client=SimpleNamespace(host=ip),
        headers={"user-agent": user_agent},
    )


def test_users_endpoints_full_lifecycle_and_export(db, factory) -> None:
    factory.ensure_default_roles()
    admin = factory.user(username="um_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = factory.stage(code="81", name="装配工段")
    process_a = factory.process(stage=stage, code="81-01", name="装配工序1")
    process_b = factory.process(stage=stage, code="81-02", name="装配工序2")
    db.commit()

    created = users.create_user_api(
        UserCreate(
            username="um_op01",
            full_name="用户模块操作员",
            password="OpInit@123",
            role_codes=[ROLE_OPERATOR],
            process_codes=[process_b.code, process_a.code],
            stage_id=stage.id,
            is_active=True,
        ),
        request=_mock_request(),
        db=db,
        current_user=admin,
    )

    user_id = created.data.id
    assert created.message == "created"
    assert created.data.username == "um_op01"
    assert created.data.stage_id == stage.id
    assert created.data.process_codes == [process_a.code, process_b.code]

    created_row = db.get(User, user_id)
    assert created_row is not None
    create_user_session(
        db,
        user=created_row,
        ip_address="10.0.0.8",
        terminal_info="pytest-online",
    )
    db.commit()

    listed = users.get_users(
        page=1,
        page_size=20,
        keyword="um_",
        role_code=ROLE_OPERATOR,
        stage_id=stage.id,
        is_active=True,
        is_online=True,
        include_deleted=False,
        db=db,
        _=admin,
    )
    assert listed.data.total == 1
    assert listed.data.items[0].username == "um_op01"
    assert listed.data.items[0].is_online is True

    export_resp = users.export_users(
        keyword="um_op01",
        role_code=ROLE_OPERATOR,
        stage_id=stage.id,
        is_active=True,
        format="csv",
        db=db,
        _=admin,
    )
    csv_text = base64.b64decode(export_resp.data.content_base64).decode("utf-8-sig")
    assert "用户名" in csv_text
    assert "um_op01" in csv_text

    updated = users.update_user_api(
        user_id,
        UserUpdate(
            full_name="用户模块管理员",
            role_codes=[ROLE_PRODUCTION_ADMIN],
            process_codes=[],
            is_active=False,
            remark="切换为生产管理员",
        ),
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert updated.data.full_name == "用户模块管理员"
    assert updated.data.role_codes == [ROLE_PRODUCTION_ADMIN]
    assert updated.data.stage_id is None
    assert updated.data.process_codes == []
    assert updated.data.is_active is False

    enabled = users.enable_user_api(
        user_id,
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert enabled.data.is_active is True

    reset = users.reset_password_api(
        user_id,
        request=_mock_request(),
        payload=UserResetPasswordRequest(password="Reset@123"),
        db=db,
        current_user=admin,
    )
    db.refresh(created_row)
    assert reset.data.must_change_password is True
    assert verify_password("Reset@123", created_row.password_hash)

    disabled = users.disable_user_api(
        user_id,
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert disabled.data.is_active is False

    deleted = users.delete_user_api(
        user_id,
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert deleted.data["deleted"] is True

    detail = users.get_user_detail(user_id, db=db, _=admin)
    assert detail.data.is_deleted is True

    active_list = users.get_users(
        page=1,
        page_size=20,
        keyword="um_op01",
        role_code=None,
        stage_id=None,
        is_active=None,
        is_online=None,
        include_deleted=False,
        db=db,
        _=admin,
    )
    assert active_list.data.total == 0

    include_deleted_list = users.get_users(
        page=1,
        page_size=20,
        keyword="um_op01",
        role_code=None,
        stage_id=None,
        is_active=None,
        is_online=None,
        include_deleted=True,
        db=db,
        _=admin,
    )
    assert include_deleted_list.data.total == 1
    assert include_deleted_list.data.items[0].is_deleted is True


def test_users_endpoints_online_filter_before_pagination(db, factory) -> None:
    factory.ensure_default_roles()
    admin = factory.user(username="um_online_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    factory.user(username="um_online_filter_a", role_codes=[ROLE_SYSTEM_ADMIN])
    factory.user(username="um_online_filter_b", role_codes=[ROLE_PRODUCTION_ADMIN])
    online_user = factory.user(username="um_online_filter_c", role_codes=[ROLE_OPERATOR])
    db.commit()

    create_user_session(
        db,
        user=online_user,
        ip_address="10.9.9.9",
        terminal_info="pytest-online-filter-endpoint",
    )
    db.commit()

    online = users.get_users(
        page=1,
        page_size=1,
        keyword="um_online_filter_",
        role_code=None,
        stage_id=None,
        is_active=None,
        is_online=True,
        include_deleted=False,
        db=db,
        _=admin,
    )
    assert online.data.total == 1
    assert [item.username for item in online.data.items] == ["um_online_filter_c"]

    offline = users.get_users(
        page=1,
        page_size=1,
        keyword="um_online_filter_",
        role_code=None,
        stage_id=None,
        is_active=None,
        is_online=False,
        include_deleted=False,
        db=db,
        _=admin,
    )
    assert offline.data.total == 2
    assert [item.username for item in offline.data.items] == ["um_online_filter_a"]


def test_users_endpoints_validation_errors(db, factory) -> None:
    factory.ensure_default_roles()
    admin = factory.user(username="um_validate_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    editor = factory.user(username="um_editor", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    with pytest.raises(HTTPException) as operator_without_stage:
        users.create_user_api(
            UserCreate(
                username="um_badop",
                full_name="bad",
                password="BadOp@123",
                role_codes=[ROLE_OPERATOR],
                process_codes=[],
                stage_id=None,
            ),
            request=_mock_request(),
            db=db,
            current_user=admin,
        )
    assert operator_without_stage.value.status_code == 400
    assert "Operator role must be assigned a stage" in str(operator_without_stage.value.detail)

    target = users.create_user_api(
        UserCreate(
            username="um_target",
            full_name="um_target",
            password="Target@123",
            role_codes=[ROLE_PRODUCTION_ADMIN],
            process_codes=[],
            stage_id=None,
        ),
        request=_mock_request(),
        db=db,
        current_user=admin,
    )

    with pytest.raises(HTTPException) as non_admin_rename:
        users.update_user_api(
            target.data.id,
            UserUpdate(username="um_new2"),
            request=_mock_request(),
            db=db,
            current_user=editor,
        )
    assert non_admin_rename.value.status_code == 400
    assert "Only system administrator can modify username" in str(non_admin_rename.value.detail)

    with pytest.raises(HTTPException) as self_delete:
        users.delete_user_api(
            admin.id,
            request=_mock_request(),
            db=db,
            current_user=admin,
        )
    assert self_delete.value.status_code == 400
    assert "Cannot delete current login user" in str(self_delete.value.detail)


def test_roles_endpoints_custom_role_lifecycle_and_builtin_guard(db, factory) -> None:
    factory.ensure_default_roles()
    admin = factory.user(username="um_role_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    db.commit()

    with pytest.raises(HTTPException) as builtin_create:
        roles.create_role_api(
            RoleCreate(
                code="um_builtin_try",
                name="手工内置角色",
                role_type="builtin",
            ),
            request=_mock_request(),
            db=db,
            current_user=admin,
        )
    assert builtin_create.value.status_code == 400
    assert "系统内置角色由系统维护，不支持手动创建" in str(builtin_create.value.detail)

    created = roles.create_role_api(
        RoleCreate(
            code="um_custom_role",
            name="用户模块自定义角色",
            description="用于功能测试",
            is_enabled=False,
        ),
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    role_id = created.data.id
    assert created.message == "created"
    assert created.data.code == "um_custom_role"
    assert created.data.is_enabled is False

    detail = roles.get_role_detail(role_id, db=db, _=admin)
    assert detail.data.user_count == 0

    updated = roles.update_role_api(
        role_id,
        RoleUpdate(
            name="用户模块自定义角色-更新",
            description="更新后描述",
        ),
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert updated.data.name == "用户模块自定义角色-更新"

    enabled = roles.enable_role_api(
        role_id,
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert enabled.data.is_enabled is True

    disabled = roles.disable_role_api(
        role_id,
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert disabled.data.is_enabled is False

    deleted = roles.delete_role_api(
        role_id,
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert deleted.data["deleted"] is True

    with pytest.raises(HTTPException) as deleted_detail:
        roles.get_role_detail(role_id, db=db, _=admin)
    assert deleted_detail.value.status_code == 404

    builtin_role = db.execute(select(Role).where(Role.code == ROLE_SYSTEM_ADMIN)).scalars().one()
    with pytest.raises(HTTPException) as delete_builtin:
        roles.delete_role_api(
            builtin_role.id,
            request=_mock_request(),
            db=db,
            current_user=admin,
        )
    assert delete_builtin.value.status_code == 400
    assert "Built-in role cannot be deleted" in str(delete_builtin.value.detail)


def test_registration_request_endpoints_approve_and_reject(db, factory) -> None:
    factory.ensure_default_roles()
    reviewer = factory.user(username="um_reviewer", role_codes=[ROLE_SYSTEM_ADMIN])
    stage = factory.stage(code="82", name="审核工段")
    process = factory.process(stage=stage, code="82-01", name="审核工序")
    db.commit()

    first_register = auth.register(RegisterRequest(account="um_reg_a", password="Passw0rd!"), db=db)
    assert first_register.message == "submitted"

    with pytest.raises(HTTPException) as duplicate_pending:
        auth.register(RegisterRequest(account="um_reg_a", password="Passw0rd!"), db=db)
    assert duplicate_pending.value.status_code == 400
    assert "pending approval" in str(duplicate_pending.value.detail)

    list_resp = auth.get_registration_requests(
        page=1,
        page_size=20,
        keyword="um_reg_a",
        status_filter="pending",
        db=db,
        _=reviewer,
    )
    assert list_resp.data.total == 1
    request_id = list_resp.data.items[0].id

    approved = auth.approve_registration(
        request_id,
        ApproveRegistrationRequest(
            account="um_reg_a",
            password="Init@123",
            role_codes=[ROLE_OPERATOR],
            process_codes=[process.code],
            stage_id=stage.id,
        ),
        request=_mock_request(),
        db=db,
        current_user=reviewer,
    )
    assert approved.data.approved is True
    assert approved.data.status == "approved"
    assert approved.data.role_codes == [ROLE_OPERATOR]
    assert approved.data.process_codes == [process.code]

    auth.register(RegisterRequest(account="um_reg_b", password="Passw0rd!"), db=db)
    request_b = auth.get_registration_requests(
        page=1,
        page_size=20,
        keyword="um_reg_b",
        status_filter="pending",
        db=db,
        _=reviewer,
    ).data.items[0]

    rejected = auth.reject_registration(
        request_b.id,
        RejectRegistrationRequest(reason="资料不完整"),
        request=_mock_request(),
        db=db,
        current_user=reviewer,
    )
    assert rejected.data.approved is False
    assert rejected.data.status == "rejected"
    assert rejected.data.rejected_reason == "资料不完整"

    rejected_detail = auth.get_registration_request(request_b.id, db=db, _=reviewer)
    assert rejected_detail.data.status == "rejected"


def test_me_endpoints_profile_session_and_change_password(db, factory) -> None:
    factory.ensure_default_roles()
    current_user = factory.user(
        username="um_me_user",
        role_codes=[ROLE_SYSTEM_ADMIN],
        password="Passw0rd!",
    )
    db.commit()

    session_row = create_user_session(
        db,
        user=current_user,
        ip_address="10.1.1.1",
        terminal_info="pytest-me",
    )
    db.commit()
    token = create_access_token(
        subject=str(current_user.id),
        extra_claims={"sid": session_row.session_token_id},
    )

    profile = me.get_my_profile(current_user=current_user)
    assert profile.data.username == "um_me_user"
    assert ROLE_SYSTEM_ADMIN in profile.data.role_codes

    current_session = me.get_my_session(token=token, db=db, current_user=current_user)
    assert current_session.data.session_token_id == session_row.session_token_id
    assert current_session.data.status == "active"
    assert current_session.data.remaining_seconds > 0

    changed = me.change_my_password(
        ChangePasswordRequest(
            old_password="Passw0rd!",
            new_password="MeNew@123",
            confirm_password="MeNew@123",
        ),
        request=_mock_request(),
        token=token,
        db=db,
        current_user=current_user,
    )
    assert changed.data["changed"] is True

    db.refresh(current_user)
    assert verify_password("MeNew@123", current_user.password_hash)

    persisted_session = db.execute(
        select(UserSession).where(UserSession.session_token_id == session_row.session_token_id)
    ).scalars().one()
    assert persisted_session.status == "logged_out"

    current_session_after_change = me.get_my_session(
        token=token,
        db=db,
        current_user=current_user,
    )
    assert current_session_after_change.data.status == "logged_out"

    with pytest.raises(HTTPException) as wrong_old_password:
        me.change_my_password(
            ChangePasswordRequest(
                old_password="wrong-pass",
                new_password="Another@123",
                confirm_password="Another@123",
            ),
            request=_mock_request(),
            token=token,
            db=db,
            current_user=current_user,
        )
    assert wrong_old_password.value.status_code == 400
    assert "Original password is incorrect" in str(wrong_old_password.value.detail)

    token_without_sid = create_access_token(subject=str(current_user.id))
    with pytest.raises(HTTPException) as no_sid:
        me.get_my_session(token=token_without_sid, db=db, current_user=current_user)
    assert no_sid.value.status_code == 404


def test_sessions_endpoints_login_logs_online_and_force_offline(db, factory) -> None:
    factory.ensure_default_roles()
    admin = factory.user(username="um_session_admin", role_codes=[ROLE_SYSTEM_ADMIN])
    target_user = factory.user(username="um_session_target", role_codes=[ROLE_OPERATOR])
    non_admin = factory.user(username="um_session_prod", role_codes=[ROLE_PRODUCTION_ADMIN])
    db.commit()

    target_session = create_user_session(
        db,
        user=target_user,
        ip_address="10.2.0.10",
        terminal_info="pytest-target",
    )
    create_login_log(
        db,
        username=target_user.username,
        user_id=target_user.id,
        success=True,
        ip_address="10.2.0.10",
        terminal_info="pytest-target",
        session_token_id=target_session.session_token_id,
    )
    create_login_log(
        db,
        username=target_user.username,
        user_id=target_user.id,
        success=False,
        ip_address="10.2.0.11",
        terminal_info="pytest-target-failed",
        failure_reason="bad password",
    )
    db.commit()

    login_logs = sessions.get_login_logs(
        page=1,
        page_size=20,
        username="um_session_target",
        success=True,
        start_time=None,
        end_time=None,
        db=db,
        _=admin,
    )
    assert login_logs.data.total == 1
    assert login_logs.data.items[0].username == "um_session_target"
    assert login_logs.data.items[0].success is True

    online = sessions.get_online_sessions(
        page=1,
        page_size=20,
        keyword="um_session_target",
        db=db,
        _=admin,
    )
    assert online.data.total == 1
    assert online.data.items[0].session_token_id == target_session.session_token_id

    with pytest.raises(HTTPException) as no_permission:
        sessions.force_offline(
            ForceOfflineRequest(session_token_id=target_session.session_token_id),
            request=_mock_request(),
            db=db,
            current_user=non_admin,
        )
    assert no_permission.value.status_code == 403

    forced = sessions.force_offline(
        ForceOfflineRequest(session_token_id=target_session.session_token_id),
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert forced.data.affected == 1
    db.refresh(target_session)
    assert target_session.status == "forced_offline"

    with pytest.raises(HTTPException) as not_found:
        sessions.force_offline(
            ForceOfflineRequest(session_token_id=target_session.session_token_id),
            request=_mock_request(),
            db=db,
            current_user=admin,
        )
    assert not_found.value.status_code == 404

    batch_session_a = create_user_session(
        db,
        user=target_user,
        ip_address="10.2.0.12",
        terminal_info="pytest-batch-a",
    )
    batch_session_b = create_user_session(
        db,
        user=target_user,
        ip_address="10.2.0.13",
        terminal_info="pytest-batch-b",
    )
    db.commit()

    batch_forced = sessions.batch_force_offline(
        BatchForceOfflineRequest(
            session_token_ids=[batch_session_a.session_token_id, batch_session_b.session_token_id]
        ),
        request=_mock_request(),
        db=db,
        current_user=admin,
    )
    assert batch_forced.data.affected == 2
    db.refresh(batch_session_a)
    db.refresh(batch_session_b)
    assert batch_session_a.status == "forced_offline"
    assert batch_session_b.status == "forced_offline"


def test_audit_logs_endpoint_filters(db, factory) -> None:
    factory.ensure_default_roles()
    operator_a = factory.user(username="um_audit_a", role_codes=[ROLE_SYSTEM_ADMIN])
    operator_b = factory.user(username="um_audit_b", role_codes=[ROLE_SYSTEM_ADMIN])
    db.commit()

    write_audit_log(
        db,
        action_code="user.create",
        action_name="新建用户",
        target_type="user",
        target_id="1001",
        target_name="alice",
        operator=operator_a,
    )
    write_audit_log(
        db,
        action_code="user.disable",
        action_name="停用用户",
        target_type="user",
        target_id="1002",
        target_name="bob",
        operator=operator_b,
    )
    write_audit_log(
        db,
        action_code="role.create",
        action_name="新建角色",
        target_type="role",
        target_id="2001",
        target_name="custom_role",
        operator=operator_a,
    )
    db.commit()

    by_operator = audits.get_audit_logs(
        page=1,
        page_size=20,
        operator_username="um_audit_a",
        action_code=None,
        target_type=None,
        start_time=None,
        end_time=None,
        db=db,
        _=operator_a,
    )
    assert by_operator.data.total == 2
    assert all(item.operator_username == "um_audit_a" for item in by_operator.data.items)

    by_action_target = audits.get_audit_logs(
        page=1,
        page_size=20,
        operator_username=None,
        action_code="user.create",
        target_type="user",
        start_time=None,
        end_time=None,
        db=db,
        _=operator_a,
    )
    assert by_action_target.data.total == 1
    assert by_action_target.data.items[0].target_name == "alice"

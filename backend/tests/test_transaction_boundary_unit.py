import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api.v1.endpoints import equipment, production, products, roles, users
from app.services import (
    assist_authorization_service,
    equipment_service,
    product_service,
    role_service,
    user_service,
)


class TransactionBoundaryUnitTest(unittest.TestCase):
    def test_create_product_service_does_not_commit_transaction(self) -> None:
        db = MagicMock()
        operator = SimpleNamespace(id=7)

        with (
            patch.object(product_service, "_create_product_revision_snapshot", return_value=object()),
            patch.object(product_service, "_sync_current_parameter_rows"),
            patch.object(product_service, "_append_revision_history"),
            patch.object(product_service, "_clone_default_craft_template_for_new_product"),
        ):
            product_service.create_product(
                db,
                "产品A",
                category="分类A",
                remark="备注",
                operator=operator,
            )

        db.commit.assert_not_called()
        db.refresh.assert_called_once()

    def test_create_product_api_rolls_back_when_audit_log_fails(self) -> None:
        db = MagicMock()
        current_user = SimpleNamespace(id=7)
        product = SimpleNamespace(id=11, name="产品A", category="分类A", remark="备注")
        payload = SimpleNamespace(name="产品A", category="分类A", remark="备注")

        with (
            patch.object(products, "get_product_by_name", return_value=None),
            patch.object(products, "create_product", return_value=product),
            patch.object(products, "write_audit_log", side_effect=RuntimeError("audit failed")),
        ):
            with self.assertRaisesRegex(RuntimeError, "audit failed"):
                products.create_product_api(
                    payload,
                    db=db,
                    current_user=current_user,
                )

        db.rollback.assert_called_once()

    def test_create_role_service_does_not_commit_transaction(self) -> None:
        db = MagicMock()
        payload = SimpleNamespace(
            code="role_a",
            role_type="custom",
            name="角色A",
            description="说明",
            is_enabled=True,
        )

        with (
            patch.object(role_service, "get_role_by_code_case_insensitive", return_value=None),
            patch.object(role_service, "get_role_by_name_case_insensitive", return_value=None),
        ):
            role, errors = role_service.create_role(db, payload)

        self.assertIsNotNone(role)
        self.assertEqual(errors, [])
        db.commit.assert_not_called()
        db.flush.assert_called_once()
        db.refresh.assert_called_once()

    def test_create_role_api_rolls_back_when_audit_log_fails(self) -> None:
        db = MagicMock()
        current_user = SimpleNamespace(id=7)
        role = SimpleNamespace(
            id=12,
            code="role_a",
            name="角色A",
            role_type="custom",
            is_enabled=True,
        )
        payload = SimpleNamespace()
        request = SimpleNamespace(
            client=SimpleNamespace(host="127.0.0.1"),
            headers={"user-agent": "unit-test"},
        )

        with (
            patch.object(roles, "create_role", return_value=(role, [])),
            patch.object(roles, "write_audit_log", side_effect=RuntimeError("audit failed")),
        ):
            with self.assertRaisesRegex(RuntimeError, "audit failed"):
                roles.create_role_api(
                    payload,
                    request=request,
                    db=db,
                    current_user=current_user,
                )

        db.rollback.assert_called_once()

    def test_create_user_service_does_not_commit_transaction(self) -> None:
        db = MagicMock()
        payload = SimpleNamespace(
            username="user_a",
            password="Pwd@123",
            role_code="operator",
            full_name="用户A",
            remark="备注",
            is_active=True,
            stage_id=None,
        )
        role = None
        stage = None
        processes = []

        with (
            patch.object(user_service, "normalize_username", return_value="user_a"),
            patch.object(user_service, "get_user_by_username", return_value=None),
            patch.object(user_service, "validate_password", return_value=None),
            patch.object(user_service, "_resolve_role", return_value=(role, None)),
            patch.object(user_service, "_resolve_stage", return_value=(stage, None)),
            patch.object(user_service, "_resolve_processes", return_value=(processes, None)),
            patch.object(user_service, "get_password_hash", return_value="hashed"),
        ):
            user, error = user_service.create_user(db, payload)

        self.assertIsNotNone(user)
        self.assertIsNone(error)
        db.commit.assert_not_called()
        db.flush.assert_called_once()
        db.refresh.assert_called_once()

    def test_create_user_api_rolls_back_when_audit_log_fails(self) -> None:
        db = MagicMock()
        current_user = SimpleNamespace(id=7)
        request = SimpleNamespace(
            client=SimpleNamespace(host="127.0.0.1"),
            headers={"user-agent": "unit-test"},
        )
        user = SimpleNamespace(
            id=21,
            username="user_a",
            stage_id=None,
            roles=[SimpleNamespace(code="operator")],
        )
        payload = SimpleNamespace()

        with (
            patch.object(users, "create_user", return_value=(user, None)),
            patch.object(users, "write_audit_log", side_effect=RuntimeError("audit failed")),
        ):
            with self.assertRaisesRegex(RuntimeError, "audit failed"):
                users.create_user_api(
                    payload,
                    request=request,
                    db=db,
                    current_user=current_user,
                )

        db.rollback.assert_called_once()

    def test_create_assist_authorization_service_does_not_commit_transaction(self) -> None:
        db = MagicMock()
        order = SimpleNamespace(id=31, status="in_progress")
        process_row = SimpleNamespace(id=41, status="in_progress", process_name="工序A")
        helper = SimpleNamespace(username="helper", is_active=True)
        target_operator = SimpleNamespace(is_active=True)
        requester = SimpleNamespace(id=7, username="requester")

        with (
            patch.object(
                assist_authorization_service,
                "_get_order_and_process_for_update",
                return_value=(order, process_row),
            ),
            patch.object(db, "get", side_effect=[helper, target_operator]),
            patch.object(
                assist_authorization_service,
                "_ensure_target_sub_order_exists",
            ),
            patch.object(db.execute.return_value.scalars(), "first", return_value=None),
            patch.object(assist_authorization_service, "add_order_event_log"),
        ):
            row = assist_authorization_service.create_assist_authorization(
                db,
                order_id=31,
                order_process_id=41,
                target_operator_user_id=51,
                helper_user_id=61,
                reason="代班",
                requester=requester,
            )

        self.assertIsNotNone(row)
        db.commit.assert_not_called()
        db.flush.assert_called_once()
        db.refresh.assert_called_once()

    def test_create_assist_authorization_api_commits_once(self) -> None:
        db = MagicMock()
        current_user = SimpleNamespace(id=7)
        payload = SimpleNamespace(
            order_process_id=41,
            target_operator_user_id=51,
            helper_user_id=61,
            reason="代班",
        )
        row = SimpleNamespace(id=91)

        with (
            patch.object(production, "create_assist_authorization", return_value=row),
            patch.object(production, "_to_assist_authorization_item", return_value={"id": 91}),
        ):
            response = production.create_assist_authorization_api(
                order_id=31,
                payload=payload,
                db=db,
                current_user=current_user,
            )

        db.commit.assert_called_once()
        self.assertEqual(response.data["id"], 91)

    def test_create_equipment_service_does_not_commit_transaction(self) -> None:
        db = MagicMock()

        with patch.object(equipment_service, "get_equipment_by_code", return_value=None):
            row = equipment_service.create_equipment(
                db,
                code="EQ-001",
                name="设备A",
                model="M1",
                location="A1",
                owner_name="owner",
                remark="remark",
            )

        self.assertIsNotNone(row)
        db.commit.assert_not_called()
        db.flush.assert_called_once()
        db.refresh.assert_called_once()

    def test_create_equipment_api_rolls_back_when_audit_log_fails(self) -> None:
        db = MagicMock()
        current_user = SimpleNamespace(id=7)
        payload = SimpleNamespace(
            code="EQ-001",
            name="设备A",
            model="M1",
            location="A1",
            owner_name="owner",
            remark="remark",
        )
        row = SimpleNamespace(id=101, code="EQ-001", name="设备A", model="M1")

        with (
            patch.object(equipment, "create_equipment", return_value=row),
            patch.object(equipment, "write_audit_log", side_effect=RuntimeError("audit failed")),
        ):
            with self.assertRaisesRegex(RuntimeError, "audit failed"):
                equipment.create_equipment_ledger(
                    payload,
                    db=db,
                    current_user=current_user,
                )

        db.rollback.assert_called_once()


if __name__ == "__main__":
    unittest.main()

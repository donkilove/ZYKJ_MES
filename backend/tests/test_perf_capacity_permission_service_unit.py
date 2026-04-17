import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.rbac import (
    ROLE_MAINTENANCE_STAFF,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
)
from app.services import authz_service
from app.services import perf_capacity_permission_service


class PerfCapacityPermissionServiceUnitTest(unittest.TestCase):
    def test_maintenance_staff_equipment_template_is_not_empty(self) -> None:
        capability_codes = {
            "feature.equipment.ledger.manage",
            "feature.equipment.executions.operate",
        }

        result = authz_service._role_template_capability_codes(
            module_code="equipment",
            role_code=ROLE_MAINTENANCE_STAFF,
            capability_codes=capability_codes,
        )

        self.assertEqual(
            result,
            sorted(capability_codes),
        )

    def test_build_perf_capacity_permission_rollout_plan_targets_expected_role_modules(
        self,
    ) -> None:
        db = MagicMock()

        def fake_permission_catalog(db, *, module_code: str):
            mapping = {
                "production": ["production.orders.detail"],
                "craft": ["craft.templates.detail"],
                "product": ["product.products.view"],
                "quality": ["quality.trend.view"],
                "equipment": ["equipment.ledger.view"],
            }
            return [
                authz_service.PermissionCatalogRow(
                    permission_code=permission_code,
                    permission_name=permission_code,
                    module_code=module_code,
                    resource_type="permission",
                    parent_permission_code=None,
                    is_enabled=True,
                )
                for permission_code in mapping[module_code]
            ]

        with patch.object(
            perf_capacity_permission_service.authz_service,
            "list_permission_catalog_rows",
            side_effect=fake_permission_catalog,
        ):
            plan = perf_capacity_permission_service.build_perf_capacity_permission_rollout_plan(db)

        self.assertEqual(
            [(item.role_code, item.module_code) for item in plan],
            [
                (ROLE_PRODUCTION_ADMIN, "production"),
                (ROLE_PRODUCTION_ADMIN, "craft"),
                (ROLE_PRODUCTION_ADMIN, "product"),
                (ROLE_QUALITY_ADMIN, "quality"),
                (ROLE_MAINTENANCE_STAFF, "equipment"),
            ],
        )

    def test_build_perf_capacity_permission_rollout_plan_uses_permission_catalog_codes(
        self,
    ) -> None:
        db = MagicMock()

        with patch.object(
            perf_capacity_permission_service.authz_service,
            "list_permission_catalog_rows",
            side_effect=[
                [
                    authz_service.PermissionCatalogRow(
                        permission_code="production.orders.detail",
                        permission_name="订单详情",
                        module_code="production",
                        resource_type="permission",
                        parent_permission_code=None,
                        is_enabled=True,
                    ),
                    authz_service.PermissionCatalogRow(
                        permission_code="production.orders.list",
                        permission_name="订单列表",
                        module_code="production",
                        resource_type="permission",
                        parent_permission_code=None,
                        is_enabled=True,
                    ),
                ],
                [
                    authz_service.PermissionCatalogRow(
                        permission_code="craft.templates.detail",
                        permission_name="模板详情",
                        module_code="craft",
                        resource_type="permission",
                        parent_permission_code=None,
                        is_enabled=True,
                    ),
                ],
            ],
        ):
            plan = perf_capacity_permission_service.build_perf_capacity_permission_rollout_plan(
                db,
                role_modules=[
                    (ROLE_PRODUCTION_ADMIN, "production"),
                    (ROLE_PRODUCTION_ADMIN, "craft"),
                ],
            )

        self.assertEqual(
            plan[0].permission_codes,
            ["production.orders.detail", "production.orders.list"],
        )
        self.assertEqual(plan[1].permission_codes, ["craft.templates.detail"])

    def test_apply_perf_capacity_permission_rollout_calls_authz_update(self) -> None:
        db = MagicMock()
        plan = [
            perf_capacity_permission_service.PerfCapacityPermissionPlanItem(
                role_code=ROLE_PRODUCTION_ADMIN,
                module_code="production",
                permission_codes=["production.orders.detail"],
            ),
            perf_capacity_permission_service.PerfCapacityPermissionPlanItem(
                role_code=ROLE_QUALITY_ADMIN,
                module_code="quality",
                permission_codes=["quality.stats.view"],
            ),
        ]

        with (
            patch.object(
                perf_capacity_permission_service,
                "build_perf_capacity_permission_rollout_plan",
                return_value=plan,
            ),
            patch.object(
                perf_capacity_permission_service.authz_service,
                "replace_role_permissions_for_module",
                side_effect=[
                    (3, [], ["production.orders.detail"]),
                    (2, [], ["quality.stats.view"]),
                ],
            ) as replace_role_permissions,
        ):
            result = perf_capacity_permission_service.apply_perf_capacity_permission_rollout(db)

        self.assertEqual(result.updated_count, 5)
        self.assertEqual(result.role_module_pairs, 2)
        self.assertEqual(replace_role_permissions.call_count, 2)


if __name__ == "__main__":
    unittest.main()

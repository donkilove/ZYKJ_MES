import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.rbac import (
    ROLE_MAINTENANCE_STAFF,
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
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
                "user": ["user.users.list"],
                "system": ["authz.role_permissions.view"],
                "message": ["message.messages.list"],
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
                (ROLE_SYSTEM_ADMIN, "user"),
                (ROLE_SYSTEM_ADMIN, "system"),
                (ROLE_SYSTEM_ADMIN, "message"),
                (ROLE_PRODUCTION_ADMIN, "production"),
                (ROLE_OPERATOR, "production"),
                (ROLE_PRODUCTION_ADMIN, "craft"),
                (ROLE_PRODUCTION_ADMIN, "product"),
                (ROLE_QUALITY_ADMIN, "quality"),
                (ROLE_MAINTENANCE_STAFF, "equipment"),
            ],
        )

    def test_build_perf_capacity_permission_rollout_plan_limits_operator_production_permissions(
        self,
    ) -> None:
        db = MagicMock()

        def fake_permission_catalog(db, *, module_code: str):
            mapping = {
                "production": [
                    "module.production.access",
                    "page.production.view",
                    "page.production_order_query.view",
                    "feature.production.order_query.execute",
                    "feature.production.assist.launch",
                    "feature.production.repair_orders.create_manual",
                    "production.my_orders.list",
                    "production.my_orders.context",
                    "production.execution.first_article",
                    "production.execution.end_production",
                    "production.assist_authorizations.create",
                    "production.assist_user_options.list",
                    "production.repair_orders.create_manual",
                    "production.orders.create",
                ]
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
            plan = perf_capacity_permission_service.build_perf_capacity_permission_rollout_plan(
                db,
                role_modules=[(ROLE_OPERATOR, "production")],
            )

        self.assertEqual(len(plan), 1)
        self.assertEqual(plan[0].role_code, ROLE_OPERATOR)
        self.assertEqual(plan[0].module_code, "production")
        self.assertIn("production.my_orders.list", plan[0].permission_codes)
        self.assertIn("production.execution.first_article", plan[0].permission_codes)
        self.assertNotIn("production.orders.create", plan[0].permission_codes)

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
                perf_capacity_permission_service,
                "_grant_quality_admin_production_scrap_permissions",
                return_value=0,
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

    def test_apply_perf_capacity_permission_rollout_invalidates_cache_even_when_no_db_delta(
        self,
    ) -> None:
        db = MagicMock()
        plan = [
            perf_capacity_permission_service.PerfCapacityPermissionPlanItem(
                role_code=ROLE_SYSTEM_ADMIN,
                module_code="system",
                permission_codes=["authz.role_permissions.view"],
            )
        ]

        with (
            patch.object(
                perf_capacity_permission_service,
                "build_perf_capacity_permission_rollout_plan",
                return_value=plan,
            ),
            patch.object(
                perf_capacity_permission_service,
                "_grant_quality_admin_production_scrap_permissions",
                return_value=0,
            ),
            patch.object(
                perf_capacity_permission_service.authz_service,
                "replace_role_permissions_for_module",
                return_value=(0, ["authz.role_permissions.view"], ["authz.role_permissions.view"]),
            ),
            patch.object(
                perf_capacity_permission_service.authz_service,
                "invalidate_permission_cache",
            ) as invalidate_cache,
            patch.object(
                perf_capacity_permission_service,
                "_apply_hierarchy_rollout_if_supported",
                return_value=0,
            ),
        ):
            result = perf_capacity_permission_service.apply_perf_capacity_permission_rollout(db)

        self.assertEqual(result.updated_count, 0)
        invalidate_cache.assert_called_once()

    def test_apply_perf_capacity_permission_rollout_applies_user_hierarchy_for_system_admin(
        self,
    ) -> None:
        db = MagicMock()
        plan = [
            perf_capacity_permission_service.PerfCapacityPermissionPlanItem(
                role_code=ROLE_SYSTEM_ADMIN,
                module_code="user",
                permission_codes=["user.users.list"],
            )
        ]

        with (
            patch.object(
                perf_capacity_permission_service,
                "build_perf_capacity_permission_rollout_plan",
                return_value=plan,
            ),
            patch.object(
                perf_capacity_permission_service,
                "_grant_quality_admin_production_scrap_permissions",
                return_value=0,
            ),
            patch.object(
                perf_capacity_permission_service.authz_service,
                "replace_role_permissions_for_module",
                return_value=(1, [], ["user.users.list"]),
            ),
            patch.object(
                perf_capacity_permission_service.authz_service,
                "get_permission_hierarchy_catalog",
                return_value={
                    "pages": [{"permission_code": "page.user.view"}],
                    "features": [
                        {"permission_code": "feature.user.user_management.view"}
                    ],
                },
            ),
            patch.object(
                perf_capacity_permission_service.authz_service,
                "update_permission_hierarchy_role_config",
                return_value={"updated_count": 3},
            ) as update_hierarchy,
        ):
            result = perf_capacity_permission_service.apply_perf_capacity_permission_rollout(db)

        update_hierarchy.assert_called_once_with(
            db,
            role_code=ROLE_SYSTEM_ADMIN,
            module_code="user",
            module_enabled=True,
            page_permission_codes=["page.user.view"],
            feature_permission_codes=["feature.user.user_management.view"],
            dry_run=False,
            operator=None,
        )
        self.assertEqual(result.updated_count, 4)
        self.assertEqual(result.items[0]["hierarchy_updated_count"], 3)

    def test_apply_perf_capacity_permission_rollout_applies_hierarchy_for_system_module(
        self,
    ) -> None:
        db = MagicMock()
        plan = [
            perf_capacity_permission_service.PerfCapacityPermissionPlanItem(
                role_code=ROLE_SYSTEM_ADMIN,
                module_code="system",
                permission_codes=["authz.permissions.catalog.view"],
            )
        ]

        with (
            patch.object(
                perf_capacity_permission_service,
                "build_perf_capacity_permission_rollout_plan",
                return_value=plan,
            ),
            patch.object(
                perf_capacity_permission_service,
                "_grant_quality_admin_production_scrap_permissions",
                return_value=0,
            ),
            patch.object(
                perf_capacity_permission_service.authz_service,
                "replace_role_permissions_for_module",
                return_value=(1, [], ["authz.permissions.catalog.view"]),
            ),
            patch.object(
                perf_capacity_permission_service.authz_service,
                "get_permission_hierarchy_catalog",
                return_value={
                    "pages": [{"permission_code": "page.function_permission_config.view"}],
                    "features": [
                        {
                            "permission_code": "feature.system.role_permissions.manage"
                        }
                    ],
                },
            ),
            patch.object(
                perf_capacity_permission_service.authz_service,
                "update_permission_hierarchy_role_config",
                return_value={"updated_count": 2},
            ) as update_hierarchy,
        ):
            result = perf_capacity_permission_service.apply_perf_capacity_permission_rollout(db)

        update_hierarchy.assert_called_once()
        self.assertEqual(result.updated_count, 3)
        self.assertEqual(result.items[0]["hierarchy_updated_count"], 2)


if __name__ == "__main__":
    unittest.main()

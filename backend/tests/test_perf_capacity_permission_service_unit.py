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

        def fake_catalog(db, *, module_code: str):
            mapping = {
                "production": {ROLE_PRODUCTION_ADMIN: ["feature.production.order_query.execute"]},
                "craft": {ROLE_PRODUCTION_ADMIN: ["feature.craft.templates.manage"]},
                "product": {ROLE_PRODUCTION_ADMIN: ["feature.product.products.manage"]},
                "quality": {ROLE_QUALITY_ADMIN: ["feature.quality.trend.view"]},
                "equipment": {ROLE_MAINTENANCE_STAFF: ["feature.equipment.executions.operate"]},
            }
            role_templates = []
            for role_code, capability_codes in mapping[module_code].items():
                role_templates.append(
                    {
                        "role_code": role_code,
                        "capability_codes": capability_codes,
                    }
                )
            return {"role_templates": role_templates}

        with patch.object(
            perf_capacity_permission_service.authz_service,
            "get_capability_pack_catalog",
            side_effect=fake_catalog,
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

    def test_apply_perf_capacity_permission_rollout_calls_authz_update(self) -> None:
        db = MagicMock()
        plan = [
            perf_capacity_permission_service.PerfCapacityPermissionPlanItem(
                role_code=ROLE_PRODUCTION_ADMIN,
                module_code="production",
                capability_codes=["feature.production.order_query.execute"],
            ),
            perf_capacity_permission_service.PerfCapacityPermissionPlanItem(
                role_code=ROLE_QUALITY_ADMIN,
                module_code="quality",
                capability_codes=["feature.quality.trend.view"],
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
                "update_capability_pack_role_config",
                side_effect=[
                    {"updated_count": 3},
                    {"updated_count": 2},
                ],
            ) as update_role_config,
        ):
            result = perf_capacity_permission_service.apply_perf_capacity_permission_rollout(db)

        self.assertEqual(result.updated_count, 5)
        self.assertEqual(result.role_module_pairs, 2)
        self.assertEqual(update_role_config.call_count, 2)


if __name__ == "__main__":
    unittest.main()

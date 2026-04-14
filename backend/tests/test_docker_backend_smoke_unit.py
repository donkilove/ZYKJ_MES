import importlib.util
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "tools" / "docker_backend_smoke.py"


def _load_module():
    spec = importlib.util.spec_from_file_location(
        "docker_backend_smoke",
        SCRIPT_PATH,
    )
    if spec is None or spec.loader is None:
        raise ImportError(f"无法加载脚本：{SCRIPT_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules["docker_backend_smoke"] = module
    spec.loader.exec_module(module)
    return module


class DockerBackendSmokeUnitTest(unittest.TestCase):
    def test_smoke_script_exists(self) -> None:
        self.assertTrue(SCRIPT_PATH.exists(), f"缺少脚本：{SCRIPT_PATH}")

    def test_default_env_matches_docker_runtime_contract(self) -> None:
        module = _load_module()
        self.assertEqual(
            module.DEFAULT_ENV,
            {
                "POSTGRES_HOST_PORT": "5433",
                "BACKEND_WEB_HOST_PORT": "8000",
                "JWT_SECRET_KEY": "docker-local-jwt-secret-20260414",
                "BOOTSTRAP_ADMIN_PASSWORD": "Admin_Local_20260414!",
                "PRODUCTION_DEFAULT_VERIFICATION_CODE": "FA20260414",
            },
        )

    def test_default_checks_cover_current_smoke_chain(self) -> None:
        module = _load_module()
        self.assertEqual(
            module.DEFAULT_CHECKS,
            [
                "health",
                "login",
                "authz_catalog",
                "role_create",
                "user_create",
                "product_create",
                "production_order_flow",
                "first_article_flow",
                "export_flow",
            ],
        )

    def test_smoke_module_exposes_long_flow_entrypoints(self) -> None:
        module = _load_module()
        self.assertTrue(callable(module.smoke_production_order_flow))
        self.assertTrue(callable(module.smoke_first_article_flow))
        self.assertTrue(callable(module.smoke_export_flow))


if __name__ == "__main__":
    unittest.main()

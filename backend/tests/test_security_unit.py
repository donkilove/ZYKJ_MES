import sys
import unittest
from pathlib import Path
from unittest.mock import patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core import security


class SecurityUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        security._PASSWORD_VERIFY_LOCAL_CACHE.clear()

    def test_verify_password_cached_hits_local_cache_after_first_success(self) -> None:
        with (
            patch.object(security.time, "monotonic", side_effect=[10.0, 20.0]),
            patch.object(security, "verify_password", return_value=True) as verify_password,
        ):
            first = security.verify_password_cached(
                "Pwd@123",
                "hash-1",
                cache_scope="user:7",
            )
            second = security.verify_password_cached(
                "Pwd@123",
                "hash-1",
                cache_scope="user:7",
            )

        self.assertTrue(first)
        self.assertTrue(second)
        verify_password.assert_called_once_with("Pwd@123", "hash-1")

    def test_verify_password_cached_does_not_cache_failed_verification(self) -> None:
        with (
            patch.object(security.time, "monotonic", side_effect=[10.0, 20.0]),
            patch.object(security, "verify_password", return_value=False) as verify_password,
        ):
            first = security.verify_password_cached(
                "Wrong@123",
                "hash-1",
                cache_scope="user:7",
            )
            second = security.verify_password_cached(
                "Wrong@123",
                "hash-1",
                cache_scope="user:7",
            )

        self.assertFalse(first)
        self.assertFalse(second)
        self.assertEqual(verify_password.call_count, 2)

    def test_create_access_token_rejects_insecure_placeholder_secret(self) -> None:
        with patch.object(
            security.settings,
            "jwt_secret_key",
            "replace_with_a_strong_secret",
        ):
            with self.assertRaisesRegex(ValueError, "JWT"):
                security.create_access_token("7")


    def test_rehash_password_if_needed_returns_new_hash_for_rounds12(self) -> None:
        from passlib.context import CryptContext
        old_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)
        old_hash = old_ctx.hash("Pwd@123")
        result = security.rehash_password_if_needed("Pwd@123", old_hash)
        self.assertIsNotNone(result)
        # 新哈希应可用当前 context 验证通过
        self.assertTrue(security.pwd_context.verify("Pwd@123", result))

    def test_rehash_password_if_needed_returns_none_for_current_rounds(self) -> None:
        current_hash = security.pwd_context.hash("Pwd@123")
        result = security.rehash_password_if_needed("Pwd@123", current_hash)
        self.assertIsNone(result)


if __name__ == "__main__":
    unittest.main()

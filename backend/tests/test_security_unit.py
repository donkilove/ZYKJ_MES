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


if __name__ == "__main__":
    unittest.main()

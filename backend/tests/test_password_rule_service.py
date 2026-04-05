import sys
import time
import unittest
from pathlib import Path

from sqlalchemy import delete


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.security import get_password_hash  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.models.registration_request import RegistrationRequest  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.user import User  # noqa: E402
from app.schemas.user import UserCreate  # noqa: E402
from app.services.user_service import approve_registration_request  # noqa: E402
from app.services.user_service import change_user_password  # noqa: E402
from app.services.user_service import create_user  # noqa: E402
from app.services.user_service import reset_user_password  # noqa: E402


class PasswordRuleServiceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.db = SessionLocal()
        self.usernames: list[str] = []
        self.role_codes: list[str] = []
        self.request_ids: list[int] = []
        self.role = self._create_role()

    def tearDown(self) -> None:
        try:
            for request_id in self.request_ids:
                self.db.execute(
                    delete(RegistrationRequest).where(
                        RegistrationRequest.id == request_id
                    )
                )

            for username in self.usernames:
                user = (
                    self.db.query(User).filter(User.username == username).one_or_none()
                )
                if user is None:
                    continue
                user.roles.clear()
                self.db.flush()
                self.db.delete(user)

            for role_code in self.role_codes:
                role = self.db.query(Role).filter(Role.code == role_code).one_or_none()
                if role is not None:
                    self.db.delete(role)

            self.db.commit()
        finally:
            self.db.close()

    def _create_role(self) -> Role:
        suffix = str(time.time_ns())
        role = Role(
            code=f"pwd_rule_{suffix}",
            name=f"密码规则角色{suffix}",
            role_type="custom",
            is_builtin=False,
            is_enabled=True,
            is_deleted=False,
        )
        self.db.add(role)
        self.db.commit()
        self.db.refresh(role)
        self.role_codes.append(role.code)
        return role

    def _create_user_direct(self, *, username: str, password: str) -> User:
        user = User(
            username=username,
            full_name=username,
            password_hash=get_password_hash(password),
            is_active=True,
            is_superuser=False,
            is_deleted=False,
            must_change_password=False,
        )
        user.roles = [self.role]
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        self.usernames.append(username)
        return user

    def _create_pending_request(self, *, account: str) -> RegistrationRequest:
        request = RegistrationRequest(
            account=account,
            password_hash=get_password_hash("Pending@123"),
            status="pending",
        )
        self.db.add(request)
        self.db.commit()
        self.db.refresh(request)
        self.request_ids.append(int(request.id))
        return request

    def test_create_user_rejects_four_consecutive_identical_chars(self) -> None:
        payload = UserCreate(
            username=f"u{str(time.time_ns())[-8:]}",
            password="Ab1111",
            role_code=self.role.code,
            is_active=True,
        )

        user, error = create_user(self.db, payload)

        self.assertIsNone(user)
        self.assertEqual(error, "密码不得包含连续4位相同字符")

    def test_create_user_allows_password_matching_existing_user_password(self) -> None:
        shared_password = "Shared@123"
        self._create_user_direct(
            username=f"u{str(time.time_ns())[-8:]}",
            password=shared_password,
        )
        username = f"u{str(time.time_ns())[-7:]}"

        created_user, error = create_user(
            self.db,
            UserCreate(
                username=username,
                password=shared_password,
                role_code=self.role.code,
                is_active=True,
            ),
        )

        self.assertIsNone(error)
        self.assertIsNotNone(created_user)
        self.usernames.append(username)

    def test_approve_registration_request_allows_password_matching_existing_user_password(
        self,
    ) -> None:
        shared_password = "Shared@123"
        self._create_user_direct(
            username=f"u{str(time.time_ns())[-8:]}",
            password=shared_password,
        )
        request = self._create_pending_request(account=f"r{str(time.time_ns())[-8:]}")
        username = f"u{str(time.time_ns())[-7:]}"

        approved_user, error = approve_registration_request(
            self.db,
            request=request,
            account=username,
            password=shared_password,
            role_code=self.role.code,
            stage_id=None,
            reviewer=None,
        )

        self.assertIsNone(error)
        self.assertIsNotNone(approved_user)
        self.usernames.append(username)

    def test_reset_user_password_allows_password_matching_existing_user_password(
        self,
    ) -> None:
        shared_password = "Shared@123"
        self._create_user_direct(
            username=f"u{str(time.time_ns())[-8:]}",
            password=shared_password,
        )
        target_user = self._create_user_direct(
            username=f"u{str(time.time_ns())[-7:]}",
            password="Reset@123",
        )

        updated_user, error = reset_user_password(
            self.db,
            user=target_user,
            new_password=shared_password,
        )

        self.assertIsNone(error)
        self.assertIsNotNone(updated_user)

    def test_change_user_password_keeps_self_service_extra_checks(self) -> None:
        user = self._create_user_direct(
            username=f"u{str(time.time_ns())[-8:]}",
            password="Pwd@123",
        )

        ok, error = change_user_password(
            self.db,
            user=user,
            old_password="Wrong@123",
            new_password="NewPwd@123",
            confirm_password="NewPwd@123",
        )
        self.assertFalse(ok)
        self.assertEqual(error, "原密码不正确")

        ok, error = change_user_password(
            self.db,
            user=user,
            old_password="Pwd@123",
            new_password="NewPwd@123",
            confirm_password="NewPwd@456",
        )
        self.assertFalse(ok)
        self.assertEqual(error, "新密码与确认密码不一致")

        ok, error = change_user_password(
            self.db,
            user=user,
            old_password="Pwd@123",
            new_password="Pwd@123",
            confirm_password="Pwd@123",
        )
        self.assertFalse(ok)
        self.assertEqual(error, "新密码不能与原密码相同")


if __name__ == "__main__":
    unittest.main()

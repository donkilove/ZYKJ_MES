import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api.v1.endpoints import production as production_endpoint
from app.services import audit_service, role_service, session_service, user_service
from app.services import process_service


class ListQueryOptimizationUnitTest(unittest.TestCase):
    def _prepare_db(self, *, total: int = 0) -> MagicMock:
        db = MagicMock()
        total_result = MagicMock()
        total_result.scalar_one.return_value = total
        rows_result = MagicMock()
        rows_result.scalars.return_value.all.return_value = []
        db.execute.side_effect = [total_result, rows_result]
        return db

    def test_list_registration_requests_total_query_avoids_subquery(self) -> None:
        db = self._prepare_db(total=3)

        total, rows = user_service.list_registration_requests(
            db,
            page=1,
            page_size=20,
            keyword="demo",
            status="pending",
        )

        self.assertEqual(total, 3)
        self.assertEqual(rows, [])
        total_stmt = db.execute.call_args_list[0].args[0]
        self.assertNotIn("FROM (SELECT", str(total_stmt))

    def test_list_roles_total_query_avoids_subquery(self) -> None:
        db = self._prepare_db(total=5)

        total, rows = role_service.list_roles(db, page=1, page_size=20, keyword="admin")

        self.assertEqual(total, 5)
        self.assertEqual(rows, [])
        total_stmt = db.execute.call_args_list[0].args[0]
        self.assertNotIn("FROM (SELECT", str(total_stmt))

    def test_list_audit_logs_total_query_avoids_subquery(self) -> None:
        db = self._prepare_db(total=7)

        total, rows = audit_service.list_audit_logs(
            db,
            page=1,
            page_size=20,
            operator_username="demo",
        )

        self.assertEqual(total, 7)
        self.assertEqual(rows, [])
        total_stmt = db.execute.call_args_list[0].args[0]
        self.assertNotIn("FROM (SELECT", str(total_stmt))

    def test_list_login_logs_total_query_avoids_subquery(self) -> None:
        db = self._prepare_db(total=11)

        total, rows = session_service.list_login_logs(
            db,
            page=1,
            page_size=20,
            username="demo",
        )

        self.assertEqual(total, 11)
        self.assertEqual(rows, [])
        total_stmt = db.execute.call_args_list[0].args[0]
        self.assertNotIn("FROM (SELECT", str(total_stmt))

    def test_list_processes_total_query_avoids_subquery(self) -> None:
        db = self._prepare_db(total=9)

        total, rows = process_service.list_processes(
            db,
            page=1,
            page_size=20,
            keyword="装配",
        )

        self.assertEqual(total, 9)
        self.assertEqual(rows, [])
        total_stmt = db.execute.call_args_list[0].args[0]
        self.assertNotIn("FROM (SELECT", str(total_stmt))

    def test_assist_user_options_total_query_avoids_subquery(self) -> None:
        db = MagicMock()
        total_result = MagicMock()
        total_result.scalar.return_value = 4
        rows_result = MagicMock()
        rows_result.scalars.return_value.unique.return_value.all.return_value = []
        db.execute.side_effect = [total_result, rows_result]

        result = production_endpoint.get_assist_user_options_api(
            page=1,
            page_size=50,
            keyword="demo",
            role_code=None,
            stage_id=None,
            db=db,
            _=None,
        )

        self.assertEqual(result.data.total, 4)
        self.assertEqual(result.data.items, [])
        total_stmt = db.execute.call_args_list[0].args[0]
        self.assertNotIn("FROM (SELECT", str(total_stmt))


if __name__ == "__main__":
    unittest.main()

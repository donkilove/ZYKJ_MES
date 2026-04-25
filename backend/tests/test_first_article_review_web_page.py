import sys
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient
from starlette.requests import Request


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.main import app  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.web.first_article_review_page import build_first_article_review_url  # noqa: E402


class FirstArticleReviewWebPageTest(unittest.TestCase):
    def tearDown(self) -> None:
        settings.public_base_url = ""

    def test_first_article_review_page_is_served_from_backend(self) -> None:
        client = TestClient(app)
        response = client.get("/first-article-review?token=abc")

        self.assertEqual(response.status_code, 200, response.text)
        self.assertIn("text/html", response.headers.get("content-type", ""))
        self.assertIn("首件扫码复核", response.text)
        self.assertIn("/api/v1/auth/login", response.text)

    def test_build_first_article_review_url_uses_backend_origin(self) -> None:
        request = Request(
            {
                "type": "http",
                "scheme": "http",
                "server": ("192.168.10.5", 8000),
                "method": "POST",
                "path": "/api/v1/production/orders/1/first-article/review-sessions",
                "query_string": b"",
                "headers": [],
                "client": ("127.0.0.1", 50000),
                "root_path": "",
            }
        )

        self.assertEqual(
            build_first_article_review_url(
                request,
                "/first-article-review?token=abc",
            ),
            "http://192.168.10.5:8000/first-article-review?token=abc",
        )

    def test_build_first_article_review_url_prefers_public_base_url(self) -> None:
        settings.public_base_url = "http://192.168.1.88:8000"
        request = Request(
            {
                "type": "http",
                "scheme": "http",
                "server": ("127.0.0.1", 8000),
                "method": "POST",
                "path": "/api/v1/production/orders/1/first-article/review-sessions",
                "query_string": b"",
                "headers": [],
                "client": ("127.0.0.1", 50000),
                "root_path": "",
            }
        )

        self.assertEqual(
            build_first_article_review_url(
                request,
                "/first-article-review?token=abc",
            ),
            "http://192.168.1.88:8000/first-article-review?token=abc",
        )

    def test_build_first_article_review_url_replaces_loopback_with_lan_ip(self) -> None:
        request = Request(
            {
                "type": "http",
                "scheme": "http",
                "server": ("127.0.0.1", 8000),
                "method": "POST",
                "path": "/api/v1/production/orders/1/first-article/review-sessions",
                "query_string": b"",
                "headers": [],
                "client": ("127.0.0.1", 50000),
                "root_path": "",
            }
        )

        with patch(
            "app.web.first_article_review_page._detect_local_ipv4",
            return_value="192.168.1.54",
        ):
            self.assertEqual(
                build_first_article_review_url(
                    request,
                    "/first-article-review?token=abc",
                ),
                "http://192.168.1.54:8000/first-article-review?token=abc",
            )


if __name__ == "__main__":
    unittest.main()

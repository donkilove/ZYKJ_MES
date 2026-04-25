from __future__ import annotations

from pathlib import Path
from urllib.parse import urljoin

from fastapi import APIRouter, Request
from fastapi.responses import FileResponse


router = APIRouter()
_PAGE_PATH = Path(__file__).resolve().parents[1] / "static" / "first_article_review.html"


def build_first_article_review_url(request: Request, review_url: str | None) -> str | None:
    raw = (review_url or "").strip()
    if not raw:
        return None
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw
    return urljoin(str(request.base_url), raw)


@router.get("/first-article-review", include_in_schema=False)
def get_first_article_review_page() -> FileResponse:
    return FileResponse(
        _PAGE_PATH,
        media_type="text/html",
        headers={"Cache-Control": "no-store"},
    )

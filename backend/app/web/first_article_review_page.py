from __future__ import annotations

import ipaddress
import socket
from pathlib import Path
from urllib.parse import urljoin, urlsplit, urlunsplit

from fastapi import APIRouter, Request
from fastapi.responses import FileResponse

from app.core.config import settings


router = APIRouter()
_PAGE_PATH = Path(__file__).resolve().parents[1] / "static" / "first_article_review.html"


def _normalize_base_url(value: str | None) -> str:
    return (value or "").strip().rstrip("/")


def _is_loopback_host(host: str | None) -> bool:
    normalized = (host or "").strip().lower()
    return normalized in {"127.0.0.1", "localhost", "::1"}


def _is_usable_ipv4(value: str) -> bool:
    try:
        address = ipaddress.ip_address(value)
    except ValueError:
        return False
    return (
        isinstance(address, ipaddress.IPv4Address)
        and not address.is_loopback
        and not address.is_link_local
        and not address.is_multicast
        and not address.is_unspecified
    )


def _detect_local_ipv4() -> str | None:
    candidates: list[str] = []

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            candidates.append(sock.getsockname()[0])
    except OSError:
        pass

    try:
        host_name = socket.gethostname()
        for _, _, _, _, sockaddr in socket.getaddrinfo(
            host_name,
            None,
            socket.AF_INET,
            socket.SOCK_DGRAM,
        ):
            candidates.append(sockaddr[0])
    except OSError:
        pass

    for candidate in candidates:
        if _is_usable_ipv4(candidate):
            return candidate
    return None


def _request_origin(request: Request) -> str:
    public_base_url = _normalize_base_url(settings.public_base_url)
    if public_base_url:
        return public_base_url

    parts = urlsplit(str(request.base_url))
    host = parts.hostname or ""
    netloc = parts.netloc
    if _is_loopback_host(host):
        detected_ip = _detect_local_ipv4()
        if detected_ip:
            netloc = f"{detected_ip}:{parts.port}" if parts.port else detected_ip
    return urlunsplit((parts.scheme, netloc, "/", "", "")).rstrip("/")


def build_first_article_review_url(request: Request, review_url: str | None) -> str | None:
    raw = (review_url or "").strip()
    if not raw:
        return None
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw
    return urljoin(f"{_request_origin(request)}/", raw.lstrip("/"))


@router.get("/first-article-review", include_in_schema=False)
def get_first_article_review_page() -> FileResponse:
    return FileResponse(
        _PAGE_PATH,
        media_type="text/html",
        headers={"Cache-Control": "no-store"},
    )

from __future__ import annotations

import json
import socket
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from urllib.parse import parse_qs, urlparse

from app.serial_bridge import SerialBridge


def _find_free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def start_server(base_dir: Path) -> tuple[int, str]:
    bridge = SerialBridge()
    web_root = base_dir / "web"
    heartbeat_path = "/__heartbeat__"

    class Handler(BaseHTTPRequestHandler):
        def _send_json(self, status: HTTPStatus, payload: dict) -> None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _read_json_body(self) -> dict:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
            return json.loads(raw or "{}")

        def do_GET(self) -> None:  # noqa: N802
            parsed = urlparse(self.path)
            if parsed.path == heartbeat_path:
                self._send_json(HTTPStatus.OK, {"status": "ok"})
                return
            if parsed.path == "/api/ports":
                self._send_json(HTTPStatus.OK, {"items": bridge.list_ports()})
                return
            if parsed.path == "/api/read":
                handle = parse_qs(parsed.query).get("handle", [""])[0]
                timeout = float(parse_qs(parsed.query).get("timeout", ["0.2"])[0])
                if not handle:
                    self._send_json(
                        HTTPStatus.BAD_REQUEST,
                        {"message": "缺少 handle"},
                    )
                    return
                self._send_json(
                    HTTPStatus.OK,
                    {"payload": bridge.read(handle, timeout=timeout)},
                )
                return
            self._serve_static(parsed.path)

        def do_POST(self) -> None:  # noqa: N802
            parsed = urlparse(self.path)
            payload = self._read_json_body()
            try:
                if parsed.path == "/api/open":
                    handle = bridge.open(
                        payload["port"],
                        int(payload.get("baudrate", 115200)),
                    )
                    self._send_json(
                        HTTPStatus.OK,
                        {
                            "handle": handle,
                            "status": "opened",
                            "port": payload["port"],
                            "baudrate": int(payload.get("baudrate", 115200)),
                        },
                    )
                    return
                if parsed.path == "/api/send":
                    bridge.send(payload["handle"], payload.get("payload", ""))
                    self._send_json(HTTPStatus.OK, {"status": "sent"})
                    return
                if parsed.path == "/api/close":
                    bridge.close(payload["handle"])
                    self._send_json(
                        HTTPStatus.OK,
                        {"status": "closed", "handle": payload["handle"]},
                    )
                    return
            except Exception as error:  # noqa: BLE001
                self._send_json(
                    HTTPStatus.BAD_REQUEST,
                    {"message": str(error)},
                )
                return
            self._send_json(HTTPStatus.NOT_FOUND, {"message": "未找到接口"})

        def log_message(self, format: str, *args) -> None:  # noqa: A003
            return

        def _serve_static(self, request_path: str) -> None:
            relative_path = request_path.lstrip("/") or "index.html"
            target = (web_root / relative_path).resolve()
            if not str(target).startswith(str(web_root.resolve())) or not target.exists():
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            content = target.read_bytes()
            if target.suffix == ".html":
                content_type = "text/html; charset=utf-8"
            elif target.suffix == ".js":
                content_type = "text/javascript; charset=utf-8"
            else:
                content_type = "application/octet-stream"
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

    port = _find_free_port()
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    Thread(target=server.serve_forever, daemon=True).start()
    return port, heartbeat_path

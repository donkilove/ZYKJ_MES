from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path


BASE_DIR = Path(r"C:\Users\Donki\UserData\Code\ZYKJ_MES\evidence\opencode_instructions_live_fix")
LAST_REQUEST_BODY = BASE_DIR / "last_request_body.json"
LAST_REQUEST_META = BASE_DIR / "last_request_meta.json"


class Handler(BaseHTTPRequestHandler):
    def _write_json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)
        parsed_body = json.loads(raw_body.decode("utf-8"))

        LAST_REQUEST_BODY.write_text(
            json.dumps(parsed_body, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        LAST_REQUEST_META.write_text(
            json.dumps(
                {
                    "method": self.command,
                    "path": self.path,
                    "content_type": self.headers.get("Content-Type"),
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )

        if isinstance(parsed_body.get("instructions"), str) and parsed_body["instructions"].strip():
            self._write_json(
                200,
                {
                    "id": "resp_mock_ok",
                    "object": "response",
                    "status": "completed",
                    "output": [
                        {
                            "type": "message",
                            "role": "assistant",
                            "content": [
                                {
                                    "type": "output_text",
                                    "text": "mock ok"
                                }
                            ]
                        }
                    ]
                },
            )
            return

        self._write_json(400, {"detail": "Instructions are required"})

    def log_message(self, format: str, *args) -> None:
        return


if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", 18080), Handler)
    server.serve_forever()

from __future__ import annotations

import sys
import time
import uuid
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
VENDOR_DIR = BASE_DIR / "vendor"
if VENDOR_DIR.exists():
    sys.path.insert(0, str(VENDOR_DIR))

import serial
from serial.tools import list_ports


class SerialBridge:
    def __init__(self) -> None:
        self._connections: dict[str, serial.SerialBase] = {}

    def list_ports(self) -> list[dict[str, str]]:
        ports = [
            {
                "port": port.device,
                "description": port.description,
            }
            for port in list_ports.comports()
        ]
        ports.append({"port": "loop://", "description": "内置回环测试端口"})
        return ports

    def open(self, port: str, baudrate: int) -> str:
        handle = uuid.uuid4().hex
        connection = serial.serial_for_url(port, baudrate=baudrate, timeout=0.1)
        self._connections[handle] = connection
        return handle

    def send(self, handle: str, payload: str) -> None:
        connection = self._connections[handle]
        connection.write(payload.encode("utf-8"))

    def read(self, handle: str, timeout: float = 1.0) -> str:
        deadline = time.time() + timeout
        connection = self._connections[handle]
        buffer = bytearray()
        while time.time() < deadline:
            chunk = connection.read(connection.in_waiting or 1)
            if chunk:
                buffer.extend(chunk)
                return buffer.decode("utf-8", errors="replace")
        return ""

    def close(self, handle: str) -> None:
        connection = self._connections.pop(handle, None)
        if connection is not None:
            connection.close()

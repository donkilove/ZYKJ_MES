from __future__ import annotations

import asyncio
import logging
from collections import defaultdict

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class MessageConnectionManager:
    """管理 WebSocket 连接池，按 user_id 维护在线连接"""

    def __init__(self) -> None:
        # user_id -> set of WebSocket
        self._connections: dict[int, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, user_id: int) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections[user_id].add(websocket)
        logger.debug(
            "[MSG_WS] 用户 %s 建立连接，当前连接数 %s",
            user_id,
            len(self._connections[user_id]),
        )

    async def connect_already_accepted(self, websocket: WebSocket, user_id: int) -> None:
        async with self._lock:
            self._connections[user_id].add(websocket)
        logger.debug(
            "[MSG_WS] 用户 %s 建立连接，当前连接数 %s",
            user_id,
            len(self._connections[user_id]),
        )

    async def disconnect(self, websocket: WebSocket, user_id: int) -> None:
        async with self._lock:
            self._connections[user_id].discard(websocket)
            if not self._connections[user_id]:
                del self._connections[user_id]
        logger.debug("[MSG_WS] 用户 %s 断开连接", user_id)

    async def push_to_user(
        self, user_id: int, payload: dict
    ) -> tuple[bool, str | None]:
        """向指定用户的所有在线连接推送轻量事件"""
        async with self._lock:
            sockets = set(self._connections.get(user_id, set()))
        if not sockets:
            return False, "no_active_connection"
        dead: list[WebSocket] = []
        delivered = False
        failure_reason: str | None = None
        for ws in sockets:
            try:
                await ws.send_json(payload)
                delivered = True
            except Exception:
                dead.append(ws)
                failure_reason = "send_json_failed"
        if dead:
            async with self._lock:
                for ws in dead:
                    self._connections[user_id].discard(ws)
        if delivered:
            return True, None
        return False, failure_reason or "push_failed"

    def online_user_ids(self) -> list[int]:
        return list(self._connections.keys())


# 全局单例
message_connection_manager = MessageConnectionManager()

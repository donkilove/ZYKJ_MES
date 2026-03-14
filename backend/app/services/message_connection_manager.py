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
        logger.debug("[MSG_WS] 用户 %s 建立连接，当前连接数 %s", user_id, len(self._connections[user_id]))

    async def disconnect(self, websocket: WebSocket, user_id: int) -> None:
        async with self._lock:
            self._connections[user_id].discard(websocket)
            if not self._connections[user_id]:
                del self._connections[user_id]
        logger.debug("[MSG_WS] 用户 %s 断开连接", user_id)

    async def push_to_user(self, user_id: int, payload: dict) -> None:
        """向指定用户的所有在线连接推送轻量事件"""
        async with self._lock:
            sockets = set(self._connections.get(user_id, set()))
        if not sockets:
            return
        dead: list[WebSocket] = []
        for ws in sockets:
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        if dead:
            async with self._lock:
                for ws in dead:
                    self._connections[user_id].discard(ws)

    def online_user_ids(self) -> list[int]:
        return list(self._connections.keys())


# 全局单例
message_connection_manager = MessageConnectionManager()

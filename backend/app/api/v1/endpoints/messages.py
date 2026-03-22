from __future__ import annotations

import logging
from datetime import datetime

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, require_permission
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.message import (
    AnnouncementPublishRequest,
    AnnouncementPublishResult,
    MessageBatchReadRequest,
    MessageListResult,
    MessageSummaryResult,
    UnreadCountResult,
)
from app.services.audit_service import write_audit_log
from app.services.message_connection_manager import message_connection_manager
from app.services.message_service import (
    get_message_summary,
    get_unread_count,
    list_messages,
    mark_all_read,
    mark_messages_read_batch,
    mark_message_read,
    publish_announcement,
)
from app.services.user_service import get_user_by_id

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/unread-count", response_model=ApiResponse[UnreadCountResult])
def api_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("message.messages.unread_count")),
) -> ApiResponse[UnreadCountResult]:
    count = get_unread_count(db, user_id=current_user.id)
    return success_response(UnreadCountResult(unread_count=count))


@router.get("/summary", response_model=ApiResponse[MessageSummaryResult])
def api_message_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("message.messages.unread_count")),
) -> ApiResponse[MessageSummaryResult]:
    payload = get_message_summary(db, user_id=current_user.id)
    return success_response(MessageSummaryResult(**payload))


@router.get("", response_model=ApiResponse[MessageListResult])
def api_list_messages(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    keyword: str | None = Query(None),
    status: str | None = Query(None),
    message_type: str | None = Query(None),
    priority: str | None = Query(None),
    source_module: str | None = Query(None),
    start_time: datetime | None = Query(None),
    end_time: datetime | None = Query(None),
    todo_only: bool = Query(False),
    active_only: bool = Query(True),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("message.messages.list")),
) -> ApiResponse[MessageListResult]:
    items, total = list_messages(
        db,
        user_id=current_user.id,
        current_user=current_user,
        page=page,
        page_size=page_size,
        keyword=keyword,
        status=status,
        message_type=message_type,
        priority=priority,
        source_module=source_module,
        start_time=start_time,
        end_time=end_time,
        todo_only=todo_only,
        active_only=active_only,
    )
    return success_response(
        MessageListResult(items=items, total=total, page=page, page_size=page_size)
    )


@router.post("/{message_id}/read", response_model=ApiResponse[dict])
def api_mark_read(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("message.messages.read")),
) -> ApiResponse[dict]:
    ok = mark_message_read(db, user_id=current_user.id, message_id=message_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="消息不存在或无权访问"
        )
    write_audit_log(
        db,
        action_code="message.mark_read",
        action_name="标记消息已读",
        target_type="message",
        target_id=str(message_id),
        operator=current_user,
    )
    db.commit()
    unread_count = get_unread_count(db, user_id=current_user.id)
    try:
        import asyncio

        from app.services.message_push_service import push_message_read_state_changed

        loop = asyncio.get_running_loop()
        loop.create_task(
            push_message_read_state_changed(
                current_user.id,
                message_id=message_id,
                unread_count=unread_count,
                is_read=True,
            )
        )
    except RuntimeError:
        pass
    return success_response({})


@router.post("/read-all", response_model=ApiResponse[dict])
def api_mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("message.messages.read_all")),
) -> ApiResponse[dict]:
    count = mark_all_read(db, user_id=current_user.id)
    write_audit_log(
        db,
        action_code="message.mark_all_read",
        action_name="全部标记已读",
        target_type="message",
        operator=current_user,
        remark=f"共标记 {count} 条",
    )
    db.commit()
    unread_count = get_unread_count(db, user_id=current_user.id)
    try:
        import asyncio

        from app.services.message_push_service import push_message_read_state_changed

        loop = asyncio.get_running_loop()
        loop.create_task(
            push_message_read_state_changed(
                current_user.id,
                message_id=None,
                unread_count=unread_count,
                is_read=True,
            )
        )
    except RuntimeError:
        pass
    return success_response({"updated": count})


@router.post("/read-batch", response_model=ApiResponse[dict])
def api_mark_batch_read(
    payload: MessageBatchReadRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("message.messages.read_all")),
) -> ApiResponse[dict]:
    count = mark_messages_read_batch(
        db,
        user_id=current_user.id,
        message_ids=payload.message_ids,
    )
    write_audit_log(
        db,
        action_code="message.mark_batch_read",
        action_name="批量标记消息已读",
        target_type="message",
        operator=current_user,
        remark=f"共标记 {count} 条",
    )
    db.commit()
    unread_count = get_unread_count(db, user_id=current_user.id)
    try:
        import asyncio

        from app.services.message_push_service import push_message_read_state_changed

        loop = asyncio.get_running_loop()
        loop.create_task(
            push_message_read_state_changed(
                current_user.id,
                message_id=None,
                unread_count=unread_count,
                is_read=True,
            )
        )
    except RuntimeError:
        pass
    return success_response({"updated": count})


@router.post(
    "/announcements",
    response_model=ApiResponse[AnnouncementPublishResult],
)
def api_publish_announcement(
    payload: AnnouncementPublishRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("message.announcements.publish")),
) -> ApiResponse[AnnouncementPublishResult]:
    try:
        result = publish_announcement(db, req=payload, operator=current_user)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    write_audit_log(
        db,
        action_code="message.announcements.publish",
        action_name="发布站内公告",
        target_type="message",
        target_id=str(result.message_id),
        target_name=payload.title.strip(),
        operator=current_user,
        after_data={
            "message_id": result.message_id,
            "priority": payload.priority,
            "range_type": payload.range_type,
            "role_codes": payload.role_codes,
            "user_ids": payload.user_ids,
            "expires_at": payload.expires_at.isoformat()
            if payload.expires_at is not None
            else None,
            "recipient_count": result.recipient_count,
        },
    )
    db.commit()
    return success_response(result)


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)) -> None:
    """WebSocket 实时消息推送端点，通过 token 鉴权"""
    # 鉴权
    user_id: int | None = None
    try:
        payload = decode_access_token(token)
        sub = str(payload.get("sub", "")).strip()
        if sub:
            user_id = int(sub)
    except Exception:
        await websocket.close(code=4001)
        return

    if user_id is None:
        await websocket.close(code=4001)
        return

    # 简单验证用户是否存在（不依赖 db session 长连接）
    from app.db.session import SessionLocal

    with SessionLocal() as db:
        user = get_user_by_id(db, user_id)
        if user is None or user.is_deleted or not user.is_active:
            await websocket.close(code=4003)
            return

    await message_connection_manager.connect(websocket, user_id)
    try:
        # 连接成功后推送当前未读数
        with SessionLocal() as db:
            count = get_unread_count(db, user_id=user_id)
        await websocket.send_json(
            {
                "event": "connected",
                "user_id": user_id,
                "unread_count": count,
            }
        )
        # 保持连接，等待客户端断开
        while True:
            data = await websocket.receive_text()
            # 客户端可发送 ping，服务端回 pong
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception("[MSG_WS] 用户 %s WebSocket 异常", user_id)
    finally:
        await message_connection_manager.disconnect(websocket, user_id)

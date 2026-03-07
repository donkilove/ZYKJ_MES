from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.production_constants import ORDER_STATUS_COMPLETED, PROCESS_STATUS_COMPLETED
from app.core.rbac import ROLE_PRODUCTION_ADMIN
from app.models.production_assist_authorization import ProductionAssistAuthorization
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_sub_order import ProductionSubOrder
from app.models.user import User
from app.services.production_event_log_service import add_order_event_log

ASSIST_STATUS_PENDING = "pending"
ASSIST_STATUS_APPROVED = "approved"
ASSIST_STATUS_REJECTED = "rejected"
ASSIST_STATUS_CONSUMED = "consumed"
ASSIST_STATUS_ALL = {
    ASSIST_STATUS_PENDING,
    ASSIST_STATUS_APPROVED,
    ASSIST_STATUS_REJECTED,
    ASSIST_STATUS_CONSUMED,
}

ASSIST_OP_FIRST_ARTICLE = "first_article"
ASSIST_OP_END_PRODUCTION = "end_production"


def _has_role(user: User, role_code: str) -> bool:
    return any(role.code == role_code for role in user.roles)


def _get_order_and_process_for_update(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
) -> tuple[ProductionOrder, ProductionOrderProcess]:
    order = (
        db.execute(
            select(ProductionOrder)
            .where(ProductionOrder.id == order_id)
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if not order:
        raise ValueError("Order not found")
    process_row = (
        db.execute(
            select(ProductionOrderProcess)
            .where(
                ProductionOrderProcess.id == order_process_id,
                ProductionOrderProcess.order_id == order_id,
            )
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if not process_row:
        raise ValueError("Order process not found")
    return order, process_row


def _ensure_target_sub_order_exists(
    db: Session,
    *,
    order_process_id: int,
    target_operator_user_id: int,
) -> None:
    row = (
        db.execute(
            select(ProductionSubOrder).where(
                ProductionSubOrder.order_process_id == order_process_id,
                ProductionSubOrder.operator_user_id == target_operator_user_id,
            )
        )
        .scalars()
        .first()
    )
    if row is None:
        raise ValueError("Target operator sub-order assignment not found")


def create_assist_authorization(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    target_operator_user_id: int,
    helper_user_id: int,
    reason: str | None,
    requester: User,
) -> ProductionAssistAuthorization:
    order, process_row = _get_order_and_process_for_update(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    if order.status == ORDER_STATUS_COMPLETED:
        raise ValueError("Order already completed")
    if process_row.status == PROCESS_STATUS_COMPLETED:
        raise ValueError("Current process already completed")

    helper = db.get(User, helper_user_id)
    if helper is None or not helper.is_active:
        raise ValueError("Helper user not found or inactive")

    target_operator = db.get(User, target_operator_user_id)
    if target_operator is None or not target_operator.is_active:
        raise ValueError("Target operator not found or inactive")

    _ensure_target_sub_order_exists(
        db,
        order_process_id=order_process_id,
        target_operator_user_id=target_operator_user_id,
    )

    duplicate = (
        db.execute(
            select(ProductionAssistAuthorization).where(
                ProductionAssistAuthorization.order_id == order_id,
                ProductionAssistAuthorization.order_process_id == order_process_id,
                ProductionAssistAuthorization.target_operator_user_id == target_operator_user_id,
                ProductionAssistAuthorization.requester_user_id == requester.id,
                ProductionAssistAuthorization.status == ASSIST_STATUS_PENDING,
            )
        )
        .scalars()
        .first()
    )
    if duplicate is not None:
        raise RuntimeError("Pending assist authorization already exists")

    row = ProductionAssistAuthorization(
        order_id=order_id,
        order_process_id=order_process_id,
        target_operator_user_id=target_operator_user_id,
        requester_user_id=requester.id,
        helper_user_id=helper_user_id,
        status=ASSIST_STATUS_PENDING,
        reason=(reason or "").strip() or None,
    )
    db.add(row)
    db.flush()

    add_order_event_log(
        db,
        order_id=order.id,
        event_type="assist_authorization_requested",
        event_title="代班申请",
        event_detail=f"{requester.username} 申请 {helper.username} 代班执行 {process_row.process_name}",
        operator_user_id=requester.id,
        payload={
            "assist_authorization_id": row.id,
            "order_process_id": process_row.id,
            "target_operator_user_id": target_operator_user_id,
            "helper_user_id": helper_user_id,
        },
    )
    db.commit()
    db.refresh(row)
    return row


def list_assist_authorizations(
    db: Session,
    *,
    current_user: User,
    page: int,
    page_size: int,
    status: str | None = None,
) -> tuple[int, list[ProductionAssistAuthorization]]:
    stmt = (
        select(ProductionAssistAuthorization)
        .options(
            selectinload(ProductionAssistAuthorization.order),
            selectinload(ProductionAssistAuthorization.order_process),
            selectinload(ProductionAssistAuthorization.requester),
            selectinload(ProductionAssistAuthorization.helper),
            selectinload(ProductionAssistAuthorization.target_operator),
            selectinload(ProductionAssistAuthorization.reviewer),
        )
        .order_by(
            ProductionAssistAuthorization.updated_at.desc(),
            ProductionAssistAuthorization.id.desc(),
        )
    )
    if status:
        if status not in ASSIST_STATUS_ALL:
            raise ValueError("Invalid assist authorization status")
        stmt = stmt.where(ProductionAssistAuthorization.status == status)

    if not _has_role(current_user, ROLE_PRODUCTION_ADMIN):
        stmt = stmt.where(
            or_(
                ProductionAssistAuthorization.requester_user_id == current_user.id,
                ProductionAssistAuthorization.helper_user_id == current_user.id,
            )
        )

    rows = db.execute(stmt).scalars().all()
    total = len(rows)
    offset = (page - 1) * page_size
    return total, rows[offset : offset + page_size]


def review_assist_authorization(
    db: Session,
    *,
    authorization_id: int,
    approve: bool,
    reviewer: User,
    review_remark: str | None,
) -> ProductionAssistAuthorization:
    if not _has_role(reviewer, ROLE_PRODUCTION_ADMIN):
        raise PermissionError("Only production admin can review assist authorization")

    row = (
        db.execute(
            select(ProductionAssistAuthorization)
            .where(ProductionAssistAuthorization.id == authorization_id)
            .with_for_update()
            .options(selectinload(ProductionAssistAuthorization.order_process))
        )
        .scalars()
        .first()
    )
    if row is None:
        raise ValueError("Assist authorization not found")
    if row.status != ASSIST_STATUS_PENDING:
        raise ValueError("Assist authorization is not pending")

    row.status = ASSIST_STATUS_APPROVED if approve else ASSIST_STATUS_REJECTED
    row.reviewer_user_id = reviewer.id
    row.review_remark = (review_remark or "").strip() or None
    row.reviewed_at = datetime.now(timezone.utc)

    process_name = row.order_process.process_name if row.order_process else ""
    add_order_event_log(
        db,
        order_id=row.order_id,
        event_type="assist_authorization_reviewed",
        event_title="代班审批",
        event_detail=(
            f"{reviewer.username} 审批通过代班申请（{process_name}）"
            if approve
            else f"{reviewer.username} 驳回代班申请（{process_name}）"
        ),
        operator_user_id=reviewer.id,
        payload={
            "assist_authorization_id": row.id,
            "approved": approve,
        },
    )

    db.commit()
    db.refresh(row)
    return row


def get_usable_assist_authorization_for_operation(
    db: Session,
    *,
    authorization_id: int,
    order_id: int,
    order_process_id: int,
    target_operator_user_id: int,
    helper_user_id: int,
    operation: str,
) -> ProductionAssistAuthorization:
    row = (
        db.execute(
            select(ProductionAssistAuthorization)
            .where(ProductionAssistAuthorization.id == authorization_id)
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if row is None:
        raise ValueError("Assist authorization not found")
    if row.status != ASSIST_STATUS_APPROVED:
        raise ValueError("Assist authorization is not approved")
    if row.order_id != order_id or row.order_process_id != order_process_id:
        raise ValueError("Assist authorization does not match order process")
    if row.target_operator_user_id != target_operator_user_id:
        raise ValueError("Assist authorization target operator mismatch")
    if row.helper_user_id != helper_user_id:
        raise ValueError("Assist authorization helper mismatch")

    if operation == ASSIST_OP_FIRST_ARTICLE:
        if row.first_article_used_at is not None:
            raise ValueError("First-article assist authorization already used")
        if row.end_production_used_at is not None:
            raise ValueError("Assist authorization already consumed")
    elif operation == ASSIST_OP_END_PRODUCTION:
        if row.end_production_used_at is not None:
            raise ValueError("End-production assist authorization already used")
    else:
        raise ValueError("Unsupported assist operation")
    return row


def mark_assist_authorization_used(
    db: Session,
    *,
    authorization_row: ProductionAssistAuthorization,
    operation: str,
) -> None:
    if operation == ASSIST_OP_FIRST_ARTICLE:
        authorization_row.first_article_used_at = datetime.now(timezone.utc)
        return

    if operation == ASSIST_OP_END_PRODUCTION:
        authorization_row.end_production_used_at = datetime.now(timezone.utc)
        authorization_row.status = ASSIST_STATUS_CONSUMED
        authorization_row.consumed_at = datetime.now(timezone.utc)
        return

    raise ValueError("Unsupported assist operation")

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, require_role_codes
from app.core.production_constants import (
    ORDER_STATUS_ALL,
)
from app.core.rbac import (
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.db.session import get_db
from app.models.order_event_log import OrderEventLog
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.production_sub_order import ProductionSubOrder
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.production import (
    EndProductionRequest,
    FirstArticleRequest,
    MyOrderItem,
    MyOrderListResult,
    OrderActionResult,
    OrderCreate,
    OrderDetail,
    OrderEventLogItem,
    OrderItem,
    OrderListResult,
    OrderUpdate,
    ProductionOperatorStatItem,
    ProductionOperatorStatsResult,
    ProductionOrderProcessItem,
    ProductionProcessStatItem,
    ProductionProcessStatsResult,
    ProductionRecordItem,
    ProductionStatsOverview,
    ProductionSubOrderItem,
)
from app.services.production_execution_service import end_production, submit_first_article
from app.services.production_order_service import (
    complete_order_manually,
    create_order,
    delete_order,
    get_order_by_id,
    list_my_orders,
    list_orders,
    update_order,
)
from app.services.production_statistics_service import (
    get_operator_stats,
    get_overview_stats,
    get_process_stats,
)


router = APIRouter()


def _raise_service_error(error: Exception) -> None:
    message = str(error)
    message_lower = message.lower()
    if isinstance(error, RuntimeError):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=message)
    if "not found" in message_lower:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=message)
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)


def _to_order_item(order: ProductionOrder) -> OrderItem:
    current_process = None
    if order.current_process_code:
        for row in order.processes:
            if row.process_code == order.current_process_code:
                current_process = row
                break
    created_by_username = order.created_by.username if order.created_by else None
    return OrderItem(
        id=order.id,
        order_code=order.order_code,
        product_id=order.product_id,
        product_name=order.product.name if order.product else "",
        quantity=order.quantity,
        status=order.status,
        current_process_code=order.current_process_code,
        current_process_name=current_process.process_name if current_process else None,
        start_date=order.start_date,
        due_date=order.due_date,
        remark=order.remark,
        created_by_user_id=order.created_by_user_id,
        created_by_username=created_by_username,
        created_at=order.created_at,
        updated_at=order.updated_at,
    )


def _to_process_item(row: ProductionOrderProcess) -> ProductionOrderProcessItem:
    return ProductionOrderProcessItem(
        id=row.id,
        process_code=row.process_code,
        process_name=row.process_name,
        process_order=row.process_order,
        status=row.status,
        visible_quantity=row.visible_quantity,
        completed_quantity=row.completed_quantity,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_sub_order_item(row: ProductionSubOrder) -> ProductionSubOrderItem:
    return ProductionSubOrderItem(
        id=row.id,
        order_process_id=row.order_process_id,
        process_code=row.order_process.process_code if row.order_process else "",
        process_name=row.order_process.process_name if row.order_process else "",
        operator_user_id=row.operator_user_id,
        operator_username=row.operator.username if row.operator else "",
        assigned_quantity=row.assigned_quantity,
        completed_quantity=row.completed_quantity,
        status=row.status,
        is_visible=row.is_visible,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_record_item(row: ProductionRecord) -> ProductionRecordItem:
    return ProductionRecordItem(
        id=row.id,
        order_process_id=row.order_process_id,
        process_code=row.order_process.process_code if row.order_process else "",
        process_name=row.order_process.process_name if row.order_process else "",
        operator_user_id=row.operator_user_id,
        operator_username=row.operator.username if row.operator else "",
        production_quantity=row.production_quantity,
        record_type=row.record_type,
        created_at=row.created_at,
    )


def _to_event_item(row: OrderEventLog) -> OrderEventLogItem:
    return OrderEventLogItem(
        id=row.id,
        event_type=row.event_type,
        event_title=row.event_title,
        event_detail=row.event_detail,
        operator_user_id=row.operator_user_id,
        operator_username=row.operator.username if row.operator else None,
        payload_json=row.payload_json,
        created_at=row.created_at,
    )


@router.get(
    "/orders",
    response_model=ApiResponse[OrderListResult],
)
def get_orders(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    keyword: str | None = Query(default=None),
    status_text: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[OrderListResult]:
    if status_text and status_text not in ORDER_STATUS_ALL:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid order status: {status_text}",
        )
    total, rows = list_orders(
        db,
        page=page,
        page_size=page_size,
        keyword=keyword,
        status=status_text,
    )
    return success_response(OrderListResult(total=total, items=[_to_order_item(row) for row in rows]))


@router.post(
    "/orders",
    response_model=ApiResponse[OrderItem],
    status_code=status.HTTP_201_CREATED,
)
def create_order_api(
    payload: OrderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[OrderItem]:
    try:
        row = create_order(
            db,
            order_code=payload.order_code,
            product_id=payload.product_id,
            quantity=payload.quantity,
            start_date=payload.start_date,
            due_date=payload.due_date,
            remark=payload.remark,
            process_codes=payload.process_codes,
            operator=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    row = get_order_by_id(db, row.id, with_relations=True) or row
    return success_response(_to_order_item(row), message="created")


@router.get(
    "/orders/{order_id}",
    response_model=ApiResponse[OrderDetail],
)
def get_order_detail_api(
    order_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_active_user),
) -> ApiResponse[OrderDetail]:
    row = get_order_by_id(db, order_id, with_relations=True)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    process_rows = sorted(row.processes, key=lambda item: (item.process_order, item.id))
    sub_order_rows: list[ProductionSubOrder] = []
    for process_row in process_rows:
        sub_order_rows.extend(process_row.sub_orders)
    sub_order_rows.sort(key=lambda item: (item.order_process.process_order, item.operator_user_id, item.id))

    record_rows = sorted(
        row.production_records,
        key=lambda item: (item.created_at, item.id),
        reverse=True,
    )[:200]
    event_rows = sorted(
        row.event_logs,
        key=lambda item: (item.created_at, item.id),
        reverse=True,
    )[:200]
    return success_response(
        OrderDetail(
            order=_to_order_item(row),
            processes=[_to_process_item(item) for item in process_rows],
            sub_orders=[_to_sub_order_item(item) for item in sub_order_rows],
            records=[_to_record_item(item) for item in record_rows],
            events=[_to_event_item(item) for item in event_rows],
        )
    )


@router.put(
    "/orders/{order_id}",
    response_model=ApiResponse[OrderItem],
)
def update_order_api(
    order_id: int,
    payload: OrderUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[OrderItem]:
    order = get_order_by_id(db, order_id, with_relations=False)
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    try:
        row = update_order(
            db,
            order=order,
            product_id=payload.product_id,
            quantity=payload.quantity,
            start_date=payload.start_date,
            due_date=payload.due_date,
            remark=payload.remark,
            process_codes=payload.process_codes,
            operator=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    row = get_order_by_id(db, row.id, with_relations=True) or row
    return success_response(_to_order_item(row), message="updated")


@router.delete(
    "/orders/{order_id}",
    response_model=ApiResponse[dict[str, bool]],
)
def delete_order_api(
    order_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[dict[str, bool]]:
    order = get_order_by_id(db, order_id, with_relations=False)
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    try:
        delete_order(db, order=order)
    except Exception as error:
        _raise_service_error(error)
    return success_response({"deleted": True}, message="deleted")


@router.post(
    "/orders/{order_id}/complete",
    response_model=ApiResponse[OrderActionResult],
)
def complete_order_api(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[OrderActionResult]:
    order = get_order_by_id(db, order_id, with_relations=True)
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    try:
        row = complete_order_manually(db, order=order, operator=current_user)
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        OrderActionResult(order_id=row.id, status=row.status, message="Order completed"),
        message="completed",
    )


@router.get(
    "/my-orders",
    response_model=ApiResponse[MyOrderListResult],
)
def get_my_orders_api(
    keyword: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=30, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN, ROLE_OPERATOR])
    ),
) -> ApiResponse[MyOrderListResult]:
    total, items = list_my_orders(
        db,
        current_user=current_user,
        keyword=keyword,
        page=page,
        page_size=page_size,
    )
    return success_response(
        MyOrderListResult(
            total=total,
            items=[MyOrderItem(**item) for item in items],
        )
    )


@router.post(
    "/orders/{order_id}/first-article",
    response_model=ApiResponse[OrderActionResult],
)
def submit_first_article_api(
    order_id: int,
    payload: FirstArticleRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_OPERATOR])),
) -> ApiResponse[OrderActionResult]:
    try:
        row, _, _ = submit_first_article(
            db,
            order_id=order_id,
            order_process_id=payload.order_process_id,
            verification_code=payload.verification_code,
            remark=payload.remark,
            operator=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        OrderActionResult(
            order_id=row.id,
            status=row.status,
            message="First article submitted",
        ),
        message="first_article_submitted",
    )


@router.post(
    "/orders/{order_id}/end-production",
    response_model=ApiResponse[OrderActionResult],
)
def end_production_api(
    order_id: int,
    payload: EndProductionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_OPERATOR])),
) -> ApiResponse[OrderActionResult]:
    try:
        row, _, _ = end_production(
            db,
            order_id=order_id,
            order_process_id=payload.order_process_id,
            quantity=payload.quantity,
            remark=payload.remark,
            operator=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        OrderActionResult(
            order_id=row.id,
            status=row.status,
            message="Production reported",
        ),
        message="production_reported",
    )


@router.get(
    "/stats/overview",
    response_model=ApiResponse[ProductionStatsOverview],
)
def get_overview_stats_api(
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN])),
) -> ApiResponse[ProductionStatsOverview]:
    payload = get_overview_stats(db)
    return success_response(ProductionStatsOverview(**payload))


@router.get(
    "/stats/processes",
    response_model=ApiResponse[ProductionProcessStatsResult],
)
def get_process_stats_api(
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN])),
) -> ApiResponse[ProductionProcessStatsResult]:
    rows = get_process_stats(db)
    return success_response(ProductionProcessStatsResult(items=[ProductionProcessStatItem(**row) for row in rows]))


@router.get(
    "/stats/operators",
    response_model=ApiResponse[ProductionOperatorStatsResult],
)
def get_operator_stats_api(
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN])),
) -> ApiResponse[ProductionOperatorStatsResult]:
    rows = get_operator_stats(db)
    return success_response(
        ProductionOperatorStatsResult(items=[ProductionOperatorStatItem(**row) for row in rows])
    )

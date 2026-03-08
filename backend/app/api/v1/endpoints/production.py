from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
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
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.production_sub_order import ProductionSubOrder
from app.models.repair_order import RepairOrder
from app.models.role import Role
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.production import (
    AssistAuthorizationCreateRequest,
    AssistAuthorizationItem,
    AssistAuthorizationListResult,
    AssistAuthorizationReviewRequest,
    AssistUserOptionItem,
    AssistUserOptionListResult,
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
    OrderPipelineModeItem,
    OrderPipelineModeUpdateRequest,
    OrderUpdate,
    ProductionOperatorStatItem,
    ProductionOperatorStatsResult,
    ProductionDataManualExportRequest,
    ProductionDataManualExportResult,
    ProductionExportResult,
    ProductionDataManualResult,
    ProductionDataTodayRealtimeResult,
    ProductionDataUnfinishedProgressResult,
    RepairOrderCompleteRequest,
    RepairOrderCreateRequest,
    RepairOrderItem,
    RepairOrderListResult,
    RepairOrderPhenomenaSummaryResult,
    RepairOrderPhenomenonSummaryItem,
    RepairOrdersExportRequest,
    ScrapStatisticsExportRequest,
    ScrapStatisticsItem,
    ScrapStatisticsListResult,
    ProductionOrderProcessItem,
    ProductionProcessStatItem,
    ProductionProcessStatsResult,
    ProductionRecordItem,
    ProductionStatsOverview,
    ProductionSubOrderItem,
)
from app.services.assist_authorization_service import create_assist_authorization, list_assist_authorizations, review_assist_authorization
from app.services.production_execution_service import end_production, submit_first_article
from app.services.production_order_service import (
    can_user_access_order_pipeline_mode,
    complete_order_manually,
    create_order,
    get_order_pipeline_mode,
    delete_order,
    get_order_by_id,
    list_my_orders,
    list_orders,
    update_order_pipeline_mode,
    update_order,
)
from app.services.production_data_query_service import (
    build_manual_filters,
    build_today_filters,
    export_manual_production_data_csv,
    get_manual_production_data,
    get_today_realtime_data,
    get_unfinished_progress_data,
    parse_id_list_param,
)
from app.services.production_repair_service import (
    RepairListFilters,
    ScrapStatisticsFilters,
    complete_repair_order,
    create_manual_repair_order,
    export_repair_orders_csv,
    export_scrap_statistics_csv,
    get_repair_order_by_id,
    get_repair_order_phenomena_summary,
    list_repair_orders,
    list_scrap_statistics,
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
    if isinstance(error, PermissionError):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=message)
    if isinstance(error, RuntimeError):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=message)
    if "not found" in message_lower:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=message)
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)


def _parse_id_list_query(raw_value: str | None) -> list[int]:
    try:
        return parse_id_list_param(raw_value)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error


def _to_order_item(order: ProductionOrder) -> OrderItem:
    current_process = None
    if order.processes:
        process_rows = sorted(order.processes, key=lambda row: (row.process_order, row.id))
        current_process = next((row for row in process_rows if row.status != "completed"), None)
        if current_process is None and order.current_process_code:
            current_process = next(
                (row for row in process_rows if row.process_code == order.current_process_code),
                None,
            )
    created_by_username = order.created_by.username if order.created_by else None
    pipeline_process_codes = [
        item.strip()
        for item in (order.pipeline_process_codes or "").split(",")
        if item and item.strip()
    ]
    return OrderItem(
        id=order.id,
        order_code=order.order_code,
        product_id=order.product_id,
        product_name=order.product.name if order.product else "",
        product_version=order.product_version,
        quantity=order.quantity,
        status=order.status,
        current_process_code=order.current_process_code,
        current_process_name=current_process.process_name if current_process else None,
        start_date=order.start_date,
        due_date=order.due_date,
        remark=order.remark,
        process_template_id=order.process_template_id,
        process_template_name=order.process_template_name,
        process_template_version=order.process_template_version,
        pipeline_enabled=bool(order.pipeline_enabled),
        pipeline_process_codes=pipeline_process_codes if order.pipeline_enabled else [],
        created_by_user_id=order.created_by_user_id,
        created_by_username=created_by_username,
        created_at=order.created_at,
        updated_at=order.updated_at,
    )


def _to_process_item(row: ProductionOrderProcess) -> ProductionOrderProcessItem:
    return ProductionOrderProcessItem(
        id=row.id,
        stage_id=row.stage_id,
        stage_code=row.stage_code,
        stage_name=row.stage_name,
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


def _to_assist_authorization_item(row) -> AssistAuthorizationItem:
    return AssistAuthorizationItem(
        id=row.id,
        order_id=row.order_id,
        order_code=row.order.order_code if row.order else "",
        order_process_id=row.order_process_id,
        process_code=row.order_process.process_code if row.order_process else "",
        process_name=row.order_process.process_name if row.order_process else "",
        target_operator_user_id=row.target_operator_user_id,
        target_operator_username=row.target_operator.username if row.target_operator else "",
        requester_user_id=row.requester_user_id,
        requester_username=row.requester.username if row.requester else "",
        helper_user_id=row.helper_user_id,
        helper_username=row.helper.username if row.helper else "",
        status=row.status,
        reason=row.reason,
        review_remark=row.review_remark,
        reviewer_user_id=row.reviewer_user_id,
        reviewer_username=row.reviewer.username if row.reviewer else None,
        reviewed_at=row.reviewed_at,
        first_article_used_at=row.first_article_used_at,
        end_production_used_at=row.end_production_used_at,
        consumed_at=row.consumed_at,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_assist_user_option_item(user: User) -> AssistUserOptionItem:
    return AssistUserOptionItem(
        id=user.id,
        username=user.username,
        full_name=user.full_name,
        role_codes=sorted(role.code for role in user.roles),
    )


def _to_order_pipeline_mode_item(payload: dict[str, object]) -> OrderPipelineModeItem:
    return OrderPipelineModeItem(
        order_id=int(payload.get("order_id") or 0),
        enabled=bool(payload.get("enabled")),
        process_codes=[str(code) for code in payload.get("process_codes") or []],
        available_process_codes=[str(code) for code in payload.get("available_process_codes") or []],
    )


def _to_repair_order_item(row: RepairOrder) -> RepairOrderItem:
    return RepairOrderItem(
        id=row.id,
        repair_order_code=row.repair_order_code,
        source_order_id=row.source_order_id,
        source_order_code=row.source_order_code,
        product_id=row.product_id,
        product_name=row.product_name,
        source_order_process_id=row.source_order_process_id,
        source_process_code=row.source_process_code,
        source_process_name=row.source_process_name,
        sender_user_id=row.sender_user_id,
        sender_username=row.sender_username,
        production_quantity=row.production_quantity,
        repair_quantity=row.repair_quantity,
        repaired_quantity=row.repaired_quantity,
        scrap_quantity=row.scrap_quantity,
        scrap_replenished=row.scrap_replenished,
        repair_time=row.repair_time,
        status=row.status,
        completed_at=row.completed_at,
        repair_operator_user_id=row.repair_operator_user_id,
        repair_operator_username=row.repair_operator_username,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_scrap_statistics_item(row: ProductionScrapStatistics) -> ScrapStatisticsItem:
    return ScrapStatisticsItem(
        id=row.id,
        order_id=row.order_id,
        order_code=row.order_code,
        product_id=row.product_id,
        product_name=row.product_name,
        process_id=row.process_id,
        process_code=row.process_code,
        process_name=row.process_name,
        scrap_reason=row.scrap_reason,
        scrap_quantity=row.scrap_quantity,
        last_scrap_time=row.last_scrap_time,
        progress=row.progress,
        applied_at=row.applied_at,
        created_at=row.created_at,
        updated_at=row.updated_at,
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
            template_id=payload.template_id,
            process_steps=[item.model_dump() for item in payload.process_steps] if payload.process_steps else None,
            save_as_template=payload.save_as_template,
            new_template_name=payload.new_template_name,
            new_template_set_default=payload.new_template_set_default,
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


@router.get(
    "/orders/{order_id}/pipeline-mode",
    response_model=ApiResponse[OrderPipelineModeItem],
)
def get_order_pipeline_mode_api(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_OPERATOR])),
) -> ApiResponse[OrderPipelineModeItem]:
    try:
        if not can_user_access_order_pipeline_mode(db, order_id=order_id, current_user=current_user):
            raise PermissionError("Current user has no access to this order pipeline mode")
        payload = get_order_pipeline_mode(db, order_id=order_id)
    except Exception as error:
        _raise_service_error(error)
    return success_response(_to_order_pipeline_mode_item(payload))


@router.put(
    "/orders/{order_id}/pipeline-mode",
    response_model=ApiResponse[OrderPipelineModeItem],
)
def update_order_pipeline_mode_api(
    order_id: int,
    payload: OrderPipelineModeUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[OrderPipelineModeItem]:
    try:
        updated = update_order_pipeline_mode(
            db,
            order_id=order_id,
            enabled=payload.enabled,
            process_codes=payload.process_codes,
            operator=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(_to_order_pipeline_mode_item(updated), message="updated")


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
            template_id=payload.template_id,
            process_steps=[item.model_dump() for item in payload.process_steps] if payload.process_steps else None,
            save_as_template=payload.save_as_template,
            new_template_name=payload.new_template_name,
            new_template_set_default=payload.new_template_set_default,
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
    view_mode: str = "own",
    proxy_operator_user_id: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN, ROLE_OPERATOR])
    ),
) -> ApiResponse[MyOrderListResult]:
    if proxy_operator_user_id is not None and proxy_operator_user_id <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="proxy_operator_user_id must be > 0")
    try:
        total, items = list_my_orders(
            db,
            current_user=current_user,
            keyword=keyword,
            page=page,
            page_size=page_size,
            view_mode=view_mode,
            proxy_operator_user_id=proxy_operator_user_id,
        )
    except Exception as error:
        _raise_service_error(error)
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
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_OPERATOR])),
) -> ApiResponse[OrderActionResult]:
    try:
        row, _, _ = submit_first_article(
            db,
            order_id=order_id,
            order_process_id=payload.order_process_id,
            verification_code=payload.verification_code,
            remark=payload.remark,
            operator=current_user,
            effective_operator_user_id=payload.effective_operator_user_id,
            assist_authorization_id=payload.assist_authorization_id,
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
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_OPERATOR])),
) -> ApiResponse[OrderActionResult]:
    try:
        row, _, _ = end_production(
            db,
            order_id=order_id,
            order_process_id=payload.order_process_id,
            quantity=payload.quantity,
            remark=payload.remark,
            operator=current_user,
            effective_operator_user_id=payload.effective_operator_user_id,
            assist_authorization_id=payload.assist_authorization_id,
            defect_items=[item.model_dump() for item in payload.defect_items] if payload.defect_items else None,
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


@router.get(
    "/data/today-realtime",
    response_model=ApiResponse[ProductionDataTodayRealtimeResult],
)
def get_today_realtime_data_api(
    stat_mode: str = Query(default="main_order"),
    product_ids: str | None = Query(default=None),
    stage_ids: str | None = Query(default=None),
    process_ids: str | None = Query(default=None),
    operator_user_ids: str | None = Query(default=None),
    order_status: str | None = Query(default="all"),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN])),
) -> ApiResponse[ProductionDataTodayRealtimeResult]:
    try:
        filters = build_today_filters(
            stat_mode=stat_mode,
            product_ids=_parse_id_list_query(product_ids),
            stage_ids=_parse_id_list_query(stage_ids),
            process_ids=_parse_id_list_query(process_ids),
            operator_user_ids=_parse_id_list_query(operator_user_ids),
            order_status=order_status,
        )
        payload = get_today_realtime_data(db, filters=filters)
    except Exception as error:
        _raise_service_error(error)
    return success_response(ProductionDataTodayRealtimeResult(**payload))


@router.get(
    "/data/unfinished-progress",
    response_model=ApiResponse[ProductionDataUnfinishedProgressResult],
)
def get_unfinished_progress_data_api(
    product_ids: str | None = Query(default=None),
    stage_ids: str | None = Query(default=None),
    process_ids: str | None = Query(default=None),
    operator_user_ids: str | None = Query(default=None),
    order_status: str | None = Query(default="all"),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN])),
) -> ApiResponse[ProductionDataUnfinishedProgressResult]:
    try:
        payload = get_unfinished_progress_data(
            db,
            product_ids=_parse_id_list_query(product_ids),
            stage_ids=_parse_id_list_query(stage_ids),
            process_ids=_parse_id_list_query(process_ids),
            operator_user_ids=_parse_id_list_query(operator_user_ids),
            order_status=order_status,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(ProductionDataUnfinishedProgressResult(**payload))


@router.get(
    "/data/manual",
    response_model=ApiResponse[ProductionDataManualResult],
)
def get_manual_production_data_api(
    stat_mode: str = Query(default="main_order"),
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    product_ids: str | None = Query(default=None),
    stage_ids: str | None = Query(default=None),
    process_ids: str | None = Query(default=None),
    operator_user_ids: str | None = Query(default=None),
    order_status: str | None = Query(default="all"),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN])),
) -> ApiResponse[ProductionDataManualResult]:
    try:
        filters = build_manual_filters(
            stat_mode=stat_mode,
            start_date=start_date,
            end_date=end_date,
            product_ids=_parse_id_list_query(product_ids),
            stage_ids=_parse_id_list_query(stage_ids),
            process_ids=_parse_id_list_query(process_ids),
            operator_user_ids=_parse_id_list_query(operator_user_ids),
            order_status=order_status,
        )
        payload = get_manual_production_data(db, filters=filters)
    except Exception as error:
        _raise_service_error(error)
    return success_response(ProductionDataManualResult(**payload))


@router.post(
    "/data/manual/export",
    response_model=ApiResponse[ProductionDataManualExportResult],
)
def export_manual_production_data_api(
    payload: ProductionDataManualExportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[ProductionDataManualExportResult]:
    try:
        filters = build_manual_filters(
            stat_mode=payload.stat_mode,
            start_date=payload.start_date,
            end_date=payload.end_date,
            product_ids=payload.product_ids,
            stage_ids=payload.stage_ids,
            process_ids=payload.process_ids,
            operator_user_ids=payload.operator_user_ids,
            order_status=payload.order_status,
        )
        data = export_manual_production_data_csv(
            db,
            filters=filters,
            operator=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(ProductionDataManualExportResult(**data))


@router.get(
    "/scrap-statistics",
    response_model=ApiResponse[ScrapStatisticsListResult],
)
def get_scrap_statistics_api(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=500),
    keyword: str | None = Query(default=None),
    progress: str | None = Query(default="all"),
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN])),
) -> ApiResponse[ScrapStatisticsListResult]:
    try:
        total, rows = list_scrap_statistics(
            db,
            page=page,
            page_size=page_size,
            filters=ScrapStatisticsFilters(
                keyword=keyword,
                progress=progress,
                start_date=start_date,
                end_date=end_date,
            ),
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        ScrapStatisticsListResult(
            total=total,
            items=[_to_scrap_statistics_item(row) for row in rows],
        )
    )


@router.post(
    "/scrap-statistics/export",
    response_model=ApiResponse[ProductionExportResult],
)
def export_scrap_statistics_api(
    payload: ScrapStatisticsExportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[ProductionExportResult]:
    try:
        result = export_scrap_statistics_csv(
            db,
            filters=ScrapStatisticsFilters(
                keyword=payload.keyword,
                progress=payload.progress,
                start_date=payload.start_date,
                end_date=payload.end_date,
            ),
            operator=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(ProductionExportResult(**result))


@router.get(
    "/repair-orders",
    response_model=ApiResponse[RepairOrderListResult],
)
def get_repair_orders_api(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=500),
    keyword: str | None = Query(default=None),
    status_text: str | None = Query(default="all", alias="status"),
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN])),
) -> ApiResponse[RepairOrderListResult]:
    try:
        total, rows = list_repair_orders(
            db,
            page=page,
            page_size=page_size,
            filters=RepairListFilters(
                keyword=keyword,
                status=status_text,
                start_date=start_date,
                end_date=end_date,
            ),
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        RepairOrderListResult(
            total=total,
            items=[_to_repair_order_item(row) for row in rows],
        )
    )


@router.post(
    "/orders/{order_id}/repair-orders",
    response_model=ApiResponse[RepairOrderItem],
    status_code=status.HTTP_201_CREATED,
)
def create_manual_repair_order_api(
    order_id: int,
    payload: RepairOrderCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_OPERATOR])),
) -> ApiResponse[RepairOrderItem]:
    try:
        row = create_manual_repair_order(
            db,
            order_id=order_id,
            order_process_id=payload.order_process_id,
            production_quantity=payload.production_quantity,
            defect_items=[item.model_dump() for item in payload.defect_items],
            sender=current_user,
        )
        db.commit()
        db.refresh(row)
    except Exception as error:
        db.rollback()
        _raise_service_error(error)
    return success_response(_to_repair_order_item(row), message="created")


@router.get(
    "/repair-orders/{repair_order_id}/phenomena-summary",
    response_model=ApiResponse[RepairOrderPhenomenaSummaryResult],
)
def get_repair_order_phenomena_summary_api(
    repair_order_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_QUALITY_ADMIN])),
) -> ApiResponse[RepairOrderPhenomenaSummaryResult]:
    try:
        repair_row = get_repair_order_by_id(db, repair_order_id=repair_order_id)
        if repair_row is None:
            raise ValueError("Repair order not found")
        rows = get_repair_order_phenomena_summary(
            db,
            repair_order_id=repair_order_id,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        RepairOrderPhenomenaSummaryResult(
            repair_order_id=repair_order_id,
            items=[RepairOrderPhenomenonSummaryItem(**item) for item in rows],
        )
    )


@router.post(
    "/repair-orders/{repair_order_id}/complete",
    response_model=ApiResponse[RepairOrderItem],
)
def complete_repair_order_api(
    repair_order_id: int,
    payload: RepairOrderCompleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[RepairOrderItem]:
    try:
        row = complete_repair_order(
            db,
            repair_order_id=repair_order_id,
            cause_items=[item.model_dump() for item in payload.cause_items],
            scrap_replenished=payload.scrap_replenished,
            return_allocations=[item.model_dump() for item in payload.return_allocations],
            operator=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(_to_repair_order_item(row), message="completed")


@router.post(
    "/repair-orders/export",
    response_model=ApiResponse[ProductionExportResult],
)
def export_repair_orders_api(
    payload: RepairOrdersExportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[ProductionExportResult]:
    try:
        result = export_repair_orders_csv(
            db,
            filters=RepairListFilters(
                keyword=payload.keyword,
                status=payload.status,
                start_date=payload.start_date,
                end_date=payload.end_date,
            ),
            operator=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(ProductionExportResult(**result))


@router.get(
    "/assist-authorizations",
    response_model=ApiResponse[AssistAuthorizationListResult],
)
def get_assist_authorizations_api(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    status_text: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_OPERATOR])),
) -> ApiResponse[AssistAuthorizationListResult]:
    try:
        total, rows = list_assist_authorizations(
            db,
            current_user=current_user,
            page=page,
            page_size=page_size,
            status=status_text,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        AssistAuthorizationListResult(
            total=total,
            items=[_to_assist_authorization_item(row) for row in rows],
        )
    )


@router.post(
    "/orders/{order_id}/assist-authorizations",
    response_model=ApiResponse[AssistAuthorizationItem],
    status_code=status.HTTP_201_CREATED,
)
def create_assist_authorization_api(
    order_id: int,
    payload: AssistAuthorizationCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_OPERATOR])),
) -> ApiResponse[AssistAuthorizationItem]:
    try:
        row = create_assist_authorization(
            db,
            order_id=order_id,
            order_process_id=payload.order_process_id,
            target_operator_user_id=payload.target_operator_user_id,
            helper_user_id=payload.helper_user_id,
            reason=payload.reason,
            requester=current_user,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        _to_assist_authorization_item(row),
        message="created",
    )


@router.post(
    "/assist-authorizations/{authorization_id}/review",
    response_model=ApiResponse[AssistAuthorizationItem],
)
def review_assist_authorization_api(
    authorization_id: int,
    payload: AssistAuthorizationReviewRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role_codes([ROLE_PRODUCTION_ADMIN])),
) -> ApiResponse[AssistAuthorizationItem]:
    try:
        row = review_assist_authorization(
            db,
            authorization_id=authorization_id,
            approve=payload.approve,
            reviewer=current_user,
            review_remark=payload.review_remark,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        _to_assist_authorization_item(row),
        message="reviewed",
    )


@router.get(
    "/assist-user-options",
    response_model=ApiResponse[AssistUserOptionListResult],
)
def get_assist_user_options_api(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    keyword: str | None = Query(default=None),
    role_code: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_role_codes([ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN, ROLE_OPERATOR])),
) -> ApiResponse[AssistUserOptionListResult]:
    allowed_role_codes = {
        ROLE_SYSTEM_ADMIN,
        ROLE_PRODUCTION_ADMIN,
        ROLE_OPERATOR,
    }
    if role_code and role_code not in allowed_role_codes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid role_code: {role_code}")

    stmt = (
        select(User)
        .join(User.roles)
        .where(
            User.is_active.is_(True),
            Role.code.in_(allowed_role_codes),
        )
        .order_by(User.id.asc())
        .distinct()
    )
    if role_code:
        stmt = stmt.where(Role.code == role_code)
    if keyword and keyword.strip():
        like_pattern = f"%{keyword.strip()}%"
        stmt = stmt.where(
            or_(
                User.username.ilike(like_pattern),
                User.full_name.ilike(like_pattern),
            )
        )

    rows = db.execute(stmt).scalars().unique().all()
    total = len(rows)
    offset = (page - 1) * page_size
    paged_rows = rows[offset : offset + page_size]
    return success_response(
        AssistUserOptionListResult(
            total=total,
            items=[_to_assist_user_option_item(user) for user in paged_rows],
        )
    )

from __future__ import annotations

from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, load_only, selectinload

from app.api.deps import require_permission, require_permission_fast
from app.core.authz_catalog import (
    PERM_PROD_ASSIST_AUTHORIZATIONS_CREATE,
    PERM_PROD_ASSIST_AUTHORIZATIONS_LIST,
    PERM_PROD_ASSIST_USER_OPTIONS_LIST,
    PERM_PROD_DATA_MANUAL,
    PERM_PROD_DATA_MANUAL_EXPORT,
    PERM_PROD_DATA_TODAY_REALTIME,
    PERM_PROD_DATA_UNFINISHED_PROGRESS,
    PERM_PROD_EXECUTION_END_PRODUCTION,
    PERM_PROD_EXECUTION_FIRST_ARTICLE,
    PERM_PROD_MY_ORDERS_CONTEXT,
    PERM_PROD_MY_ORDERS_EXPORT,
    PERM_PROD_MY_ORDERS_LIST,
    PERM_PROD_ORDERS_COMPLETE,
    PERM_PROD_ORDERS_CREATE,
    PERM_PROD_ORDERS_DELETE,
    PERM_PROD_ORDERS_DETAIL,
    PERM_PROD_ORDERS_EXPORT,
    PERM_PROD_ORDERS_LIST,
    PERM_PROD_ORDERS_PIPELINE_MODE_UPDATE,
    PERM_PROD_ORDERS_PIPELINE_MODE_VIEW,
    PERM_PROD_ORDERS_UPDATE,
    PERM_PROD_PIPELINE_INSTANCES_LIST,
    PERM_PROD_REPAIR_ORDERS_COMPLETE,
    PERM_PROD_REPAIR_ORDERS_CREATE_MANUAL,
    PERM_PROD_REPAIR_ORDERS_DETAIL,
    PERM_PROD_REPAIR_ORDERS_EXPORT,
    PERM_PROD_REPAIR_ORDERS_LIST,
    PERM_PROD_REPAIR_ORDERS_PHENOMENA_SUMMARY,
    PERM_PROD_SCRAP_STATISTICS_DETAIL,
    PERM_PROD_SCRAP_STATISTICS_EXPORT,
    PERM_PROD_SCRAP_STATISTICS_LIST,
    PERM_PROD_STATS_OPERATORS,
    PERM_PROD_STATS_OVERVIEW,
    PERM_PROD_STATS_PROCESSES,
)
from app.core.production_constants import (
    ORDER_STATUS_ALL,
)
from app.core.security import verify_password
from app.core.rbac import (
    ROLE_OPERATOR,
    ROLE_PRODUCTION_ADMIN,
    ROLE_QUALITY_ADMIN,
    ROLE_SYSTEM_ADMIN,
)
from app.db.session import get_db
from app.models.first_article_template import FirstArticleTemplate
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
    AssistUserOptionItem,
    AssistUserOptionListResult,
    CompleteOrderRequest,
    EndProductionRequest,
    FirstArticleParameterItem,
    FirstArticleParameterListResult,
    FirstArticleParticipantOptionItem,
    FirstArticleParticipantOptionListResult,
    FirstArticleRequest,
    FirstArticleTemplateItem,
    FirstArticleTemplateListResult,
    MyOrderContextResult,
    MyOrdersExportRequest,
    MyOrderItem,
    MyOrderListResult,
    OrderActionResult,
    OrderCreate,
    OrderDetail,
    OrderEventLogItem,
    OrderEventLogListResult,
    OrderItem,
    OrderListResult,
    OrderPipelineModeItem,
    OrderPipelineModeUpdateRequest,
    OrdersExportRequest,
    OrderUpdate,
    PipelineInstanceItem,
    PipelineInstanceListResult,
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
    RepairOrderDetailItem,
    RepairOrderItem,
    RepairOrderListResult,
    RepairOrderPhenomenaSummaryResult,
    RepairOrderPhenomenonSummaryItem,
    RepairOrdersExportRequest,
    ScrapStatisticsDetailItem,
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
from app.services.product_service import (
    get_current_revision,
    get_effective_product_parameters,
    get_product_by_id,
    get_product_version_parameters,
)
from app.services.assist_authorization_service import (
    create_assist_authorization,
    list_assist_authorizations,
)
from app.services.production_execution_service import (
    end_production,
    submit_first_article,
)
from app.services.production_order_service import (
    can_user_access_order_detail,
    can_user_access_order_pipeline_mode,
    complete_order_manually,
    export_my_orders_csv,
    create_order,
    export_orders_csv,
    get_my_order_context,
    get_order_pipeline_mode,
    delete_order,
    get_order_by_id,
    list_my_orders,
    list_orders,
    list_pipeline_instances,
    update_order_pipeline_mode,
    update_order,
)
from app.services.production_event_log_service import search_order_event_logs_by_code
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
        ) from error


def _to_order_item(order: ProductionOrder) -> OrderItem:
    current_process = None
    if order.processes:
        process_rows = sorted(
            order.processes, key=lambda row: (row.process_order, row.id)
        )
        current_process = next(
            (row for row in process_rows if row.status != "completed"), None
        )
        if current_process is None and order.current_process_code:
            current_process = next(
                (
                    row
                    for row in process_rows
                    if row.process_code == order.current_process_code
                ),
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
        supplier_id=order.supplier_id,
        supplier_name=order.supplier_name,
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
        order_id=row.order_id,
        order_code=row.order_code_snapshot,
        order_status=row.order_status_snapshot,
        product_name=row.product_name_snapshot,
        process_code=row.process_code_snapshot,
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
        target_operator_username=row.target_operator.username
        if row.target_operator
        else "",
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
        available_process_codes=[
            str(code) for code in payload.get("available_process_codes") or []
        ],
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
    product_name: str | None = Query(default=None),
    pipeline_enabled: bool | None = Query(default=None),
    start_date_from: date | None = Query(default=None),
    start_date_to: date | None = Query(default=None),
    due_date_from: date | None = Query(default=None),
    due_date_to: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_PROD_ORDERS_LIST)),
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
        product_name=product_name,
        pipeline_enabled=pipeline_enabled,
        start_date_from=start_date_from,
        start_date_to=start_date_to,
        due_date_from=due_date_from,
        due_date_to=due_date_to,
    )
    return success_response(
        OrderListResult(total=total, items=[_to_order_item(row) for row in rows])
    )


@router.post(
    "/orders",
    response_model=ApiResponse[OrderItem],
    status_code=status.HTTP_201_CREATED,
)
def create_order_api(
    payload: OrderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_PROD_ORDERS_CREATE)),
) -> ApiResponse[OrderItem]:
    try:
        row = create_order(
            db,
            order_code=payload.order_code,
            product_id=payload.product_id,
            supplier_id=payload.supplier_id,
            quantity=payload.quantity,
            start_date=payload.start_date,
            due_date=payload.due_date,
            remark=payload.remark,
            process_codes=payload.process_codes,
            template_id=payload.template_id,
            process_steps=[item.model_dump() for item in payload.process_steps]
            if payload.process_steps
            else None,
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
    current_user: User = Depends(require_permission(PERM_PROD_ORDERS_DETAIL)),
) -> ApiResponse[OrderDetail]:
    row = get_order_by_id(db, order_id, with_relations=True)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Order not found"
        )
    if not can_user_access_order_detail(
        db, order_id=order_id, current_user=current_user
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Current user has no access to this order",
        )

    process_rows = sorted(row.processes, key=lambda item: (item.process_order, item.id))
    sub_order_rows: list[ProductionSubOrder] = []
    for process_row in process_rows:
        sub_order_rows.extend(process_row.sub_orders)
    sub_order_rows.sort(
        key=lambda item: (
            item.order_process.process_order,
            item.operator_user_id,
            item.id,
        )
    )

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
    current_user: User = Depends(
        require_permission(PERM_PROD_ORDERS_PIPELINE_MODE_VIEW)
    ),
) -> ApiResponse[OrderPipelineModeItem]:
    try:
        if not can_user_access_order_pipeline_mode(
            db, order_id=order_id, current_user=current_user
        ):
            raise PermissionError(
                "Current user has no access to this order pipeline mode"
            )
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
    current_user: User = Depends(
        require_permission(PERM_PROD_ORDERS_PIPELINE_MODE_UPDATE)
    ),
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
    current_user: User = Depends(require_permission(PERM_PROD_ORDERS_UPDATE)),
) -> ApiResponse[OrderItem]:
    order = get_order_by_id(db, order_id, with_relations=False)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Order not found"
        )

    try:
        row = update_order(
            db,
            order=order,
            product_id=payload.product_id,
            supplier_id=payload.supplier_id,
            quantity=payload.quantity,
            start_date=payload.start_date,
            due_date=payload.due_date,
            remark=payload.remark,
            process_codes=payload.process_codes,
            template_id=payload.template_id,
            process_steps=[item.model_dump() for item in payload.process_steps]
            if payload.process_steps
            else None,
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
    current_user: User = Depends(require_permission(PERM_PROD_ORDERS_DELETE)),
) -> ApiResponse[dict[str, bool]]:
    order = get_order_by_id(db, order_id, with_relations=False)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Order not found"
        )
    try:
        delete_order(db, order=order, operator=current_user)
    except Exception as error:
        _raise_service_error(error)
    return success_response({"deleted": True}, message="deleted")


@router.get(
    "/order-events/search",
    response_model=ApiResponse[OrderEventLogListResult],
)
def search_order_events_api(
    order_code: str,
    event_type: str | None = Query(default=None),
    operator_username: str | None = Query(default=None),
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_PROD_ORDERS_DETAIL)),
) -> ApiResponse[OrderEventLogListResult]:
    if start_date is not None and end_date is not None and start_date > end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date cannot be greater than end_date",
        )
    start_time = (
        datetime.combine(start_date, datetime.min.time()) if start_date else None
    )
    end_time = datetime.combine(end_date, datetime.max.time()) if end_date else None
    rows = search_order_event_logs_by_code(
        db,
        order_code=order_code,
        event_type=event_type,
        operator_username=operator_username,
        start_time=start_time,
        end_time=end_time,
    )
    return success_response(
        OrderEventLogListResult(
            total=len(rows),
            items=[_to_event_item(item) for item in rows],
        )
    )


@router.post(
    "/orders/{order_id}/complete",
    response_model=ApiResponse[OrderActionResult],
)
def complete_order_api(
    order_id: int,
    payload: CompleteOrderRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_PROD_ORDERS_COMPLETE)),
) -> ApiResponse[OrderActionResult]:
    order = get_order_by_id(db, order_id, with_relations=True)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Order not found"
        )
    if not verify_password(payload.password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="当前登录密码错误，无法结束订单",
        )
    try:
        row = complete_order_manually(db, order=order, operator=current_user)
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        OrderActionResult(order_id=row.id, status=row.status, message="订单已结束"),
        message="order_completed",
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
    order_status: str | None = Query(default=None),
    current_process_id: int | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_PROD_MY_ORDERS_LIST)),
) -> ApiResponse[MyOrderListResult]:
    normalized_status: str | None = None
    if proxy_operator_user_id is not None and proxy_operator_user_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="proxy_operator_user_id must be > 0",
        )
    if current_process_id is not None and current_process_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="current_process_id must be > 0",
        )
    if order_status is not None:
        token = order_status.strip().lower()
        if token and token != "all":
            if token not in ORDER_STATUS_ALL:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid order status: {order_status}",
                )
            normalized_status = token
    try:
        total, items = list_my_orders(
            db,
            current_user=current_user,
            keyword=keyword,
            page=page,
            page_size=page_size,
            view_mode=view_mode,
            proxy_operator_user_id=proxy_operator_user_id,
            order_status=normalized_status,
            current_process_id=current_process_id,
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
    "/my-orders/export",
    response_model=ApiResponse[ProductionExportResult],
)
def export_my_orders_api(
    payload: MyOrdersExportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_PROD_MY_ORDERS_EXPORT)),
) -> ApiResponse[ProductionExportResult]:
    normalized_status: str | None = None
    if payload.order_status is not None:
        token = payload.order_status.strip().lower()
        if token and token != "all":
            if token not in ORDER_STATUS_ALL:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid order status: {payload.order_status}",
                )
            normalized_status = token
    try:
        result = export_my_orders_csv(
            db,
            current_user=current_user,
            keyword=payload.keyword,
            view_mode=payload.view_mode,
            proxy_operator_user_id=payload.proxy_operator_user_id,
            order_status=normalized_status,
            current_process_id=payload.current_process_id,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(ProductionExportResult(**result))


@router.get(
    "/my-orders/{order_id}/context",
    response_model=ApiResponse[MyOrderContextResult],
)
def get_my_order_context_api(
    order_id: int,
    view_mode: str = "own",
    order_process_id: int | None = None,
    proxy_operator_user_id: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_PROD_MY_ORDERS_CONTEXT)),
) -> ApiResponse[MyOrderContextResult]:
    if proxy_operator_user_id is not None and proxy_operator_user_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="proxy_operator_user_id must be > 0",
        )
    if order_process_id is not None and order_process_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="order_process_id must be > 0",
        )
    try:
        item = get_my_order_context(
            db,
            order_id=order_id,
            order_process_id=order_process_id,
            current_user=current_user,
            view_mode=view_mode,
            proxy_operator_user_id=proxy_operator_user_id,
        )
    except Exception as error:
        _raise_service_error(error)
    if item is None:
        return success_response(MyOrderContextResult(found=False, item=None))
    return success_response(MyOrderContextResult(found=True, item=MyOrderItem(**item)))


def _get_first_article_order_context(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
) -> tuple[ProductionOrder, ProductionOrderProcess]:
    order = db.get(ProductionOrder, order_id)
    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )
    process_row = (
        db.execute(
            select(ProductionOrderProcess).where(
                ProductionOrderProcess.id == order_process_id,
                ProductionOrderProcess.order_id == order_id,
            )
        )
        .scalars()
        .first()
    )
    if process_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order process not found",
        )
    return order, process_row


@router.post(
    "/orders/{order_id}/first-article",
    response_model=ApiResponse[OrderActionResult],
)
def submit_first_article_api(
    order_id: int,
    payload: FirstArticleRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_PROD_EXECUTION_FIRST_ARTICLE)),
) -> ApiResponse[OrderActionResult]:
    try:
        row, _, _ = submit_first_article(
            db,
            order_id=order_id,
            order_process_id=payload.order_process_id,
            pipeline_instance_id=payload.pipeline_instance_id,
            template_id=payload.template_id,
            check_content=payload.check_content,
            test_value=payload.test_value,
            result=payload.result,
            participant_user_ids=payload.participant_user_ids,
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


@router.get(
    "/orders/{order_id}/first-article/templates",
    response_model=ApiResponse[FirstArticleTemplateListResult],
)
def list_first_article_templates_api(
    order_id: int,
    order_process_id: int,
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast(PERM_PROD_EXECUTION_FIRST_ARTICLE)),
) -> ApiResponse[FirstArticleTemplateListResult]:
    order, process_row = _get_first_article_order_context(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    rows = (
        db.execute(
            select(FirstArticleTemplate)
            .options(
                load_only(
                    FirstArticleTemplate.id,
                    FirstArticleTemplate.product_id,
                    FirstArticleTemplate.process_code,
                    FirstArticleTemplate.template_name,
                    FirstArticleTemplate.check_content,
                    FirstArticleTemplate.test_value,
                )
            )
            .where(
                FirstArticleTemplate.product_id == order.product_id,
                FirstArticleTemplate.process_code == process_row.process_code,
                FirstArticleTemplate.is_enabled.is_(True),
            )
            .order_by(
                FirstArticleTemplate.template_name.asc(),
                FirstArticleTemplate.id.asc(),
            )
        )
        .scalars()
        .all()
    )
    return success_response(
        FirstArticleTemplateListResult(
            total=len(rows),
            items=[
                FirstArticleTemplateItem(
                    id=row.id,
                    product_id=row.product_id,
                    process_code=row.process_code,
                    template_name=row.template_name,
                    check_content=row.check_content,
                    test_value=row.test_value,
                )
                for row in rows
            ],
        )
    )


@router.get(
    "/orders/{order_id}/first-article/participant-users",
    response_model=ApiResponse[FirstArticleParticipantOptionListResult],
)
def list_first_article_participant_users_api(
    order_id: int,
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast(PERM_PROD_EXECUTION_FIRST_ARTICLE)),
) -> ApiResponse[FirstArticleParticipantOptionListResult]:
    order = db.get(ProductionOrder, order_id)
    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )
    rows = (
        db.execute(
            select(User)
            .options(load_only(User.id, User.username, User.full_name))
            .where(User.is_active.is_(True), User.is_deleted.is_(False))
            .order_by(User.username.asc(), User.id.asc())
        )
        .scalars()
        .all()
    )
    return success_response(
        FirstArticleParticipantOptionListResult(
            total=len(rows),
            items=[
                FirstArticleParticipantOptionItem(
                    id=row.id,
                    username=row.username,
                    full_name=row.full_name,
                )
                for row in rows
            ],
        )
    )


@router.get(
    "/orders/{order_id}/first-article/parameters",
    response_model=ApiResponse[FirstArticleParameterListResult],
)
def get_first_article_parameters_api(
    order_id: int,
    order_process_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_PROD_EXECUTION_FIRST_ARTICLE)),
) -> ApiResponse[FirstArticleParameterListResult]:
    order, _ = _get_first_article_order_context(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    product = get_product_by_id(db, order.product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )
    parameter_scope = "effective"
    try:
        revision, parameters = get_effective_product_parameters(db, product=product)
    except ValueError:
        current_revision = get_current_revision(db, product=product)
        if current_revision is None:
            return success_response(
                FirstArticleParameterListResult(
                    product_id=product.id,
                    product_name=product.name,
                    parameter_scope="version",
                    version=0,
                    version_label="-",
                    lifecycle_status=product.lifecycle_status,
                    total=0,
                    items=[],
                )
            )
        parameter_scope = "version"
        revision, parameters = get_product_version_parameters(
            db,
            product=product,
            version=current_revision.version,
        )
    return success_response(
        FirstArticleParameterListResult(
            product_id=product.id,
            product_name=product.name,
            parameter_scope=parameter_scope,
            version=revision.version,
            version_label=revision.version_label,
            lifecycle_status=revision.lifecycle_status,
            total=len(parameters),
            items=[
                FirstArticleParameterItem(
                    name=row.param_key,
                    category=row.param_category,
                    type=row.param_type,
                    value=row.param_value,
                    description=row.param_description or "",
                    sort_order=row.sort_order,
                    is_preset=row.is_preset,
                )
                for row in parameters
            ],
        )
    )


@router.post(
    "/orders/{order_id}/end-production",
    response_model=ApiResponse[OrderActionResult],
)
def end_production_api(
    order_id: int,
    payload: EndProductionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission(PERM_PROD_EXECUTION_END_PRODUCTION)
    ),
) -> ApiResponse[OrderActionResult]:
    try:
        row, _, _ = end_production(
            db,
            order_id=order_id,
            order_process_id=payload.order_process_id,
            pipeline_instance_id=payload.pipeline_instance_id,
            quantity=payload.quantity,
            remark=payload.remark,
            operator=current_user,
            effective_operator_user_id=payload.effective_operator_user_id,
            assist_authorization_id=payload.assist_authorization_id,
            defect_items=[item.model_dump() for item in payload.defect_items]
            if payload.defect_items
            else None,
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
    _: User = Depends(require_permission(PERM_PROD_STATS_OVERVIEW)),
) -> ApiResponse[ProductionStatsOverview]:
    payload = get_overview_stats(db)
    return success_response(ProductionStatsOverview(**payload))


@router.get(
    "/stats/processes",
    response_model=ApiResponse[ProductionProcessStatsResult],
)
def get_process_stats_api(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_PROD_STATS_PROCESSES)),
) -> ApiResponse[ProductionProcessStatsResult]:
    rows = get_process_stats(db)
    return success_response(
        ProductionProcessStatsResult(
            items=[ProductionProcessStatItem(**row) for row in rows]
        )
    )


@router.get(
    "/stats/operators",
    response_model=ApiResponse[ProductionOperatorStatsResult],
)
def get_operator_stats_api(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_PROD_STATS_OPERATORS)),
) -> ApiResponse[ProductionOperatorStatsResult]:
    rows = get_operator_stats(db)
    return success_response(
        ProductionOperatorStatsResult(
            items=[ProductionOperatorStatItem(**row) for row in rows]
        )
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
    _: User = Depends(require_permission(PERM_PROD_DATA_TODAY_REALTIME)),
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
    _: User = Depends(require_permission(PERM_PROD_DATA_UNFINISHED_PROGRESS)),
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
    _: User = Depends(require_permission(PERM_PROD_DATA_MANUAL)),
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
    current_user: User = Depends(require_permission(PERM_PROD_DATA_MANUAL_EXPORT)),
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
    product_name: str | None = Query(default=None),
    process_code: str | None = Query(default=None),
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_PROD_SCRAP_STATISTICS_LIST)),
) -> ApiResponse[ScrapStatisticsListResult]:
    try:
        total, rows = list_scrap_statistics(
            db,
            page=page,
            page_size=page_size,
            filters=ScrapStatisticsFilters(
                keyword=keyword,
                progress=progress,
                product_name=product_name,
                process_code=process_code,
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
    current_user: User = Depends(require_permission(PERM_PROD_SCRAP_STATISTICS_EXPORT)),
) -> ApiResponse[ProductionExportResult]:
    try:
        result = export_scrap_statistics_csv(
            db,
            filters=ScrapStatisticsFilters(
                keyword=payload.keyword,
                progress=payload.progress,
                product_name=payload.product_name,
                process_code=payload.process_code,
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
    _: User = Depends(require_permission(PERM_PROD_REPAIR_ORDERS_LIST)),
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
    current_user: User = Depends(
        require_permission(PERM_PROD_REPAIR_ORDERS_CREATE_MANUAL)
    ),
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
    _: User = Depends(require_permission(PERM_PROD_REPAIR_ORDERS_PHENOMENA_SUMMARY)),
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
    current_user: User = Depends(require_permission(PERM_PROD_REPAIR_ORDERS_COMPLETE)),
) -> ApiResponse[RepairOrderItem]:
    try:
        row = complete_repair_order(
            db,
            repair_order_id=repair_order_id,
            cause_items=[item.model_dump() for item in payload.cause_items],
            scrap_replenished=payload.scrap_replenished,
            return_allocations=[
                item.model_dump() for item in payload.return_allocations
            ],
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
    current_user: User = Depends(require_permission(PERM_PROD_REPAIR_ORDERS_EXPORT)),
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
    order_code: str | None = Query(default=None),
    process_name: str | None = Query(default=None),
    requester_username: str | None = Query(default=None),
    helper_username: str | None = Query(default=None),
    created_at_from: datetime | None = Query(default=None),
    created_at_to: datetime | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_permission(PERM_PROD_ASSIST_AUTHORIZATIONS_LIST)
    ),
) -> ApiResponse[AssistAuthorizationListResult]:
    try:
        total, rows = list_assist_authorizations(
            db,
            current_user=current_user,
            page=page,
            page_size=page_size,
            status=status_text,
            order_code=order_code,
            process_name=process_name,
            requester_username=requester_username,
            helper_username=helper_username,
            created_at_from=created_at_from,
            created_at_to=created_at_to,
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
    current_user: User = Depends(
        require_permission(PERM_PROD_ASSIST_AUTHORIZATIONS_CREATE)
    ),
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
        db.commit()
    except Exception as error:
        db.rollback()
        _raise_service_error(error)
    return success_response(
        _to_assist_authorization_item(row),
        message="created",
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
    stage_id: int | None = Query(default=None, gt=0),
    db: Session = Depends(get_db),
    _: None = Depends(require_permission_fast(PERM_PROD_ASSIST_USER_OPTIONS_LIST)),
) -> ApiResponse[AssistUserOptionListResult]:
    allowed_role_codes = {
        ROLE_SYSTEM_ADMIN,
        ROLE_PRODUCTION_ADMIN,
        ROLE_OPERATOR,
    }
    if role_code and role_code not in allowed_role_codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role_code: {role_code}",
        )

    filters = [
        User.is_active.is_(True),
        User.is_deleted.is_(False),
        Role.code.in_(allowed_role_codes),
    ]
    if role_code:
        filters.append(Role.code == role_code)
    if stage_id is not None:
        filters.append(User.stage_id == stage_id)
    if keyword and keyword.strip():
        like_pattern = f"%{keyword.strip()}%"
        filters.append(
            or_(
                User.username.ilike(like_pattern),
                User.full_name.ilike(like_pattern),
            )
        )

    count_stmt = (
        select(func.count(func.distinct(User.id)))
        .select_from(User)
        .join(User.roles)
        .where(*filters)
    )
    total = db.execute(count_stmt).scalar() or 0
    offset = (page - 1) * page_size
    paged_stmt = (
        select(User)
        .options(
            load_only(User.id, User.username, User.full_name, User.stage_id),
            selectinload(User.roles).load_only(Role.id, Role.code),
        )
        .join(User.roles)
        .where(*filters)
        .order_by(User.id.asc())
        .distinct()
        .offset(offset)
        .limit(page_size)
    )
    paged_rows = db.execute(paged_stmt).scalars().unique().all()
    return success_response(
        AssistUserOptionListResult(
            total=total,
            items=[_to_assist_user_option_item(user) for user in paged_rows],
        )
    )


def _to_pipeline_instance_item(row: object) -> PipelineInstanceItem:
    return PipelineInstanceItem(
        id=row.id,
        pipeline_link_id=row.pipeline_link_id,
        sub_order_id=row.sub_order_id,
        order_id=row.order_id,
        order_code=row.order.order_code if row.order else "",
        order_process_id=row.order_process_id,
        process_code=row.process_code,
        process_name=row.order_process.process_name if row.order_process else "",
        pipeline_seq=row.pipeline_seq,
        pipeline_sub_order_no=row.pipeline_sub_order_no,
        is_active=row.is_active,
        invalid_reason=row.invalid_reason,
        invalidated_at=row.invalidated_at,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_repair_order_detail_item(
    row: object, event_logs: list | None = None
) -> RepairOrderDetailItem:
    from app.schemas.production import (
        RepairCauseDetailItem,
        RepairDefectPhenomenonItem,
        RepairEventLogItem,
        RepairReturnRouteItem,
    )

    return RepairOrderDetailItem(
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
        defect_rows=[
            RepairDefectPhenomenonItem(
                id=d.id,
                phenomenon=d.phenomenon,
                quantity=d.quantity,
                production_record_id=d.production_record_id,
                production_sub_order_id=d.production_record.sub_order_id
                if d.production_record is not None
                else None,
                production_record_type=d.production_record.record_type
                if d.production_record is not None
                else None,
                production_record_quantity=d.production_record.production_quantity
                if d.production_record is not None
                else None,
                production_record_created_at=d.production_record.created_at
                if d.production_record is not None
                else None,
                production_record_operator_user_id=d.production_record.operator_user_id
                if d.production_record is not None
                else None,
            )
            for d in (row.defect_rows or [])
        ],
        cause_rows=[
            RepairCauseDetailItem(
                id=c.id,
                phenomenon=c.phenomenon,
                reason=c.reason,
                quantity=c.quantity,
                is_scrap=c.is_scrap,
            )
            for c in (row.cause_rows or [])
        ],
        return_routes=[
            RepairReturnRouteItem(
                id=r.id,
                target_process_id=r.target_process_id,
                target_process_code=r.target_process_code,
                target_process_name=r.target_process_name,
                return_quantity=r.return_quantity,
            )
            for r in (row.return_routes or [])
        ],
        event_logs=[
            RepairEventLogItem(
                id=e.id,
                order_code=e.order_code_snapshot,
                order_status=e.order_status_snapshot,
                product_name=e.product_name_snapshot,
                process_code=e.process_code_snapshot,
                event_type=e.event_type,
                event_title=e.event_title,
                event_detail=e.event_detail,
                payload_json=e.payload_json,
                created_at=e.created_at,
            )
            for e in (event_logs or [])
        ],
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


@router.post(
    "/orders/export",
    response_model=ApiResponse[ProductionExportResult],
)
def export_orders_api(
    payload: OrdersExportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_PROD_ORDERS_EXPORT)),
) -> ApiResponse[ProductionExportResult]:
    try:
        result = export_orders_csv(
            db,
            keyword=payload.keyword,
            status=payload.status,
            product_name=payload.product_name,
            pipeline_enabled=payload.pipeline_enabled,
            start_date_from=payload.start_date_from,
            start_date_to=payload.start_date_to,
            due_date_from=payload.due_date_from,
            due_date_to=payload.due_date_to,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(ProductionExportResult(**result))


@router.get(
    "/pipeline-instances",
    response_model=ApiResponse[PipelineInstanceListResult],
)
def get_pipeline_instances_api(
    order_id: int | None = Query(default=None),
    order_code: str | None = Query(default=None),
    order_process_id: int | None = Query(default=None),
    sub_order_id: int | None = Query(default=None),
    process_keyword: str | None = Query(default=None),
    pipeline_sub_order_no: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_PROD_PIPELINE_INSTANCES_LIST)),
) -> ApiResponse[PipelineInstanceListResult]:
    try:
        total, rows = list_pipeline_instances(
            db,
            order_id=order_id,
            order_code=order_code,
            order_process_id=order_process_id,
            sub_order_id=sub_order_id,
            process_keyword=process_keyword,
            pipeline_sub_order_no=pipeline_sub_order_no,
            is_active=is_active,
            page=page,
            page_size=page_size,
        )
    except Exception as error:
        _raise_service_error(error)
    return success_response(
        PipelineInstanceListResult(
            total=total,
            items=[_to_pipeline_instance_item(row) for row in rows],
        )
    )


@router.get(
    "/scrap-statistics/{scrap_id}",
    response_model=ApiResponse[ScrapStatisticsDetailItem],
)
def get_scrap_statistics_detail_api(
    scrap_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_PROD_SCRAP_STATISTICS_DETAIL)),
) -> ApiResponse[ScrapStatisticsDetailItem]:
    from sqlalchemy import select as sa_select
    from app.models.production_scrap_statistics import ProductionScrapStatistics
    from app.models.order_event_log import OrderEventLog
    from app.schemas.production import ScrapEventLogItem, ScrapRelatedRepairItem

    row = (
        db.execute(
            sa_select(ProductionScrapStatistics).where(
                ProductionScrapStatistics.id == scrap_id
            )
        )
        .scalars()
        .first()
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Scrap statistics not found"
        )
    # Query related repair orders by order/process.
    related_repairs: list[ScrapRelatedRepairItem] = []
    if row.order_id is not None:
        repair_filters = [RepairOrder.source_order_id == row.order_id]
        if row.process_id is not None:
            repair_filters.append(RepairOrder.source_order_process_id == row.process_id)
        repair_rows = (
            db.execute(
                sa_select(RepairOrder)
                .where(*repair_filters)
                .order_by(RepairOrder.repair_time.desc())
            )
            .scalars()
            .all()
        )
        related_repairs = [
            ScrapRelatedRepairItem(
                id=r.id,
                repair_order_code=r.repair_order_code,
                status=r.status,
                repair_quantity=r.repair_quantity,
                repaired_quantity=r.repaired_quantity,
                scrap_quantity=r.scrap_quantity,
                repair_time=r.repair_time,
                completed_at=r.completed_at,
            )
            for r in repair_rows
        ]
    related_logs: list[ScrapEventLogItem] = []
    if row.order_id is not None:
        log_rows = [
            log
            for log in db.execute(
                select(OrderEventLog)
                .where(OrderEventLog.order_id == row.order_id)
                .order_by(OrderEventLog.created_at.desc())
                .limit(100)
            )
            .scalars()
            .all()
            if (
                log.process_code_snapshot == row.process_code
                or log.event_type == "scrap_statistics_export"
            )
        ]
        related_logs = [
            ScrapEventLogItem(
                id=log.id,
                order_code=log.order_code_snapshot,
                order_status=log.order_status_snapshot,
                product_name=log.product_name_snapshot,
                process_code=log.process_code_snapshot,
                event_type=log.event_type,
                event_title=log.event_title,
                event_detail=log.event_detail,
                payload_json=log.payload_json,
                created_at=log.created_at,
            )
            for log in log_rows
        ]

    return success_response(
        ScrapStatisticsDetailItem(
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
            related_repair_orders=related_repairs,
            related_event_logs=related_logs,
        )
    )


@router.get(
    "/repair-orders/{repair_order_id}/detail",
    response_model=ApiResponse[RepairOrderDetailItem],
)
def get_repair_order_detail_api(
    repair_order_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission(PERM_PROD_REPAIR_ORDERS_DETAIL)),
) -> ApiResponse[RepairOrderDetailItem]:
    from app.models.order_event_log import OrderEventLog

    row = get_repair_order_by_id(db, repair_order_id=repair_order_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Repair order not found"
        )
    # Query latest related order events for context.
    event_logs = []
    if row.source_order_id is not None:
        event_logs = [
            event
            for event in db.execute(
                select(OrderEventLog)
                .where(OrderEventLog.order_id == row.source_order_id)
                .order_by(OrderEventLog.created_at.desc())
                .limit(100)
            )
            .scalars()
            .all()
            if (
                event.process_code_snapshot == row.source_process_code
                or (
                    event.payload_json
                    and f'"repair_order_id":{row.id}' in event.payload_json
                )
            )
        ]

    return success_response(_to_repair_order_detail_item(row, event_logs=event_logs))

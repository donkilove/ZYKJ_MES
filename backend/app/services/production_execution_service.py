from __future__ import annotations

from datetime import UTC, date, datetime

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.authz_catalog import PERM_PROD_MY_ORDERS_PROXY
from app.core.config import ensure_runtime_settings_secure, settings
from app.core.production_constants import (
    ORDER_STATUS_COMPLETED,
    ORDER_STATUS_IN_PROGRESS,
    PROCESS_STATUS_COMPLETED,
    PROCESS_STATUS_IN_PROGRESS,
    PROCESS_STATUS_PARTIAL,
    PROCESS_STATUS_PENDING,
    RECORD_TYPE_FIRST_ARTICLE,
    RECORD_TYPE_PRODUCTION,
    SUB_ORDER_STATUS_IN_PROGRESS,
    SUB_ORDER_STATUS_PENDING,
)
from app.core.rbac import ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN
from app.models.daily_verification_code import DailyVerificationCode
from app.models.first_article_participant import FirstArticleParticipant
from app.models.first_article_record import FirstArticleRecord
from app.models.first_article_template import FirstArticleTemplate
from app.models.order_sub_order_pipeline_instance import ProcessPipelineInstance
from app.models.process import Process
from app.models.production_assist_authorization import (
    ProductionAssistAuthorization,
)
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.production_record import ProductionRecord
from app.models.production_sub_order import ProductionSubOrder
from app.models.user import User
from app.services.assist_authorization_service import (
    ASSIST_OP_END_PRODUCTION,
    ASSIST_OP_FIRST_ARTICLE,
    ASSIST_STATUS_APPROVED,
    get_usable_assist_authorization_for_operation,
    mark_assist_authorization_used,
)
from app.services.authz_service import has_permission
from app.services.production_event_log_service import add_order_event_log
from app.services.production_order_service import (
    _invalidate_pipeline_instances_for_order,
    allocate_pipeline_instance_for_process,
    ensure_sub_orders_visible_quantity,
    get_active_pipeline_instance_for_process,
    get_active_pipeline_instance_for_sub_order,
    get_active_pipeline_instance_for_link_id,
    get_active_pipeline_instance_for_process_sequence,
    get_current_cycle_manual_repair_quantity,
    get_in_progress_sub_order_count,
    get_process_remaining_quantity,
    get_runtime_max_producible_quantity,
    get_user_parallel_block_reason_for_process,
    invalidate_pipeline_instances_for_process,
    is_pipeline_parallel_edge_for_processes,
    is_pipeline_process_selected_for_order,
    list_user_parallel_block_reasons_for_process,
)
from app.services.production_repair_service import create_repair_order


def _get_today_verification_code(
    db: Session,
    *,
    operator_user_id: int,
) -> DailyVerificationCode:
    today = date.today()
    row = (
        db.execute(
            select(DailyVerificationCode)
            .where(DailyVerificationCode.verify_date == today)
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if row:
        return row
    ensure_runtime_settings_secure(require_verification_code=True)
    row = DailyVerificationCode(
        verify_date=today,
        code=settings.production_default_verification_code,
        created_by_user_id=operator_user_id,
    )
    db.add(row)
    db.flush()
    return row


def _can_proxy_cross_user_operation(db: Session, *, operator: User) -> bool:
    return has_permission(
        db,
        user=operator,
        permission_code=PERM_PROD_MY_ORDERS_PROXY,
    )


def _has_process_scope_exemption(user: User) -> bool:
    if user.is_superuser:
        return True
    role_codes = {role.code for role in user.roles if role.is_enabled}
    return bool(role_codes.intersection({ROLE_SYSTEM_ADMIN, ROLE_PRODUCTION_ADMIN}))


def _is_user_bound_to_process(
    db: Session,
    *,
    user_id: int,
    process_code: str,
) -> bool:
    return (
        db.execute(
            select(Process.id)
            .select_from(User)
            .join(User.processes)
            .where(
                User.id == user_id,
                User.is_active.is_(True),
                Process.code == process_code,
            )
            .limit(1)
        ).scalar()
        is not None
    )


def _ensure_effective_operator_can_operate_process(
    db: Session,
    *,
    effective_operator_user_id: int,
    process_row: ProductionOrderProcess,
    assist_authorization_row: ProductionAssistAuthorization | None = None,
) -> None:
    effective_operator = db.get(User, effective_operator_user_id)
    if effective_operator is None or not effective_operator.is_active:
        raise ValueError("Effective operator not found or inactive")
    if (
        assist_authorization_row is not None
        and int(assist_authorization_row.helper_user_id) == effective_operator_user_id
        and int(assist_authorization_row.order_process_id) == int(process_row.id)
    ):
        return
    if _has_process_scope_exemption(effective_operator):
        return
    if _is_user_bound_to_process(
        db,
        user_id=effective_operator_user_id,
        process_code=process_row.process_code,
    ):
        return
    raise PermissionError("当前操作员未绑定该工序，不能操作该工序订单")


def _lock_order_and_process(
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


def _lock_sub_order(
    db: Session,
    *,
    order_process_id: int,
    operator_user_id: int,
) -> ProductionSubOrder:
    row = (
        db.execute(
            select(ProductionSubOrder)
            .where(
                ProductionSubOrder.order_process_id == order_process_id,
                ProductionSubOrder.operator_user_id == operator_user_id,
            )
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if not row:
        row = ProductionSubOrder(
            order_process_id=order_process_id,
            operator_user_id=operator_user_id,
            completed_quantity=0,
            status=SUB_ORDER_STATUS_PENDING,
        )
        db.add(row)
        db.flush()
    return row


def _lock_previous_process(
    db: Session,
    *,
    order_id: int,
    process_order: int,
) -> ProductionOrderProcess | None:
    if process_order <= 1:
        return None
    return (
        db.execute(
            select(ProductionOrderProcess)
            .where(
                ProductionOrderProcess.order_id == order_id,
                ProductionOrderProcess.process_order == process_order - 1,
            )
            .with_for_update()
        )
        .scalars()
        .first()
    )


def _get_required_pipeline_instance(
    db: Session,
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
    sub_order: ProductionSubOrder,
    pipeline_instance_id: int | None,
) -> ProcessPipelineInstance | None:
    pipeline_process_selected = is_pipeline_process_selected_for_order(
        order=order,
        process_code=process_row.process_code,
    )
    if not pipeline_process_selected:
        return None
    if pipeline_instance_id is None:
        return None
    current_instance = get_active_pipeline_instance_for_process(
        db,
        order_process_id=process_row.id,
        pipeline_instance_id=pipeline_instance_id,
    )
    if current_instance is None:
        raise RuntimeError("Pipeline instance binding does not match current executable task")
    return current_instance


def _resolve_pipeline_instance_for_first_article(
    db: Session,
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
    sub_order: ProductionSubOrder,
    pipeline_instance_id: int | None,
) -> ProcessPipelineInstance | None:
    pipeline_process_selected = is_pipeline_process_selected_for_order(
        order=order,
        process_code=process_row.process_code,
    )
    if not pipeline_process_selected:
        return None
    if pipeline_instance_id is not None:
        current_instance = get_active_pipeline_instance_for_process(
            db,
            order_process_id=process_row.id,
            pipeline_instance_id=pipeline_instance_id,
        )
        if current_instance is None:
            raise RuntimeError("Pipeline instance binding does not match current executable task")
        return current_instance

    previous_process = _lock_previous_process(
        db,
        order_id=order.id,
        process_order=process_row.process_order,
    )
    if previous_process is None or not is_pipeline_parallel_edge_for_processes(
        order=order,
        previous_process_code=previous_process.process_code if previous_process else "",
        current_process_code=process_row.process_code,
    ):
        return allocate_pipeline_instance_for_process(
            db,
            order=order,
            process_row=process_row,
        )

    candidate_previous_instances = (
        db.execute(
            select(ProcessPipelineInstance)
            .where(
                ProcessPipelineInstance.order_id == order.id,
                ProcessPipelineInstance.order_process_id == previous_process.id,
                ProcessPipelineInstance.is_active.is_(True),
            )
            .order_by(ProcessPipelineInstance.pipeline_seq.asc(), ProcessPipelineInstance.id.asc())
        )
        .scalars()
        .all()
    )
    if not candidate_previous_instances:
        raise RuntimeError("Previous process pipeline instance is missing or inactive")

    existing_current_instances = (
        db.execute(
            select(ProcessPipelineInstance)
            .where(
                ProcessPipelineInstance.order_id == order.id,
                ProcessPipelineInstance.order_process_id == process_row.id,
                ProcessPipelineInstance.is_active.is_(True),
            )
        )
        .scalars()
        .all()
    )
    used_seqs = {int(row.pipeline_seq) for row in existing_current_instances}
    chosen_previous = next(
        (
            row
            for row in candidate_previous_instances
            if row.pipeline_seq not in used_seqs
        ),
        None,
    )
    if chosen_previous is None:
        raise RuntimeError("Previous process pipeline instance is missing or inactive")
    return allocate_pipeline_instance_for_process(
        db,
        order=order,
        process_row=process_row,
        preferred_pipeline_seq=int(chosen_previous.pipeline_seq),
        preferred_pipeline_link_id=chosen_previous.pipeline_link_id,
    )


def _ensure_pipeline_sequence_gate(
    db: Session,
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
    sub_order: ProductionSubOrder,
    current_instance: ProcessPipelineInstance | None,
) -> None:
    if current_instance is None:
        return
    previous_process = _lock_previous_process(
        db,
        order_id=order.id,
        process_order=process_row.process_order,
    )
    if previous_process is None:
        return
    if not is_pipeline_parallel_edge_for_processes(
        order=order,
        previous_process_code=previous_process.process_code,
        current_process_code=process_row.process_code,
    ):
        return
    pipeline_link_id = (current_instance.pipeline_link_id or "").strip()
    previous_instance = None
    if pipeline_link_id:
        previous_instance = get_active_pipeline_instance_for_link_id(
            db,
            order_id=order.id,
            order_process_id=previous_process.id,
            pipeline_link_id=pipeline_link_id,
        )
    else:
        previous_instance = get_active_pipeline_instance_for_process_sequence(
            db,
            order_id=order.id,
            order_process_id=previous_process.id,
            pipeline_seq=current_instance.pipeline_seq,
        )
    if previous_instance is None:
        raise RuntimeError("Previous process pipeline instance is missing or inactive")
    return


def _is_start_gate_allowed(
    db: Session,
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
) -> bool:
    previous_process = _lock_previous_process(
        db,
        order_id=order.id,
        process_order=process_row.process_order,
    )
    if previous_process is None:
        return True
    if not order.pipeline_enabled:
        return True
    if is_pipeline_parallel_edge_for_processes(
        order=order,
        previous_process_code=previous_process.process_code,
        current_process_code=process_row.process_code,
    ):
        return previous_process.status in {
            PROCESS_STATUS_IN_PROGRESS,
            PROCESS_STATUS_PARTIAL,
            PROCESS_STATUS_COMPLETED,
        }
    return previous_process.status == PROCESS_STATUS_COMPLETED


def _is_end_gate_allowed(
    db: Session,
    *,
    order: ProductionOrder,
    process_row: ProductionOrderProcess,
) -> bool:
    previous_process = _lock_previous_process(
        db,
        order_id=order.id,
        process_order=process_row.process_order,
    )
    if previous_process is None:
        return True
    if not order.pipeline_enabled:
        return True
    if is_pipeline_parallel_edge_for_processes(
        order=order,
        previous_process_code=previous_process.process_code,
        current_process_code=process_row.process_code,
    ):
        return previous_process.completed_quantity > 0
    return True


def _refresh_order_status(db: Session, *, order: ProductionOrder) -> None:
    process_rows = (
        db.execute(
            select(ProductionOrderProcess)
            .where(ProductionOrderProcess.order_id == order.id)
            .order_by(
                ProductionOrderProcess.process_order.asc(),
                ProductionOrderProcess.id.asc(),
            )
            .with_for_update()
        )
        .scalars()
        .all()
    )
    first_incomplete = next(
        (
            row
            for row in process_rows
            if int(row.completed_quantity or 0) < int(row.visible_quantity or 0)
        ),
        None,
    )
    if first_incomplete is None and process_rows:
        order.status = ORDER_STATUS_COMPLETED
        order.current_process_code = None
        return

    order.status = ORDER_STATUS_IN_PROGRESS
    if first_incomplete is not None:
        order.current_process_code = first_incomplete.process_code
    elif process_rows:
        order.current_process_code = process_rows[0].process_code


def _normalize_first_article_result(result: str) -> str:
    normalized = result.strip().lower()
    if normalized not in {"passed", "failed"}:
        raise ValueError("First article result must be passed or failed")
    return normalized


def _normalize_optional_text(value: str | None) -> str | None:
    text = (value or "").strip()
    return text or None


def _normalize_optional_preserved_text(value: str | None) -> str | None:
    if value is None:
        return None
    return value if value.strip() else None


def _build_first_article_event_detail(
    *,
    operator_username: str,
    process_name: str,
    result: str,
    remark: str | None,
) -> str:
    if result == "passed":
        prefix = f"{operator_username} 在工序 {process_name} 提交首件并开工。"
    else:
        prefix = f"{operator_username} 在工序 {process_name} 提交首件不通过。"
    normalized_remark = _normalize_optional_text(remark)
    if normalized_remark is None:
        return prefix
    return f"{prefix}{normalized_remark}"


def _get_first_article_template(
    db: Session,
    *,
    template_id: int,
    product_id: int,
    process_code: str,
) -> FirstArticleTemplate:
    row = (
        db.execute(
            select(FirstArticleTemplate).where(
                FirstArticleTemplate.id == template_id,
                FirstArticleTemplate.product_id == product_id,
                FirstArticleTemplate.process_code == process_code,
                FirstArticleTemplate.is_enabled.is_(True),
            )
        )
        .scalars()
        .first()
    )
    if row is None:
        raise ValueError("First article template not found")
    return row


def _normalize_participant_user_ids(
    db: Session,
    *,
    participant_user_ids: list[int] | None,
) -> list[int]:
    normalized_ids: list[int] = []
    seen: set[int] = set()
    for raw_user_id in participant_user_ids or []:
        user_id = int(raw_user_id)
        if user_id <= 0:
            raise ValueError("Participant user id must be greater than 0")
        if user_id in seen:
            continue
        seen.add(user_id)
        normalized_ids.append(user_id)
    if not normalized_ids:
        return []

    rows = (
        db.execute(
            select(User.id).where(
                User.id.in_(normalized_ids),
                User.is_active.is_(True),
                User.is_deleted.is_(False),
            )
        )
        .scalars()
        .all()
    )
    found_ids = {int(row_id) for row_id in rows}
    missing_ids = [
        str(user_id) for user_id in normalized_ids if user_id not in found_ids
    ]
    if missing_ids:
        raise ValueError(
            f"Participant users not found or inactive: {', '.join(missing_ids)}"
        )
    return normalized_ids


def _validate_participant_users_exclude_effective_operator(
    *,
    participant_user_ids: list[int],
    effective_operator_user_id: int,
) -> None:
    if effective_operator_user_id in participant_user_ids:
        raise ValueError("参与操作员不能包含当前主操作员本人")


def submit_first_article(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    pipeline_instance_id: int | None,
    template_id: int | None,
    check_content: str | None,
    test_value: str | None,
    result: str,
    participant_user_ids: list[int] | None,
    verification_code: str | None,
    remark: str | None,
    operator: User,
    effective_operator_user_id: int | None = None,
    assist_authorization_id: int | None = None,
    skip_verification_code: bool = False,
    reviewer_user_id: int | None = None,
    reviewed_at=None,
    review_remark: str | None = None,
    preserve_input_text: bool = False,
) -> tuple[ProductionOrder, ProductionOrderProcess, ProductionSubOrder]:
    order, process_row = _lock_order_and_process(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    if order.status == ORDER_STATUS_COMPLETED:
        raise ValueError("Order already completed")
    if process_row.status not in {
        PROCESS_STATUS_PENDING,
        PROCESS_STATUS_IN_PROGRESS,
        PROCESS_STATUS_PARTIAL,
    }:
        raise ValueError("Current process does not allow first-article operation")

    assist_row = None
    if assist_authorization_id:
        assist_row = get_usable_assist_authorization_for_operation(
            db,
            authorization_id=assist_authorization_id,
            order_id=order_id,
            order_process_id=order_process_id,
            helper_user_id=operator.id,
            operation=ASSIST_OP_FIRST_ARTICLE,
        )
        effective_user_id = operator.id
    else:
        effective_user_id = effective_operator_user_id or operator.id
        if effective_user_id != operator.id and not _can_proxy_cross_user_operation(
            db, operator=operator
        ):
            raise ValueError(
                "Assist authorization is required for cross-user operation"
            )

    _ensure_effective_operator_can_operate_process(
        db,
        effective_operator_user_id=effective_user_id,
        process_row=process_row,
        assist_authorization_row=assist_row,
    )

    sub_order = _lock_sub_order(
        db,
        order_process_id=process_row.id,
        operator_user_id=effective_user_id,
    )
    if sub_order.status != SUB_ORDER_STATUS_PENDING:
        raise ValueError("Current sub-order does not allow first-article operation")
    pipeline_instance = _resolve_pipeline_instance_for_first_article(
        db,
        order=order,
        process_row=process_row,
        sub_order=sub_order,
        pipeline_instance_id=pipeline_instance_id,
    )
    _ensure_pipeline_sequence_gate(
        db,
        order=order,
        process_row=process_row,
        sub_order=sub_order,
        current_instance=pipeline_instance,
    )

    process_remaining = get_process_remaining_quantity(
        db,
        process_row=process_row,
    )
    in_progress_count = get_in_progress_sub_order_count(
        db,
        order_process_id=process_row.id,
    )
    pool_remaining = get_runtime_max_producible_quantity(
        process_remaining_quantity=process_remaining,
        in_progress_count=in_progress_count,
        current_sub_order_status=SUB_ORDER_STATUS_PENDING,
    )
    pipeline_parallel_edge = False
    previous_process = _lock_previous_process(
        db,
        order_id=order.id,
        process_order=process_row.process_order,
    )
    if previous_process is not None:
        pipeline_parallel_edge = is_pipeline_parallel_edge_for_processes(
            order=order,
            previous_process_code=previous_process.process_code,
            current_process_code=process_row.process_code,
        )
    if pool_remaining <= 0 and not (pipeline_parallel_edge and pipeline_instance is not None):
        raise ValueError("No producible quantity available for current user")
    if not _is_start_gate_allowed(db, order=order, process_row=process_row):
        raise ValueError("Current process is blocked by pipeline start gate")

    normalized_verification_code = (verification_code or "").strip()
    if skip_verification_code:
        normalized_verification_code = normalized_verification_code or "SCAN_REVIEW"
    else:
        code_row = _get_today_verification_code(db, operator_user_id=operator.id)
        if normalized_verification_code != code_row.code:
            raise ValueError("Invalid verification code")

    normalized_result = _normalize_first_article_result(result)
    template_row = None
    if template_id is not None:
        template_row = _get_first_article_template(
            db,
            template_id=template_id,
            product_id=order.product_id,
            process_code=process_row.process_code,
        )
    normalize_text = (
        _normalize_optional_preserved_text
        if preserve_input_text
        else _normalize_optional_text
    )
    normalized_check_content = normalize_text(check_content)
    normalized_test_value = normalize_text(test_value)
    if template_row is not None:
        if normalized_check_content is None:
            normalized_check_content = normalize_text(template_row.check_content)
        if normalized_test_value is None:
            normalized_test_value = normalize_text(template_row.test_value)
    normalized_participant_user_ids = _normalize_participant_user_ids(
        db,
        participant_user_ids=participant_user_ids,
    )
    _validate_participant_users_exclude_effective_operator(
        participant_user_ids=normalized_participant_user_ids,
        effective_operator_user_id=effective_user_id,
    )
    if normalized_result == "passed":
        effective_operator_label = operator.username
        if effective_user_id != operator.id:
            effective_operator_row = db.get(User, effective_user_id)
            if effective_operator_row is not None:
                effective_operator_label = effective_operator_row.username
        effective_operator_block_reason = get_user_parallel_block_reason_for_process(
            db,
            user_id=effective_user_id,
            process_row=process_row,
            user_label=effective_operator_label,
        )
        if effective_operator_block_reason is not None:
            raise ValueError(effective_operator_block_reason)
        participant_candidate_ids = {
            participant_user_id
            for participant_user_id in normalized_participant_user_ids
            if participant_user_id != effective_user_id
        }
        if participant_candidate_ids:
            participant_rows = db.execute(
                select(User.id, User.username, User.full_name).where(
                    User.id.in_(participant_candidate_ids)
                )
            ).all()
            participant_label_by_id = {
                int(row.id): (
                    f"{row.username}({row.full_name})"
                    if (row.full_name or "").strip()
                    else row.username
                )
                for row in participant_rows
            }
            participant_block_reasons = list_user_parallel_block_reasons_for_process(
                db,
                user_ids=participant_candidate_ids,
                process_row=process_row,
                user_label_by_id=participant_label_by_id,
                for_participant=True,
            )
            if participant_block_reasons:
                raise ValueError(next(iter(participant_block_reasons.values())))

    if normalized_result == "passed":
        if process_row.status == PROCESS_STATUS_PENDING:
            process_row.status = PROCESS_STATUS_IN_PROGRESS
        sub_order.status = SUB_ORDER_STATUS_IN_PROGRESS
        if pipeline_instance is not None:
            pipeline_instance.sub_order_id = sub_order.id
        order.status = ORDER_STATUS_IN_PROGRESS
        if not order.current_process_code:
            order.current_process_code = process_row.process_code

    first_article_row = FirstArticleRecord(
        order_id=order.id,
        order_process_id=process_row.id,
        operator_user_id=operator.id,
        sub_order_id=sub_order.id,
        assist_authorization_id=assist_row.id if assist_row else None,
        template_id=template_row.id if template_row else None,
        verification_date=date.today(),
        verification_code=normalized_verification_code,
        result=normalized_result,
        check_content=normalized_check_content,
        test_value=normalized_test_value,
        remark=(remark or "").strip() or None,
        reviewer_user_id=reviewer_user_id,
        reviewed_at=reviewed_at,
        review_remark=(review_remark or "").strip() or None,
    )
    db.add(first_article_row)
    db.flush()
    for participant_user_id in normalized_participant_user_ids:
        db.add(
            FirstArticleParticipant(
                record_id=first_article_row.id,
                user_id=participant_user_id,
            )
        )

    if normalized_result == "passed":
        db.add(
            ProductionRecord(
                order_id=order.id,
                order_process_id=process_row.id,
                sub_order_id=sub_order.id,
                operator_user_id=operator.id,
                production_quantity=0,
                record_type=RECORD_TYPE_FIRST_ARTICLE,
            )
        )
    add_order_event_log(
        db,
        order_id=order.id,
        event_type=(
            "first_article_passed"
            if normalized_result == "passed"
            else "first_article_failed"
        ),
        event_title="首件通过" if normalized_result == "passed" else "首件不通过",
        event_detail=_build_first_article_event_detail(
            operator_username=operator.username,
            process_name=process_row.process_name,
            result=normalized_result,
            remark=remark,
        ),
        operator_user_id=operator.id,
        payload={
            "first_article_record_id": first_article_row.id,
            "order_process_id": process_row.id,
            "process_code": process_row.process_code,
            "template_id": template_row.id if template_row else None,
            "template_name": template_row.template_name if template_row else None,
            "result": normalized_result,
            "participant_user_ids": normalized_participant_user_ids,
            "operator_user_id": operator.id,
            "effective_operator_user_id": effective_user_id,
            "assist_authorization_id": assist_row.id if assist_row else None,
            "pipeline_instance_id": pipeline_instance.id if pipeline_instance else None,
            "pipeline_instance_no": pipeline_instance.pipeline_instance_no
            if pipeline_instance
            else None,
        },
    )
    if assist_row is not None:
        mark_assist_authorization_used(
            db,
            authorization_row=assist_row,
            operation=ASSIST_OP_FIRST_ARTICLE,
        )
    db.commit()
    db.refresh(order)
    db.refresh(process_row)
    db.refresh(sub_order)
    return order, process_row, sub_order


def end_production(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    pipeline_instance_id: int | None,
    quantity: int,
    remark: str | None,
    operator: User,
    effective_operator_user_id: int | None = None,
    assist_authorization_id: int | None = None,
    defect_items: list[dict[str, object]] | None = None,
) -> tuple[ProductionOrder, ProductionOrderProcess, ProductionSubOrder]:
    if quantity <= 0:
        raise ValueError("Quantity must be greater than 0")

    order, process_row = _lock_order_and_process(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    if order.status == ORDER_STATUS_COMPLETED:
        raise ValueError("Order already completed")
    if process_row.status not in {PROCESS_STATUS_IN_PROGRESS, PROCESS_STATUS_PARTIAL}:
        raise ValueError("Current process is not in progress")

    assist_row = None
    if assist_authorization_id:
        assist_row = get_usable_assist_authorization_for_operation(
            db,
            authorization_id=assist_authorization_id,
            order_id=order_id,
            order_process_id=order_process_id,
            helper_user_id=operator.id,
            operation=ASSIST_OP_END_PRODUCTION,
        )
        effective_user_id = operator.id
    else:
        effective_user_id = effective_operator_user_id or operator.id
        if effective_user_id != operator.id:
            raise PermissionError("结束生产只能由发起首件的操作员本人执行")

    _ensure_effective_operator_can_operate_process(
        db,
        effective_operator_user_id=effective_user_id,
        process_row=process_row,
        assist_authorization_row=assist_row,
    )

    sub_order = _lock_sub_order(
        db,
        order_process_id=process_row.id,
        operator_user_id=effective_user_id,
    )
    if sub_order.status != SUB_ORDER_STATUS_IN_PROGRESS:
        raise ValueError("Current sub-order is not in progress")
    pipeline_instance = _get_required_pipeline_instance(
        db,
        order=order,
        process_row=process_row,
        sub_order=sub_order,
        pipeline_instance_id=pipeline_instance_id,
    )
    _ensure_pipeline_sequence_gate(
        db,
        order=order,
        process_row=process_row,
        sub_order=sub_order,
        current_instance=pipeline_instance,
    )

    process_remaining = get_process_remaining_quantity(
        db,
        process_row=process_row,
    )
    in_progress_count = get_in_progress_sub_order_count(
        db,
        order_process_id=process_row.id,
    )
    max_producible = get_runtime_max_producible_quantity(
        process_remaining_quantity=process_remaining,
        in_progress_count=in_progress_count,
        current_sub_order_status=sub_order.status,
    )
    defect_quantity = 0
    if defect_items:
        defect_quantity = sum(
            int(item.get("quantity") or 0)
            for item in defect_items
            if isinstance(item, dict)
        )
        if defect_quantity < 0:
            raise ValueError("Defect quantity cannot be negative")
    manual_repair_quantity_before_end = get_current_cycle_manual_repair_quantity(
        db,
        order_id=order.id,
        order_process_id=process_row.id,
        operator_user_id=effective_user_id,
    )
    transfer_quantity = quantity - manual_repair_quantity_before_end - defect_quantity
    if transfer_quantity < 0:
        raise ValueError(
            "本次生产数量不能小于生产中手工送修数量与结束报工送修数量之和"
        )
    total_consumed_quantity = transfer_quantity + defect_quantity
    if total_consumed_quantity > max_producible:
        raise RuntimeError(
            f"Concurrent update detected. Max producible quantity is {max_producible}, "
            f"but transfer quantity plus defect quantity is {total_consumed_quantity}"
        )
    if not _is_end_gate_allowed(db, order=order, process_row=process_row):
        raise ValueError("Current process is blocked by pipeline end gate")

    process_row.completed_quantity += transfer_quantity
    sub_order.completed_quantity += transfer_quantity

    if process_row.completed_quantity >= order.quantity:
        process_row.completed_quantity = order.quantity
        process_row.status = PROCESS_STATUS_COMPLETED
    else:
        process_row.status = PROCESS_STATUS_PARTIAL

    if process_row.status == PROCESS_STATUS_COMPLETED:
        invalidate_pipeline_instances_for_process(
            db,
            order_process_id=process_row.id,
            reason="process_completed",
        )

    sub_order.status = SUB_ORDER_STATUS_PENDING

    next_process = (
        db.execute(
            select(ProductionOrderProcess)
            .where(
                ProductionOrderProcess.order_id == order.id,
                ProductionOrderProcess.process_order == process_row.process_order + 1,
            )
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if next_process:
        parallel_edge = is_pipeline_parallel_edge_for_processes(
            order=order,
            previous_process_code=process_row.process_code,
            current_process_code=next_process.process_code,
        )
        released_visible_quantity = min(process_row.completed_quantity, order.quantity)
        if parallel_edge:
            target_visible = released_visible_quantity
        elif process_row.status in {PROCESS_STATUS_PARTIAL, PROCESS_STATUS_COMPLETED}:
            target_visible = released_visible_quantity
        else:
            target_visible = next_process.visible_quantity
        if target_visible > next_process.visible_quantity:
            previous_visible = next_process.visible_quantity
            next_process.visible_quantity = target_visible
            add_order_event_log(
                db,
                order_id=order.id,
                event_type="process_visible_quantity_released",
                event_title="下工序放行量已更新",
                event_detail=(
                    f"工序 {process_row.process_name} 向下工序 {next_process.process_name} 放行可见量，"
                    f"从 {previous_visible} 变更为 {target_visible}"
                ),
                operator_user_id=operator.id,
                payload={
                    "source_order_process_id": process_row.id,
                    "source_process_code": process_row.process_code,
                    "target_order_process_id": next_process.id,
                    "target_process_code": next_process.process_code,
                    "previous_visible_quantity": previous_visible,
                    "target_visible_quantity": target_visible,
                },
            )
        ensure_sub_orders_visible_quantity(
            db,
            process_row=next_process,
            target_visible_quantity=next_process.visible_quantity,
        )

    record_row = ProductionRecord(
        order_id=order.id,
        order_process_id=process_row.id,
        sub_order_id=sub_order.id,
        operator_user_id=operator.id,
        production_quantity=quantity,
        record_type=RECORD_TYPE_PRODUCTION,
    )
    db.add(record_row)
    db.flush()

    repair_row = None
    if defect_items:
        if defect_quantity > 0:
            enriched_defect_items = []
            for item in defect_items:
                if not isinstance(item, dict):
                    continue
                enriched_item = dict(item)
                enriched_item["production_record_id"] = record_row.id
                enriched_item["production_time"] = record_row.created_at
                enriched_defect_items.append(enriched_item)
            repair_row = create_repair_order(
                db,
                order_id=order.id,
                order_process_id=process_row.id,
                sender=operator,
                production_quantity=quantity,
                defect_items=enriched_defect_items,
                auto_created=True,
            )
    total_defect_quantity = manual_repair_quantity_before_end + defect_quantity
    total_production_quantity = quantity
    defect_rate_percent = (
        round((total_defect_quantity / total_production_quantity) * 100, 2)
        if total_production_quantity > 0
        else 0.0
    )
    event_detail = (
        f"{operator.username} 在工序 {process_row.process_name} 报工 {quantity} 件，"
        f"流转 {transfer_quantity} 件。"
        if not remark
        else (
            f"{operator.username} 在工序 {process_row.process_name} 报工 {quantity} 件，"
            f"流转 {transfer_quantity} 件。{remark.strip()}"
        )
    )
    if total_defect_quantity > 0:
        event_detail = (
            f"{event_detail} 本次生产 {total_production_quantity} 件，"
            f"不良 {total_defect_quantity} 件"
            f"（手工送修 {manual_repair_quantity_before_end} + 结束统一送修 {defect_quantity}），"
            f"本次不良率 {defect_rate_percent:.2f}%。"
        )
    add_order_event_log(
        db,
        order_id=order.id,
        event_type="production_reported",
        event_title="报工完成",
        event_detail=event_detail,
        operator_user_id=operator.id,
        payload={
            "order_process_id": process_row.id,
            "process_code": process_row.process_code,
            "quantity": quantity,
            "transfer_quantity": transfer_quantity,
            "defect_quantity": defect_quantity,
            "manual_repair_quantity_before_end": manual_repair_quantity_before_end,
            "total_defect_quantity": total_defect_quantity,
            "total_production_quantity": total_production_quantity,
            "defect_rate_percent": defect_rate_percent,
            "total_consumed_quantity": total_consumed_quantity,
            "operator_user_id": operator.id,
            "effective_operator_user_id": effective_user_id,
            "assist_authorization_id": assist_row.id if assist_row else None,
            "production_record_id": record_row.id,
            "pipeline_instance_id": pipeline_instance.id if pipeline_instance else None,
            "pipeline_link_id": pipeline_instance.pipeline_link_id
            if pipeline_instance
            else None,
            "pipeline_instance_no": pipeline_instance.pipeline_instance_no
            if pipeline_instance
            else None,
            "repair_order_id": repair_row.id if repair_row else None,
            "repair_order_code": repair_row.repair_order_code if repair_row else None,
        },
    )
    if assist_row is not None:
        mark_assist_authorization_used(
            db,
            authorization_row=assist_row,
            operation=ASSIST_OP_END_PRODUCTION,
        )

    _refresh_order_status(db, order=order)
    if order.status == ORDER_STATUS_COMPLETED:
        _invalidate_pipeline_instances_for_order(
            db,
            order_id=order.id,
            reason="order_completed",
        )
    db.commit()
    db.refresh(order)
    db.refresh(process_row)
    db.refresh(sub_order)
    return order, process_row, sub_order

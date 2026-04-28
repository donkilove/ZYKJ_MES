from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.first_article_record import FirstArticleRecord
from app.models.first_article_review_session import FirstArticleReviewSession
from app.models.production_order import ProductionOrder
from app.models.production_order_process import ProductionOrderProcess
from app.models.user import User
from app.services.production_execution_service import (
    _get_first_article_template,
    _get_required_pipeline_instance,
    _is_start_gate_allowed,
    _lock_order_and_process,
    _lock_sub_order,
    _normalize_optional_text,
    _normalize_participant_user_ids,
    submit_first_article,
)


REVIEW_SESSION_PENDING = "pending"
REVIEW_SESSION_APPROVED = "approved"
REVIEW_SESSION_REJECTED = "rejected"
REVIEW_SESSION_EXPIRED = "expired"
REVIEW_SESSION_CANCELLED = "cancelled"
REVIEW_TOKEN_TTL = timedelta(minutes=5)


@dataclass(frozen=True)
class FirstArticleReviewSessionCommandResult:
    session_id: int
    review_url: str | None
    expires_at: datetime
    status: str
    first_article_record_id: int | None = None
    reviewer_user_id: int | None = None
    reviewed_at: datetime | None = None
    review_remark: str | None = None


@dataclass(frozen=True)
class FirstArticleReviewSessionDetailResult:
    session_id: int
    status: str
    expires_at: datetime
    order_id: int
    order_code: str
    product_name: str
    order_process_id: int
    process_name: str
    operator_user_id: int
    operator_username: str
    template_id: int | None
    check_content: str
    test_value: str
    participant_user_ids: list[int]
    review_remark: str | None


def _now() -> datetime:
    return datetime.now(UTC)


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _new_token() -> str:
    return secrets.token_urlsafe(32)


def _review_url_for_token(token: str) -> str:
    return f"/first-article-review?token={token}"


def _is_expired(row: FirstArticleReviewSession, *, now: datetime | None = None) -> bool:
    expires_at = row.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    return expires_at <= (now or _now())


def _expire_if_needed(db: Session, row: FirstArticleReviewSession) -> None:
    if row.status == REVIEW_SESSION_PENDING and _is_expired(row):
        row.status = REVIEW_SESSION_EXPIRED
        db.flush()


def _normalize_required_text(value: str, field_name: str) -> str:
    text = (value or "").strip()
    if not text:
        raise ValueError(f"{field_name} is required")
    return text


def _prepare_first_article_draft(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    pipeline_instance_id: int | None,
    template_id: int | None,
    check_content: str,
    test_value: str,
    participant_user_ids: list[int] | None,
    operator: User,
) -> tuple[ProductionOrder, ProductionOrderProcess, list[int], str, str]:
    order, process_row = _lock_order_and_process(
        db,
        order_id=order_id,
        order_process_id=order_process_id,
    )
    sub_order = _lock_sub_order(
        db,
        order_process_id=process_row.id,
        operator_user_id=operator.id,
    )
    pipeline_instance = _get_required_pipeline_instance(
        db,
        order=order,
        process_row=process_row,
        sub_order=sub_order,
        pipeline_instance_id=pipeline_instance_id,
    )
    if pipeline_instance is not None and pipeline_instance.id != pipeline_instance_id:
        raise ValueError("Pipeline instance binding does not match current task")
    if not _is_start_gate_allowed(db, order=order, process_row=process_row):
        raise ValueError("Current process is blocked by pipeline start gate")
    if template_id is not None:
        _get_first_article_template(
            db,
            template_id=template_id,
            product_id=order.product_id,
            process_code=process_row.process_code,
        )
    normalized_check_content = _normalize_required_text(
        check_content,
        "check_content",
    )
    normalized_test_value = _normalize_required_text(test_value, "test_value")
    normalized_participant_user_ids = _normalize_participant_user_ids(
        db,
        participant_user_ids=participant_user_ids,
    )
    return (
        order,
        process_row,
        normalized_participant_user_ids,
        normalized_check_content,
        normalized_test_value,
    )


def create_first_article_review_session(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    pipeline_instance_id: int | None,
    template_id: int | None,
    check_content: str,
    test_value: str,
    participant_user_ids: list[int] | None,
    operator: User,
    assist_authorization_id: int | None = None,
) -> FirstArticleReviewSessionCommandResult:
    _, _, normalized_participant_user_ids, normalized_check_content, normalized_test_value = (
        _prepare_first_article_draft(
            db,
            order_id=order_id,
            order_process_id=order_process_id,
            pipeline_instance_id=pipeline_instance_id,
            template_id=template_id,
            check_content=check_content,
            test_value=test_value,
            participant_user_ids=participant_user_ids,
            operator=operator,
        )
    )

    existing_rows = (
        db.execute(
            select(FirstArticleReviewSession)
            .where(
                FirstArticleReviewSession.order_id == order_id,
                FirstArticleReviewSession.order_process_id == order_process_id,
                FirstArticleReviewSession.operator_user_id == operator.id,
                FirstArticleReviewSession.status.in_(
                    [
                        REVIEW_SESSION_PENDING,
                        REVIEW_SESSION_REJECTED,
                        REVIEW_SESSION_EXPIRED,
                    ]
                ),
            )
            .with_for_update()
        )
        .scalars()
        .all()
    )
    for existing_row in existing_rows:
        existing_row.status = REVIEW_SESSION_CANCELLED

    token = _new_token()
    expires_at = _now() + REVIEW_TOKEN_TTL
    row = FirstArticleReviewSession(
        token_hash=_hash_token(token),
        status=REVIEW_SESSION_PENDING,
        expires_at=expires_at,
        order_id=order_id,
        order_process_id=order_process_id,
        pipeline_instance_id=pipeline_instance_id,
        operator_user_id=operator.id,
        assist_authorization_id=assist_authorization_id,
        template_id=template_id,
        check_content=normalized_check_content,
        test_value=normalized_test_value,
        participant_user_ids=normalized_participant_user_ids,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return FirstArticleReviewSessionCommandResult(
        session_id=row.id,
        review_url=_review_url_for_token(token),
        expires_at=row.expires_at,
        status=row.status,
    )


def refresh_first_article_review_session(
    db: Session,
    *,
    session_id: int,
    check_content: str,
    test_value: str,
    participant_user_ids: list[int] | None,
    operator: User,
) -> FirstArticleReviewSessionCommandResult:
    row = (
        db.execute(
            select(FirstArticleReviewSession)
            .where(FirstArticleReviewSession.id == session_id)
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if row is None:
        raise ValueError("Review session not found")
    if row.operator_user_id != operator.id:
        raise PermissionError("Current user cannot refresh this review session")
    if row.status == REVIEW_SESSION_APPROVED:
        raise ValueError("Approved review session cannot be refreshed")
    _, _, normalized_participant_user_ids, normalized_check_content, normalized_test_value = (
        _prepare_first_article_draft(
            db,
            order_id=row.order_id,
            order_process_id=row.order_process_id,
            pipeline_instance_id=row.pipeline_instance_id,
            template_id=row.template_id,
            check_content=check_content,
            test_value=test_value,
            participant_user_ids=participant_user_ids,
            operator=operator,
        )
    )
    token = _new_token()
    row.token_hash = _hash_token(token)
    row.status = REVIEW_SESSION_PENDING
    row.expires_at = _now() + REVIEW_TOKEN_TTL
    row.check_content = normalized_check_content
    row.test_value = normalized_test_value
    row.participant_user_ids = normalized_participant_user_ids
    row.reviewer_user_id = None
    row.review_result = None
    row.review_remark = None
    row.reviewed_at = None
    row.first_article_record_id = None
    db.commit()
    db.refresh(row)
    return FirstArticleReviewSessionCommandResult(
        session_id=row.id,
        review_url=_review_url_for_token(token),
        expires_at=row.expires_at,
        status=row.status,
    )


def get_first_article_review_session_status(
    db: Session,
    *,
    session_id: int,
    operator: User,
) -> FirstArticleReviewSessionCommandResult:
    row = db.get(FirstArticleReviewSession, session_id)
    if row is None:
        raise ValueError("Review session not found")
    if row.operator_user_id != operator.id:
        raise PermissionError("Current user cannot view this review session")
    _expire_if_needed(db, row)
    db.commit()
    db.refresh(row)
    return FirstArticleReviewSessionCommandResult(
        session_id=row.id,
        review_url=None,
        expires_at=row.expires_at,
        status=row.status,
        first_article_record_id=row.first_article_record_id,
        reviewer_user_id=row.reviewer_user_id,
        reviewed_at=row.reviewed_at,
        review_remark=row.review_remark,
    )


def get_first_article_review_session_detail(
    db: Session,
    *,
    token: str,
) -> FirstArticleReviewSessionDetailResult:
    row = (
        db.execute(
            select(FirstArticleReviewSession)
            .options(
                selectinload(FirstArticleReviewSession.order).selectinload(
                    ProductionOrder.product
                ),
                selectinload(FirstArticleReviewSession.order_process),
                selectinload(FirstArticleReviewSession.operator),
            )
            .where(FirstArticleReviewSession.token_hash == _hash_token(token))
        )
        .scalars()
        .first()
    )
    if row is None:
        raise ValueError("Review session not found")
    _expire_if_needed(db, row)
    if row.status != REVIEW_SESSION_PENDING:
        db.commit()
        raise ValueError("Review session is not pending")
    db.commit()
    order = row.order
    process_row = row.order_process
    operator = row.operator
    return FirstArticleReviewSessionDetailResult(
        session_id=row.id,
        status=row.status,
        expires_at=row.expires_at,
        order_id=row.order_id,
        order_code=order.order_code if order else "",
        product_name=order.product.name if order and order.product else "",
        order_process_id=row.order_process_id,
        process_name=process_row.process_name if process_row else "",
        operator_user_id=row.operator_user_id,
        operator_username=operator.username if operator else "",
        template_id=row.template_id,
        check_content=row.check_content,
        test_value=row.test_value,
        participant_user_ids=list(row.participant_user_ids or []),
        review_remark=row.review_remark,
    )


def submit_first_article_review_result(
    db: Session,
    *,
    token: str,
    review_result: str,
    review_remark: str | None,
    reviewer: User,
) -> FirstArticleReviewSessionCommandResult:
    normalized_result = review_result.strip().lower()
    if normalized_result not in {"passed", "failed"}:
        raise ValueError("Review result must be passed or failed")
    row = (
        db.execute(
            select(FirstArticleReviewSession)
            .where(FirstArticleReviewSession.token_hash == _hash_token(token))
            .with_for_update()
        )
        .scalars()
        .first()
    )
    if row is None:
        raise ValueError("Review session not found")
    _expire_if_needed(db, row)
    if row.status != REVIEW_SESSION_PENDING:
        raise ValueError("Review session is not pending")

    reviewed_at = _now()
    normalized_remark = _normalize_optional_text(review_remark)
    row.reviewer_user_id = reviewer.id
    row.review_result = normalized_result
    row.review_remark = normalized_remark
    row.reviewed_at = reviewed_at
    if normalized_result == "failed":
        row.status = REVIEW_SESSION_REJECTED
        db.commit()
        db.refresh(row)
        return FirstArticleReviewSessionCommandResult(
            session_id=row.id,
            review_url=None,
            expires_at=row.expires_at,
            status=row.status,
            first_article_record_id=None,
            reviewer_user_id=row.reviewer_user_id,
            reviewed_at=row.reviewed_at,
            review_remark=row.review_remark,
        )

    operator = db.get(User, row.operator_user_id)
    if operator is None:
        raise ValueError("Review session operator not found")
    submit_first_article(
        db,
        order_id=row.order_id,
        order_process_id=row.order_process_id,
        pipeline_instance_id=row.pipeline_instance_id,
        template_id=row.template_id,
        check_content=row.check_content,
        test_value=row.test_value,
        result="passed",
        participant_user_ids=list(row.participant_user_ids or []),
        verification_code="SCAN_REVIEW",
        remark=normalized_remark,
        operator=operator,
        assist_authorization_id=row.assist_authorization_id,
        skip_verification_code=True,
        reviewer_user_id=reviewer.id,
        reviewed_at=reviewed_at,
        review_remark=normalized_remark,
    )
    record = (
        db.execute(
            select(FirstArticleRecord)
            .where(
                FirstArticleRecord.order_id == row.order_id,
                FirstArticleRecord.order_process_id == row.order_process_id,
                FirstArticleRecord.reviewer_user_id == reviewer.id,
            )
            .order_by(FirstArticleRecord.id.desc())
        )
        .scalars()
        .first()
    )
    row.status = REVIEW_SESSION_APPROVED
    row.first_article_record_id = record.id if record is not None else None
    db.commit()
    db.refresh(row)
    return FirstArticleReviewSessionCommandResult(
        session_id=row.id,
        review_url=None,
        expires_at=row.expires_at,
        status=row.status,
        first_article_record_id=row.first_article_record_id,
        reviewer_user_id=row.reviewer_user_id,
        reviewed_at=row.reviewed_at,
        review_remark=row.review_remark,
    )

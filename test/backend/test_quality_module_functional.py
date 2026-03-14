from __future__ import annotations

import base64
import csv
import io
from datetime import date, datetime, time, timedelta

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.api.v1.endpoints import quality
from app.core.config import settings
from app.core.rbac import ROLE_OPERATOR, ROLE_QUALITY_ADMIN
from app.models.first_article_disposition import FirstArticleDisposition
from app.models.production_scrap_statistics import ProductionScrapStatistics
from app.models.repair_order import RepairOrder
from app.schemas.quality import (
    FirstArticleDispositionRequest,
    FirstArticleExportRequest,
    QualityStatsExportRequest,
)


def _decode_csv_rows(content_base64: str) -> list[list[str]]:
    csv_text = base64.b64decode(content_base64).decode("utf-8-sig")
    return list(csv.reader(io.StringIO(csv_text)))


def _build_quality_dataset(db, factory) -> dict[str, object]:
    day_1 = date.today() - timedelta(days=2)
    day_2 = date.today() - timedelta(days=1)
    old_day = date.today() - timedelta(days=10)

    stage_a = factory.stage(code="61", name="品质工段A", sort_order=1)
    stage_b = factory.stage(code="62", name="品质工段B", sort_order=2)
    process_a = factory.process(stage=stage_a, code="61-01", name="外观检验")
    process_b = factory.process(stage=stage_b, code="62-01", name="功能检验")

    operator_a = factory.user(
        username="quality_operator_a",
        role_codes=[ROLE_OPERATOR],
        processes=[process_a, process_b],
    )
    operator_b = factory.user(
        username="quality_operator_b",
        role_codes=[ROLE_OPERATOR],
        processes=[process_a],
    )
    quality_admin = factory.user(username="quality_admin", role_codes=[ROLE_QUALITY_ADMIN])

    product_a = factory.product(name="品质产品A")
    product_b = factory.product(name="品质产品B")

    order_a1 = factory.order(product=product_a, order_code="Q-ORD-A1", quantity=20, status="in_progress")
    order_a2 = factory.order(product=product_a, order_code="Q-ORD-A2", quantity=15, status="completed")
    order_b1 = factory.order(product=product_b, order_code="Q-ORD-B1", quantity=12, status="in_progress")
    order_old = factory.order(product=product_a, order_code="Q-ORD-OLD", quantity=6, status="completed")

    order_process_a1 = factory.order_process(
        order=order_a1,
        process=process_a,
        stage=stage_a,
        process_order=1,
        status="in_progress",
        visible_quantity=20,
        completed_quantity=6,
    )
    order_process_a2 = factory.order_process(
        order=order_a2,
        process=process_a,
        stage=stage_a,
        process_order=1,
        status="completed",
        visible_quantity=15,
        completed_quantity=15,
    )
    order_process_b1 = factory.order_process(
        order=order_b1,
        process=process_b,
        stage=stage_b,
        process_order=1,
        status="in_progress",
        visible_quantity=12,
        completed_quantity=5,
    )
    order_process_old = factory.order_process(
        order=order_old,
        process=process_a,
        stage=stage_a,
        process_order=1,
        status="completed",
        visible_quantity=6,
        completed_quantity=6,
    )

    day_1_pass = factory.first_article(
        order=order_a1,
        process_row=order_process_a1,
        operator=operator_a,
        verification_date=day_1,
        verification_code="VC-DAY1",
        result="passed",
    )
    day_1_pass.remark = "首件通过"
    day_1_pass.created_at = datetime.combine(day_1, time(9, 0, 0))
    day_1_pass.updated_at = day_1_pass.created_at

    day_1_failed = factory.first_article(
        order=order_a2,
        process_row=order_process_a2,
        operator=operator_b,
        verification_date=day_1,
        verification_code="VC-DAY1",
        result="failed",
    )
    day_1_failed.remark = "尺寸偏差"
    day_1_failed.created_at = datetime.combine(day_1, time(10, 30, 0))
    day_1_failed.updated_at = day_1_failed.created_at

    day_2_pass = factory.first_article(
        order=order_b1,
        process_row=order_process_b1,
        operator=operator_a,
        verification_date=day_2,
        verification_code="VC-DAY2",
        result="passed",
    )
    day_2_pass.remark = "复测通过"
    day_2_pass.created_at = datetime.combine(day_2, time(13, 15, 0))
    day_2_pass.updated_at = day_2_pass.created_at

    old_pass = factory.first_article(
        order=order_old,
        process_row=order_process_old,
        operator=operator_b,
        verification_date=old_day,
        verification_code="VC-OLD",
        result="passed",
    )
    old_pass.remark = "历史记录"
    old_pass.created_at = datetime.combine(old_day, time(8, 0, 0))
    old_pass.updated_at = old_pass.created_at

    factory.verification_code(verify_date=day_1, code="VC-DAY1", created_by=quality_admin)

    db.add(
        FirstArticleDisposition(
            first_article_record_id=day_1_failed.id,
            disposition_opinion="初始判定不通过",
            disposition_user_id=quality_admin.id,
            disposition_username=quality_admin.username,
            disposition_at=datetime.combine(day_1, time(11, 0, 0)),
            recheck_result="failed",
            final_judgment="reject",
        )
    )

    db.add(
        ProductionScrapStatistics(
            order_id=order_a1.id,
            order_code=order_a1.order_code,
            product_id=product_a.id,
            product_name=product_a.name,
            process_id=order_process_a1.id,
            process_code=order_process_a1.process_code,
            process_name=order_process_a1.process_name,
            scrap_reason="外观划伤",
            scrap_quantity=2,
            last_scrap_time=datetime.combine(day_1, time(12, 0, 0)),
            progress="applied",
            applied_at=datetime.combine(day_1, time(12, 10, 0)),
        )
    )
    db.add(
        ProductionScrapStatistics(
            order_id=order_b1.id,
            order_code=order_b1.order_code,
            product_id=product_b.id,
            product_name=product_b.name,
            process_id=order_process_b1.id,
            process_code=order_process_b1.process_code,
            process_name=order_process_b1.process_name,
            scrap_reason="功能异常",
            scrap_quantity=3,
            last_scrap_time=datetime.combine(day_2, time(15, 0, 0)),
            progress="pending_apply",
            applied_at=None,
        )
    )

    db.add(
        RepairOrder(
            repair_order_code="RO-QA-001",
            source_order_id=order_a1.id,
            source_order_code=order_a1.order_code,
            product_id=product_a.id,
            product_name=product_a.name,
            source_order_process_id=order_process_a1.id,
            source_process_code=order_process_a1.process_code,
            source_process_name=order_process_a1.process_name,
            sender_user_id=operator_a.id,
            sender_username=operator_a.username,
            production_quantity=20,
            repair_quantity=2,
            repaired_quantity=1,
            scrap_quantity=1,
            scrap_replenished=False,
            repair_time=datetime.combine(day_1, time(16, 0, 0)),
            status="completed",
            completed_at=datetime.combine(day_1, time(17, 0, 0)),
            repair_operator_user_id=operator_b.id,
            repair_operator_username=operator_b.username,
        )
    )
    db.add(
        RepairOrder(
            repair_order_code="RO-QA-002",
            source_order_id=order_b1.id,
            source_order_code=order_b1.order_code,
            product_id=product_b.id,
            product_name=product_b.name,
            source_order_process_id=order_process_b1.id,
            source_process_code=order_process_b1.process_code,
            source_process_name=order_process_b1.process_name,
            sender_user_id=operator_a.id,
            sender_username=operator_a.username,
            production_quantity=12,
            repair_quantity=1,
            repaired_quantity=0,
            scrap_quantity=0,
            scrap_replenished=False,
            repair_time=datetime.combine(day_2, time(16, 30, 0)),
            status="in_repair",
            completed_at=None,
            repair_operator_user_id=operator_a.id,
            repair_operator_username=operator_a.username,
        )
    )

    db.commit()
    return {
        "day_1": day_1,
        "day_2": day_2,
        "quality_admin": quality_admin,
        "day_1_pass_id": day_1_pass.id,
        "day_1_failed_id": day_1_failed.id,
        "day_2_pass_id": day_2_pass.id,
        "product_a_id": product_a.id,
        "product_b_id": product_b.id,
    }


def _assert_bad_date_range(callable_obj) -> None:
    with pytest.raises(HTTPException) as exc_info:
        callable_obj()
    assert exc_info.value.status_code == 400
    assert "start_date cannot be greater than end_date" in str(exc_info.value.detail)


def test_quality_first_article_flow_endpoints(db, factory) -> None:
    fixture = _build_quality_dataset(db, factory)
    day_1 = fixture["day_1"]
    qa_admin = fixture["quality_admin"]

    list_resp = quality.get_first_articles_api(
        query_date=day_1,
        keyword="Q-ORD-A",
        result="passed",
        page=1,
        page_size=20,
        db=db,
        _=qa_admin,
    )
    assert list_resp.data.total == 1
    assert list_resp.data.verification_code == "VC-DAY1"
    assert list_resp.data.verification_code_source == "stored"
    assert list_resp.data.items[0].id == fixture["day_1_pass_id"]
    assert list_resp.data.items[0].result == "passed"

    detail_resp = quality.get_first_article_detail_api(
        record_id=fixture["day_1_failed_id"],
        db=db,
        _=qa_admin,
    )
    assert detail_resp.data.order_code == "Q-ORD-A2"
    assert detail_resp.data.result == "failed"
    assert detail_resp.data.disposition_opinion == "初始判定不通过"
    assert detail_resp.data.final_judgment == "reject"

    export_resp = quality.export_first_articles_api(
        FirstArticleExportRequest(
            query_date=day_1,
            keyword="Q-ORD-A",
            result="failed",
        ),
        db=db,
        _=qa_admin,
    )
    csv_rows = _decode_csv_rows(export_resp.data.content_base64)
    assert export_resp.data.total_rows == 1
    assert csv_rows[0] == [
        "提交时间",
        "订单号",
        "产品",
        "工序编码",
        "工序名称",
        "操作员",
        "结果",
        "校验日期",
        "校验码",
        "备注",
    ]
    assert csv_rows[1][1] == "Q-ORD-A2"
    assert csv_rows[1][6] == "不通过"

    created_disposition_resp = quality.submit_disposition_api(
        record_id=fixture["day_2_pass_id"],
        payload=FirstArticleDispositionRequest(
            disposition_opinion="补充复判记录",
            recheck_result="passed",
            final_judgment="accept",
        ),
        db=db,
        current_user=qa_admin,
    )
    assert created_disposition_resp.data.disposition_opinion == "补充复判记录"
    assert created_disposition_resp.data.recheck_result == "passed"
    assert created_disposition_resp.data.final_judgment == "accept"

    updated_disposition_resp = quality.submit_disposition_api(
        record_id=fixture["day_1_failed_id"],
        payload=FirstArticleDispositionRequest(
            disposition_opinion="复检后判定返工",
            recheck_result="failed",
            final_judgment="rework",
        ),
        db=db,
        current_user=qa_admin,
    )
    assert updated_disposition_resp.data.disposition_opinion == "复检后判定返工"
    assert updated_disposition_resp.data.recheck_result == "failed"
    assert updated_disposition_resp.data.final_judgment == "rework"

    stored_disposition = db.execute(
        select(FirstArticleDisposition).where(
            FirstArticleDisposition.first_article_record_id == fixture["day_1_failed_id"]
        )
    ).scalars().first()
    assert stored_disposition is not None
    assert stored_disposition.disposition_username == qa_admin.username
    assert stored_disposition.final_judgment == "rework"

    with pytest.raises(HTTPException) as exc_info:
        quality.get_first_article_detail_api(record_id=999999, db=db, _=qa_admin)
    assert exc_info.value.status_code == 404


def test_quality_stats_trend_and_export_endpoints(db, factory) -> None:
    fixture = _build_quality_dataset(db, factory)
    day_1 = fixture["day_1"]
    day_2 = fixture["day_2"]
    qa_admin = fixture["quality_admin"]

    overview_resp = quality.get_quality_overview_api(
        start_date=day_1,
        end_date=day_2,
        db=db,
        _=qa_admin,
    )
    assert overview_resp.data.first_article_total == 3
    assert overview_resp.data.passed_total == 2
    assert overview_resp.data.failed_total == 1
    assert overview_resp.data.pass_rate_percent == 66.67
    assert overview_resp.data.covered_order_count == 3
    assert overview_resp.data.covered_process_count == 2
    assert overview_resp.data.covered_operator_count == 2

    process_resp = quality.get_quality_process_stats_api(
        start_date=day_1,
        end_date=day_2,
        db=db,
        _=qa_admin,
    )
    process_map = {item.process_code: item for item in process_resp.data.items}
    assert set(process_map.keys()) == {"61-01", "62-01"}
    assert process_map["61-01"].first_article_total == 2
    assert process_map["61-01"].failed_total == 1
    assert process_map["62-01"].first_article_total == 1
    assert process_map["62-01"].passed_total == 1

    operator_resp = quality.get_quality_operator_stats_api(
        start_date=day_1,
        end_date=day_2,
        db=db,
        _=qa_admin,
    )
    operator_map = {item.operator_username: item for item in operator_resp.data.items}
    assert operator_map["quality_operator_a"].first_article_total == 2
    assert operator_map["quality_operator_a"].passed_total == 2
    assert operator_map["quality_operator_b"].first_article_total == 1
    assert operator_map["quality_operator_b"].failed_total == 1

    product_resp = quality.get_quality_product_stats_api(
        start_date=day_1,
        end_date=day_2,
        db=db,
        _=qa_admin,
    )
    product_map = {item.product_id: item for item in product_resp.data.items}
    assert product_map[fixture["product_a_id"]].first_article_total == 2
    assert product_map[fixture["product_a_id"]].scrap_total == 2
    assert product_map[fixture["product_a_id"]].repair_order_count == 1
    assert product_map[fixture["product_b_id"]].first_article_total == 1
    assert product_map[fixture["product_b_id"]].scrap_total == 3
    assert product_map[fixture["product_b_id"]].repair_order_count == 1

    trend_resp = quality.get_quality_trend_api(
        start_date=day_1,
        end_date=day_2,
        db=db,
        _=qa_admin,
    )
    assert len(trend_resp.data.items) == 2
    trend_map = {item.stat_date: item for item in trend_resp.data.items}
    assert trend_map[day_1].first_article_total == 2
    assert trend_map[day_1].failed_total == 1
    assert trend_map[day_1].scrap_total == 2
    assert trend_map[day_2].first_article_total == 1
    assert trend_map[day_2].passed_total == 1
    assert trend_map[day_2].scrap_total == 3

    export_resp = quality.export_quality_stats_api(
        payload=QualityStatsExportRequest(start_date=day_1, end_date=day_2),
        db=db,
        _=qa_admin,
    )
    assert export_resp.data.total_rows == len(process_resp.data.items) + len(operator_resp.data.items)
    stats_csv = _decode_csv_rows(export_resp.data.content_base64)
    assert stats_csv[0] == ["== 品质总览 =="]
    assert stats_csv[4] == ["== 工序统计 =="]
    assert any(row and row[0] == "== 人员统计 ==" for row in stats_csv)


def test_quality_verification_code_source_rules(db, factory) -> None:
    stage = factory.stage(code="63", name="校验来源工段", sort_order=1)
    process = factory.process(stage=stage, code="63-01", name="校验来源工序")
    operator = factory.user(
        username="quality_source_operator",
        role_codes=[ROLE_OPERATOR],
        processes=[process],
    )
    qa_admin = factory.user(username="quality_source_admin", role_codes=[ROLE_QUALITY_ADMIN])
    product = factory.product(name="校验来源产品")
    order = factory.order(product=product, order_code="Q-SOURCE-1", quantity=5, status="in_progress")
    order_process = factory.order_process(
        order=order,
        process=process,
        stage=stage,
        process_order=1,
        status="in_progress",
        visible_quantity=5,
        completed_quantity=1,
    )

    yesterday = date.today() - timedelta(days=1)
    record = factory.first_article(
        order=order,
        process_row=order_process,
        operator=operator,
        verification_date=yesterday,
        verification_code="VC-YESTERDAY",
        result="passed",
    )
    record.created_at = datetime.combine(yesterday, time(9, 30, 0))
    record.updated_at = record.created_at
    db.commit()

    today_resp = quality.get_first_articles_api(
        query_date=date.today(),
        keyword=None,
        result=None,
        page=1,
        page_size=20,
        db=db,
        _=qa_admin,
    )
    assert today_resp.data.verification_code_source == "default"
    assert today_resp.data.verification_code == settings.production_default_verification_code

    yesterday_resp = quality.get_first_articles_api(
        query_date=yesterday,
        keyword=None,
        result=None,
        page=1,
        page_size=20,
        db=db,
        _=qa_admin,
    )
    assert yesterday_resp.data.verification_code is None
    assert yesterday_resp.data.verification_code_source == "none"


def test_quality_date_range_validation(db, factory) -> None:
    qa_admin = factory.user(username="quality_range_admin", role_codes=[ROLE_QUALITY_ADMIN])
    start = date(2026, 3, 12)
    end = date(2026, 3, 10)

    _assert_bad_date_range(
        lambda: quality.get_quality_overview_api(
            start_date=start,
            end_date=end,
            db=db,
            _=qa_admin,
        )
    )
    _assert_bad_date_range(
        lambda: quality.get_quality_process_stats_api(
            start_date=start,
            end_date=end,
            db=db,
            _=qa_admin,
        )
    )
    _assert_bad_date_range(
        lambda: quality.get_quality_operator_stats_api(
            start_date=start,
            end_date=end,
            db=db,
            _=qa_admin,
        )
    )
    _assert_bad_date_range(
        lambda: quality.get_quality_product_stats_api(
            start_date=start,
            end_date=end,
            db=db,
            _=qa_admin,
        )
    )
    _assert_bad_date_range(
        lambda: quality.export_quality_stats_api(
            payload=QualityStatsExportRequest(start_date=start, end_date=end),
            db=db,
            _=qa_admin,
        )
    )
    _assert_bad_date_range(
        lambda: quality.get_quality_trend_api(
            start_date=start,
            end_date=end,
            db=db,
            _=qa_admin,
        )
    )

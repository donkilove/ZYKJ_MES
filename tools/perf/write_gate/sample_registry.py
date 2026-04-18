from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from functools import lru_cache
from threading import Lock
from pathlib import Path
import sys
from types import SimpleNamespace
from typing import Any
from uuid import uuid4

from sqlalchemy import or_, select
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool

from tools.perf.write_gate.sample_runtime import SampleHandler


RUNTIME_ORDER_REFS_KEY = "__write_gate_runtime_order_refs__"
RUNTIME_TEMPLATE_IDS_KEY = "__write_gate_runtime_template_ids__"
RUNTIME_STAGE_IDS_KEY = "__write_gate_runtime_stage_ids__"
RUNTIME_PROCESS_CODE_KEY = "__write_gate_runtime_process_code__"
RUNTIME_PRODUCT_IDS_KEY = "__write_gate_runtime_product_ids__"
RUNTIME_EQUIPMENT_REFS_KEY = "__write_gate_runtime_equipment_refs__"
RUNTIME_QUALITY_REFS_KEY = "__write_gate_runtime_quality_refs__"
RUNTIME_AUTH_REFS_KEY = "__write_gate_runtime_auth_refs__"
RUNTIME_MESSAGE_IDS_KEY = "__write_gate_runtime_message_ids__"
RUNTIME_USER_MGMT_REFS_KEY = "__write_gate_runtime_user_mgmt_refs__"

PROCESS_CODE_RESERVATION_LOCK = Lock()
RESERVED_PROCESS_CODES: set[str] = set()


def _ensure_backend_import_path() -> None:
    repo_root = Path(__file__).resolve().parents[3]
    backend_dir = repo_root / "backend"
    if str(backend_dir) not in sys.path:
        sys.path.insert(0, str(backend_dir))
    if str(repo_root) not in sys.path:
        sys.path.insert(0, str(repo_root))


def _build_perf_session_factory(database_url: str):
    engine = create_engine(
        database_url,
        poolclass=NullPool,
        pool_pre_ping=True,
        future=True,
    )
    return sessionmaker(
        autocommit=False,
        autoflush=False,
        bind=engine,
        expire_on_commit=False,
    )


@lru_cache(maxsize=1)
def _backend_dependencies() -> SimpleNamespace:
    _ensure_backend_import_path()

    from app.core.config import settings
    from app.core.security import get_password_hash
    from app.db.session import SessionLocal
    from app.models.equipment import Equipment
    from app.models.equipment_rule import EquipmentRule
    from app.models.equipment_runtime_parameter import EquipmentRuntimeParameter
    from app.models.first_article_disposition import FirstArticleDisposition
    from app.models.first_article_disposition_history import (
        FirstArticleDispositionHistory,
    )
    from app.models.first_article_record import FirstArticleRecord
    from app.models.maintenance_item import MaintenanceItem
    from app.models.maintenance_plan import MaintenancePlan
    from app.models.maintenance_record import MaintenanceRecord
    from app.models.maintenance_work_order import MaintenanceWorkOrder
    from app.models.message import Message
    from app.models.production_scrap_statistics import ProductionScrapStatistics
    from app.models.product_process_template import ProductProcessTemplate
    from app.models.product import Product
    from app.models.process import Process
    from app.models.process_stage import ProcessStage
    from app.models.production_order import ProductionOrder
    from app.models.production_order_process import ProductionOrderProcess
    from app.models.production_sub_order import ProductionSubOrder
    from app.models.registration_request import RegistrationRequest
    from app.models.role import Role
    from app.models.repair_cause import RepairCause
    from app.models.repair_defect_phenomenon import RepairDefectPhenomenon
    from app.models.repair_order import RepairOrder
    from app.models.repair_return_route import RepairReturnRoute
    from app.models.supplier import Supplier
    from app.models.user import User
    from app.models.user_session import UserSession
    from app.schemas.equipment_rule import (
        EquipmentRuleUpsertRequest,
        EquipmentRuntimeParameterUpsertRequest,
    )
    from app.schemas.message import AnnouncementPublishRequest
    from app.schemas.role import RoleCreate
    from app.schemas.user import UserCreate
    from app.services.craft_service import (
        archive_template,
        create_process,
        create_system_master_template,
        create_template,
        get_system_master_template,
        publish_template,
        resolve_user_stage_codes,
    )
    from app.services.equipment_rule_service import (
        create_equipment_rule,
        create_runtime_parameter,
    )
    from app.services.equipment_service import (
        complete_work_order,
        create_equipment,
        create_maintenance_item,
        create_maintenance_plan,
        generate_work_order_for_plan,
        start_work_order,
    )
    from app.services.perf_sample_seed_service import (
        reset_runtime_samples,
        seed_production_craft_samples,
    )
    from app.services.product_service import (
        activate_product_version,
        copy_product_version,
        create_product,
        get_draft_revision,
        get_effective_revision,
        update_product_version_parameters,
    )
    from app.services.message_service import publish_announcement
    from app.services.production_execution_service import submit_first_article
    from app.services.quality_supplier_service import create_supplier
    from app.services.role_service import create_role
    from app.services.session_service import create_or_reuse_user_session
    from app.services.user_service import (
        create_user,
        delete_user,
        submit_registration_request,
    )

    return SimpleNamespace(
        settings=settings,
        get_password_hash=get_password_hash,
        SessionLocal=SessionLocal,
        PerfSessionLocal=_build_perf_session_factory(settings.database_url),
        Equipment=Equipment,
        EquipmentRule=EquipmentRule,
        EquipmentRuleUpsertRequest=EquipmentRuleUpsertRequest,
        EquipmentRuntimeParameter=EquipmentRuntimeParameter,
        EquipmentRuntimeParameterUpsertRequest=EquipmentRuntimeParameterUpsertRequest,
        FirstArticleDisposition=FirstArticleDisposition,
        FirstArticleDispositionHistory=FirstArticleDispositionHistory,
        FirstArticleRecord=FirstArticleRecord,
        MaintenanceItem=MaintenanceItem,
        MaintenancePlan=MaintenancePlan,
        MaintenanceRecord=MaintenanceRecord,
        MaintenanceWorkOrder=MaintenanceWorkOrder,
        Message=Message,
        ProductionScrapStatistics=ProductionScrapStatistics,
        Product=Product,
        ProductProcessTemplate=ProductProcessTemplate,
        Process=Process,
        ProcessStage=ProcessStage,
        ProductionOrder=ProductionOrder,
        ProductionOrderProcess=ProductionOrderProcess,
        ProductionSubOrder=ProductionSubOrder,
        RegistrationRequest=RegistrationRequest,
        Role=Role,
        RepairCause=RepairCause,
        RepairDefectPhenomenon=RepairDefectPhenomenon,
        RepairOrder=RepairOrder,
        RepairReturnRoute=RepairReturnRoute,
        Supplier=Supplier,
        User=User,
        UserSession=UserSession,
        AnnouncementPublishRequest=AnnouncementPublishRequest,
        RoleCreate=RoleCreate,
        UserCreate=UserCreate,
        complete_work_order=complete_work_order,
        create_equipment=create_equipment,
        create_equipment_rule=create_equipment_rule,
        create_maintenance_item=create_maintenance_item,
        create_maintenance_plan=create_maintenance_plan,
        create_role=create_role,
        create_or_reuse_user_session=create_or_reuse_user_session,
        create_supplier=create_supplier,
        create_process=create_process,
        create_system_master_template=create_system_master_template,
        create_template=create_template,
        create_runtime_parameter=create_runtime_parameter,
        create_user=create_user,
        delete_user=delete_user,
        generate_work_order_for_plan=generate_work_order_for_plan,
        get_system_master_template=get_system_master_template,
        publish_announcement=publish_announcement,
        publish_template=publish_template,
        reset_runtime_samples=reset_runtime_samples,
        resolve_user_stage_codes=resolve_user_stage_codes,
        seed_production_craft_samples=seed_production_craft_samples,
        start_work_order=start_work_order,
        submit_registration_request=submit_registration_request,
        archive_template=archive_template,
        activate_product_version=activate_product_version,
        copy_product_version=copy_product_version,
        create_product=create_product,
        get_draft_revision=get_draft_revision,
        get_effective_revision=get_effective_revision,
        submit_first_article=submit_first_article,
        update_product_version_parameters=update_product_version_parameters,
    )


def _new_run_id(prefix: str) -> str:
    return f"{prefix}-{uuid4().hex[:12]}"


def _append_context_refs(
    sample_context: dict[str, Any],
    *,
    key: str,
    refs: list[Any],
) -> None:
    bucket = sample_context.setdefault(key, [])
    if not isinstance(bucket, list):
        sample_context[key] = list(refs)
        return
    bucket.extend(refs)


def _require_context_value(sample_context: dict[str, Any], key: str) -> Any:
    if key not in sample_context:
        raise KeyError(f"缺少运行时样本上下文字段: {key}")
    return sample_context[key]


@dataclass(slots=True)
class NoOpSampleHandler(SampleHandler):
    sample_name: str

    def prepare(self, sample_context: dict[str, Any] | None = None) -> None:
        del sample_context
        return None

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any] | None = None,
    ) -> None:
        del strategy, sample_context
        return None


@dataclass(slots=True)
class BaselineOrderCreateReadyHandler(SampleHandler):
    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        try:
            result = deps.seed_production_craft_samples(
                db,
                run_id="baseline",
                cleanup_stale_perf_artifacts=False,
            )
            sample_context.update(result.context)
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy, sample_context
        return None


@dataclass(slots=True)
class RuntimeTemplateReadyHandler(SampleHandler):
    publish_before_request: bool = False
    archive_before_request: bool = False

    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        try:
            baseline = deps.seed_production_craft_samples(
                db,
                run_id="baseline",
                cleanup_stale_perf_artifacts=False,
            )
            admin_user = db.get(deps.User, int(baseline.context["admin_user_id"]))
            if admin_user is None:
                raise ValueError("管理员账号不存在，无法创建运行时模板")

            run_id = _new_run_id("tpl")
            template_name = f"PERF-TPL-{run_id.upper()}"
            template = deps.create_template(
                db,
                product_id=int(baseline.context["product_id"]),
                template_name=template_name,
                is_default=False,
                remark="性能压测运行时模板",
                steps=[
                    {
                        "step_order": 1,
                        "stage_id": int(baseline.context["stage_id"]),
                        "process_id": int(baseline.context["process_id"]),
                    },
                    {
                        "step_order": 2,
                        "stage_id": int(baseline.context["stage_id"]),
                        "process_id": int(baseline.context["secondary_process_id"]),
                    },
                ],
                operator=admin_user,
            )
            if self.publish_before_request or self.archive_before_request:
                template, _ = deps.publish_template(
                    db,
                    template=template,
                    operator=admin_user,
                    apply_order_sync=False,
                    confirmed=True,
                    expected_version=template.version,
                    note="性能压测运行时模板预发布",
                )
            if self.archive_before_request:
                template = deps.archive_template(
                    db,
                    template=template,
                    operator=admin_user,
                )

            sample_context["craft_template_id"] = template.id
            sample_context["craft_template_name"] = template.template_name
            sample_context["craft_template_version"] = template.version
            sample_context["craft_template_published_version"] = template.published_version
            _append_context_refs(
                sample_context,
                key=RUNTIME_TEMPLATE_IDS_KEY,
                refs=[template.id],
            )
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        deps = _backend_dependencies()
        template_ids = sample_context.pop(RUNTIME_TEMPLATE_IDS_KEY, [])
        if not template_ids:
            return None

        db = deps.PerfSessionLocal()
        try:
            for template_id in reversed(template_ids):
                row = db.get(deps.ProductProcessTemplate, int(template_id))
                if row is not None:
                    db.delete(row)
            db.commit()
        finally:
            db.close()
        return None


@dataclass(slots=True)
class RuntimeStageDeleteReadyHandler(SampleHandler):
    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        try:
            run_id = _new_run_id("stg")
            stage_code = f"PERF-STAGE-DEL-{run_id.upper()}"[:64]
            row = deps.ProcessStage(
                code=stage_code,
                name=f"性能压测删除工段-{run_id}"[:128],
                sort_order=999,
                is_enabled=True,
                remark="性能压测运行时删除工段样本",
            )
            db.add(row)
            db.commit()
            db.refresh(row)
            sample_context["runtime_stage_id"] = int(row.id)
            sample_context["runtime_stage_code"] = row.code
            _append_context_refs(
                sample_context,
                key=RUNTIME_STAGE_IDS_KEY,
                refs=[int(row.id)],
            )
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        deps = _backend_dependencies()
        stage_ids = sample_context.pop(RUNTIME_STAGE_IDS_KEY, [])
        if not stage_ids:
            return None
        db = deps.PerfSessionLocal()
        try:
            for stage_id in reversed(stage_ids):
                row = db.get(deps.ProcessStage, int(stage_id))
                if row is not None:
                    db.delete(row)
            db.commit()
        finally:
            db.close()
        return None


@dataclass(slots=True)
class RuntimeOrderReadyHandler(SampleHandler):
    promote_to_in_progress: bool = False

    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        try:
            run_id = _new_run_id("order")
            result = deps.seed_production_craft_samples(
                db,
                run_id=run_id,
                mode="runtime",
                cleanup_stale_perf_artifacts=False,
            )
            runtime_order_id = int(_require_context_value(result.context, "runtime_order_id"))
            runtime_order = db.get(deps.ProductionOrder, runtime_order_id)
            if runtime_order is None:
                raise ValueError("运行时生产订单创建失败")

            process_rows = (
                db.execute(
                    select(deps.ProductionOrderProcess)
                    .where(deps.ProductionOrderProcess.order_id == runtime_order_id)
                    .order_by(
                        deps.ProductionOrderProcess.process_order.asc(),
                        deps.ProductionOrderProcess.id.asc(),
                    )
                )
                .scalars()
                .all()
            )
            if len(process_rows) < 2:
                raise ValueError("运行时生产订单缺少必要工序，无法支撑写门禁")

            runtime_sub_order = (
                db.execute(
                    select(deps.ProductionSubOrder)
                    .where(
                        deps.ProductionSubOrder.order_process_id == process_rows[0].id,
                        deps.ProductionSubOrder.is_visible.is_(True),
                        deps.ProductionSubOrder.assigned_quantity > 0,
                    )
                    .order_by(deps.ProductionSubOrder.id.asc())
                )
                .scalars()
                .first()
            )
            if runtime_sub_order is None:
                raise ValueError("运行时订单未生成可用子工单，无法支撑写门禁")
            sample_context["runtime_operator_user_id"] = int(
                runtime_sub_order.operator_user_id
            )

            if self.promote_to_in_progress:
                operator_user = db.get(
                    deps.User,
                    int(runtime_sub_order.operator_user_id),
                )
                if operator_user is None:
                    raise ValueError("运行时子工单操作员不存在，无法推进运行中态")
                deps.submit_first_article(
                    db,
                    order_id=runtime_order_id,
                    order_process_id=process_rows[0].id,
                    pipeline_instance_id=None,
                    template_id=int(result.context["first_article_template_id"]),
                    check_content="运行时首件检查",
                    test_value="通过",
                    result="passed",
                    participant_user_ids=[operator_user.id],
                    verification_code=str(result.context["verification_code"]),
                    remark="性能压测运行时样本预热",
                    operator=operator_user,
                )

            sample_context["production_order_id"] = runtime_order_id
            sample_context["production_order_code"] = runtime_order.order_code
            sample_context["order_process_id"] = process_rows[0].id
            sample_context["secondary_order_process_id"] = process_rows[1].id
            _append_context_refs(
                sample_context,
                key=RUNTIME_ORDER_REFS_KEY,
                refs=list(result.run_scoped_refs),
            )
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        deps = _backend_dependencies()
        runtime_refs = sample_context.pop(RUNTIME_ORDER_REFS_KEY, [])
        if not runtime_refs:
            return None

        db = deps.PerfSessionLocal()
        try:
            deps.reset_runtime_samples(
                db,
                list(runtime_refs),
                restore_strategy=strategy,
            )
        finally:
            db.close()
        return None


def _reserve_runtime_process_code(*, stage_code: str, existing_codes: set[str]) -> str:
    with PROCESS_CODE_RESERVATION_LOCK:
        for serial in range(3, 100):
            candidate = f"{stage_code}-{serial:02d}"
            if candidate in existing_codes or candidate in RESERVED_PROCESS_CODES:
                continue
            RESERVED_PROCESS_CODES.add(candidate)
            return candidate
    raise ValueError("未找到可用工序编码序号，无法执行 craft 运行时工序样本")


@dataclass(slots=True)
class CraftProcessCreateReadyHandler(SampleHandler):
    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        stage_id = int(_require_context_value(sample_context, "stage_id"))
        stage_code = str(_require_context_value(sample_context, "stage_code"))
        db = deps.PerfSessionLocal()
        try:
            existing_codes = set(
                db.execute(
                    select(deps.Process.code).where(
                        deps.Process.stage_id == stage_id
                    )
                )
                .scalars()
                .all()
            )
        finally:
            db.close()

        candidate = _reserve_runtime_process_code(
            stage_code=stage_code,
            existing_codes=existing_codes,
        )

        sample_context["runtime_process_code"] = candidate
        sample_context["runtime_process_name"] = candidate
        sample_context[RUNTIME_PROCESS_CODE_KEY] = candidate

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        reserved_code = sample_context.pop(RUNTIME_PROCESS_CODE_KEY, None)
        if not isinstance(reserved_code, str):
            return None
        with PROCESS_CODE_RESERVATION_LOCK:
            RESERVED_PROCESS_CODES.discard(reserved_code)
        return None


@dataclass(slots=True)
class CraftProcessRuntimeReadyHandler(SampleHandler):
    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        stage_id = int(_require_context_value(sample_context, "stage_id"))
        stage_code = str(_require_context_value(sample_context, "stage_code"))
        db = deps.PerfSessionLocal()
        try:
            baseline = deps.seed_production_craft_samples(
                db,
                run_id="baseline",
                cleanup_stale_perf_artifacts=False,
            )
            admin_user = db.get(deps.User, int(baseline.context["admin_user_id"]))
            if admin_user is None:
                raise ValueError("管理员账号不存在，无法创建运行时工序")
            existing_codes = set(
                db.execute(
                    select(deps.Process.code).where(deps.Process.stage_id == stage_id)
                )
                .scalars()
                .all()
            )
            runtime_code = _reserve_runtime_process_code(
                stage_code=stage_code,
                existing_codes=existing_codes,
            )
            row = deps.create_process(
                db,
                code=runtime_code,
                name=runtime_code,
                stage_id=stage_id,
                remark="性能压测运行时工序",
            )
            sample_context["runtime_process_id"] = int(row.id)
            sample_context["runtime_process_code"] = row.code
            sample_context["runtime_process_name"] = row.name
            sample_context[RUNTIME_PROCESS_CODE_KEY] = row.code
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        deps = _backend_dependencies()
        process_id = sample_context.pop("runtime_process_id", None)
        runtime_code = sample_context.pop(RUNTIME_PROCESS_CODE_KEY, None)
        db = deps.PerfSessionLocal()
        try:
            if process_id is not None:
                row = db.get(deps.Process, int(process_id))
                if row is not None:
                    db.delete(row)
                    db.commit()
        finally:
            db.close()
        if isinstance(runtime_code, str):
            with PROCESS_CODE_RESERVATION_LOCK:
                RESERVED_PROCESS_CODES.discard(runtime_code)
        return None


@dataclass(slots=True)
class SystemMasterTemplateReadyHandler(SampleHandler):
    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        try:
            existing = deps.get_system_master_template(db)
            if existing is not None:
                return None
            baseline = deps.seed_production_craft_samples(
                db,
                run_id="baseline",
                cleanup_stale_perf_artifacts=False,
            )
            admin_user = db.get(deps.User, int(baseline.context["admin_user_id"]))
            if admin_user is None:
                raise ValueError("管理员账号不存在，无法准备系统母版")
            deps.create_system_master_template(
                db,
                steps=[
                    {
                        "step_order": 1,
                        "stage_id": int(baseline.context["stage_id"]),
                        "process_id": int(baseline.context["process_id"]),
                    }
                ],
                operator=admin_user,
            )
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy, sample_context
        return None


@dataclass(slots=True)
class RuntimeProductVersionReadyHandler(SampleHandler):
    ensure_draft: bool = False

    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        product_id_for_cleanup: int | None = None
        try:
            baseline = deps.seed_production_craft_samples(
                db,
                run_id="baseline",
                cleanup_stale_perf_artifacts=False,
            )
            admin_user = db.get(deps.User, int(baseline.context["admin_user_id"]))
            if admin_user is None:
                raise ValueError("管理员账号不存在，无法创建运行时产品样本")

            product = deps.create_product(
                db,
                name=f"PERF-PRODUCT-{_new_run_id('prd').upper()}",
                category="贴片",
                remark="性能压测运行时产品",
                operator=admin_user,
            )
            product_id_for_cleanup = int(product.id)
            # 先落稳初始草稿和当前参数，再切换到后续版本状态，避免同事务内重复写当前参数。
            db.commit()
            db.refresh(product)
            effective_revision = deps.activate_product_version(
                db,
                product=product,
                version=1,
                confirmed=True,
                expected_effective_version=0,
                operator=admin_user,
            )
            current_version = effective_revision.version
            effective_version = effective_revision.version

            if self.ensure_draft:
                draft_revision = deps.copy_product_version(
                    db,
                    product=product,
                    source_version=effective_version,
                    operator=admin_user,
                )
                deps.update_product_version_parameters(
                    db,
                    product=product,
                    version=draft_revision.version,
                    items=[
                        (
                            "产品名称",
                            "基础参数",
                            "Text",
                            product.name,
                            "",
                        ),
                        (
                            "产品芯片",
                            "基础参数",
                            "Text",
                            f"PERF-CHIP-{draft_revision.version}",
                            "性能压测运行时版本差异",
                        ),
                    ],
                    remark="性能压测运行时草稿版本",
                    operator=admin_user,
                    confirmed=False,
                )
                db.commit()
                current_version = draft_revision.version

            sample_context["product_id"] = product.id
            sample_context["product_name"] = product.name
            sample_context["product_current_version"] = current_version
            sample_context["product_effective_version"] = effective_version
            _append_context_refs(
                sample_context,
                key=RUNTIME_PRODUCT_IDS_KEY,
                refs=[product.id],
            )
        except Exception:
            db.rollback()
            if product_id_for_cleanup is not None:
                cleanup_db = deps.PerfSessionLocal()
                try:
                    row = cleanup_db.get(deps.Product, product_id_for_cleanup)
                    if row is not None:
                        cleanup_db.delete(row)
                        cleanup_db.commit()
                finally:
                    cleanup_db.close()
            raise
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        deps = _backend_dependencies()
        product_ids = sample_context.pop(RUNTIME_PRODUCT_IDS_KEY, [])
        if not product_ids:
            return None
        db = deps.PerfSessionLocal()
        try:
            for product_id in reversed(product_ids):
                row = db.get(deps.Product, int(product_id))
                if row is not None:
                    db.delete(row)
            db.commit()
        finally:
            db.close()
        return None


def _ensure_equipment_execution_stage_code(
    *,
    db: Any,
    deps: SimpleNamespace,
) -> str:
    stage = (
        db.execute(
            select(deps.ProcessStage).where(
                deps.ProcessStage.code == "product_testing"
            )
        )
        .scalars()
        .first()
    )
    if stage is None:
        stage = deps.ProcessStage(
            code="product_testing",
            name="成品测试",
            sort_order=0,
            remark="性能压测设备执行阶段",
            is_enabled=True,
        )
        db.add(stage)
        db.flush()
    elif not stage.is_enabled:
        stage.is_enabled = True
        db.flush()

    process_rows = (
        db.execute(
            select(deps.Process).where(
                deps.Process.stage_id == stage.id,
                deps.Process.is_enabled.is_(True),
            )
        )
        .scalars()
        .all()
    )
    if not process_rows:
        existing_process = (
            db.execute(
                select(deps.Process).where(
                    deps.Process.code == "perf_product_testing_default"
                )
            )
            .scalars()
            .first()
        )
        if existing_process is None:
            existing_process = deps.Process(
                code="perf_product_testing_default",
                name="成品测试默认流程",
                stage_id=stage.id,
                is_enabled=True,
                remark="性能压测设备执行流程",
            )
            db.add(existing_process)
        else:
            existing_process.stage_id = stage.id
            existing_process.is_enabled = True
        db.flush()
    return str(stage.code)


def _resolve_equipment_operator_context(
    *,
    db: Any,
    deps: SimpleNamespace,
    baseline_context: dict[str, Any],
) -> tuple[Any, str, list[str]]:
    canonical_stage_code = _ensure_equipment_execution_stage_code(db=db, deps=deps)
    operator_user = (
        db.execute(select(deps.User).where(deps.User.username == "ltmnt1"))
        .scalars()
        .first()
    )
    if operator_user is not None:
        stage_codes = sorted(
            deps.resolve_user_stage_codes(
                db,
                process_codes=[process.code for process in operator_user.processes],
            )
        )
        if stage_codes:
            return operator_user, stage_codes[0], stage_codes
        return operator_user, canonical_stage_code, [canonical_stage_code]

    admin_user = db.get(deps.User, int(baseline_context["admin_user_id"]))
    if admin_user is None:
        raise ValueError("管理员账号不存在，无法准备设备运行时样本")
    return admin_user, canonical_stage_code, [canonical_stage_code]


@dataclass(slots=True)
class RuntimeEquipmentFixtureHandler(SampleHandler):
    include_equipment: bool = False
    include_item: bool = False
    include_plan: bool = False
    include_rule: bool = False
    include_runtime_parameter: bool = False
    include_work_order: bool = False
    promote_work_order_to_in_progress: bool = False
    complete_work_order_for_record: bool = False

    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        created_refs: list[tuple[str, int]] = []
        try:
            baseline = deps.seed_production_craft_samples(
                db,
                run_id="baseline",
                cleanup_stale_perf_artifacts=False,
            )
            operator_user, stage_code, operator_stage_codes = (
                _resolve_equipment_operator_context(
                    db=db,
                    deps=deps,
                    baseline_context=baseline.context,
                )
            )
            sample_context["equipment_stage_code"] = stage_code

            equipment = None
            item = None
            plan = None

            if (
                self.include_equipment
                or self.include_plan
                or self.include_runtime_parameter
                or self.include_work_order
                or self.complete_work_order_for_record
            ):
                equipment = deps.create_equipment(
                    db,
                    code=f"EQ-{_new_run_id('eq').upper()}",
                    name=f"设备-{_new_run_id('eqn').upper()}",
                    model="MODEL-A",
                    location="A区",
                    owner_name="tester",
                    remark="性能压测运行时设备",
                )
                db.commit()
                db.refresh(equipment)
                created_refs.append(("equipment", int(equipment.id)))
                sample_context["equipment_id"] = int(equipment.id)
                sample_context["equipment_code"] = equipment.code

            if (
                self.include_item
                or self.include_plan
                or self.include_work_order
                or self.complete_work_order_for_record
            ):
                item = deps.create_maintenance_item(
                    db,
                    name=f"保养项目-{_new_run_id('item').upper()}",
                    default_cycle_days=30,
                    category="点检",
                    default_duration_minutes=60,
                    standard_description="性能压测运行时保养项目",
                )
                created_refs.append(("item", int(item.id)))
                sample_context["maintenance_item_id"] = int(item.id)

            if self.include_plan or self.include_work_order or self.complete_work_order_for_record:
                if equipment is None or item is None:
                    raise ValueError("设备计划运行时样本缺少前置设备或保养项目")
                plan = deps.create_maintenance_plan(
                    db,
                    equipment_id=int(equipment.id),
                    item_id=int(item.id),
                    cycle_days=30,
                    execution_process_code=stage_code,
                    estimated_duration_minutes=45,
                    start_date=date(2026, 4, 1),
                    next_due_date=date(2026, 4, 1),
                    default_executor_user_id=int(operator_user.id),
                )
                created_refs.append(("plan", int(plan.id)))
                sample_context["maintenance_plan_id"] = int(plan.id)

            if self.include_rule:
                rule = deps.create_equipment_rule(
                    db,
                    payload=deps.EquipmentRuleUpsertRequest(
                        equipment_type="加工中心",
                        rule_code=f"RULE-{_new_run_id('eqr').upper()}",
                        rule_name=f"设备规则-{_new_run_id('eqr-name').upper()}",
                        rule_type="点检",
                        condition_desc="温度超过阈值",
                        is_enabled=True,
                        effective_at=None,
                        remark="性能压测运行时设备规则",
                    ),
                )
                db.commit()
                db.refresh(rule)
                created_refs.append(("rule", int(rule.id)))
                sample_context["equipment_rule_id"] = int(rule.id)

            if self.include_runtime_parameter:
                if equipment is None:
                    raise ValueError("运行参数样本缺少前置设备")
                runtime_parameter = deps.create_runtime_parameter(
                    db,
                    payload=deps.EquipmentRuntimeParameterUpsertRequest(
                        equipment_id=int(equipment.id),
                        param_code=f"PARAM-{_new_run_id('eqp').upper()}",
                        param_name=f"参数-{_new_run_id('eqp-name').upper()}",
                        unit="mm",
                        standard_value=1.0,
                        upper_limit=2.0,
                        lower_limit=0.5,
                        effective_at=None,
                        is_enabled=True,
                        remark="性能压测运行时参数",
                    ),
                )
                db.commit()
                db.refresh(runtime_parameter)
                created_refs.append(("runtime_parameter", int(runtime_parameter.id)))
                sample_context["equipment_runtime_parameter_id"] = int(
                    runtime_parameter.id
                )

            if self.include_work_order or self.complete_work_order_for_record:
                if plan is None:
                    raise ValueError("设备工单运行时样本缺少前置计划")
                work_order, _ = deps.generate_work_order_for_plan(db, row=plan)
                created_refs.append(("work_order", int(work_order.id)))
                sample_context["maintenance_work_order_id"] = int(work_order.id)

                if (
                    self.promote_work_order_to_in_progress
                    or self.complete_work_order_for_record
                ):
                    work_order = deps.start_work_order(
                        db,
                        row=work_order,
                        operator=operator_user,
                        current_user_role_codes=[
                            role.code for role in operator_user.roles
                        ],
                        current_user_stage_codes=operator_stage_codes,
                    )

                if self.complete_work_order_for_record:
                    work_order = deps.complete_work_order(
                        db,
                        row=work_order,
                        operator=operator_user,
                        current_user_role_codes=[
                            role.code for role in operator_user.roles
                        ],
                        current_user_stage_codes=operator_stage_codes,
                        result_summary="完成",
                        result_remark="性能压测运行时保养完成",
                        attachment_link=None,
                    )
                    record_id = (
                        db.execute(
                            select(deps.MaintenanceRecord.id).where(
                                deps.MaintenanceRecord.work_order_id == work_order.id
                            )
                        )
                        .scalars()
                        .first()
                    )
                    if record_id is None:
                        raise ValueError("运行时保养记录创建失败")
                    created_refs.append(("record", int(record_id)))
                    sample_context["maintenance_record_id"] = int(record_id)

            _append_context_refs(
                sample_context,
                key=RUNTIME_EQUIPMENT_REFS_KEY,
                refs=created_refs,
            )
        except Exception:
            db.rollback()
            if created_refs:
                cleanup_db = deps.PerfSessionLocal()
                try:
                    self._delete_created_refs(cleanup_db, deps, created_refs)
                finally:
                    cleanup_db.close()
            raise
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        deps = _backend_dependencies()
        created_refs = sample_context.pop(RUNTIME_EQUIPMENT_REFS_KEY, [])
        if not created_refs:
            return None
        db = deps.PerfSessionLocal()
        try:
            self._delete_created_refs(db, deps, created_refs)
        finally:
            db.close()
        return None

    @staticmethod
    def _delete_created_refs(
        db: Any,
        deps: SimpleNamespace,
        created_refs: list[tuple[str, int]],
    ) -> None:
        equipment_ids = {
            int(ref_id) for ref_type, ref_id in created_refs if ref_type == "equipment"
        }
        item_ids = {
            int(ref_id) for ref_type, ref_id in created_refs if ref_type == "item"
        }
        if equipment_ids or item_ids:
            RuntimeEquipmentFixtureHandler._delete_related_equipment_rows(
                db=db,
                deps=deps,
                equipment_ids=equipment_ids,
                item_ids=item_ids,
            )
        model_map = {
            "equipment": deps.Equipment,
            "item": deps.MaintenanceItem,
            "plan": deps.MaintenancePlan,
            "rule": deps.EquipmentRule,
            "runtime_parameter": deps.EquipmentRuntimeParameter,
            "work_order": deps.MaintenanceWorkOrder,
            "record": deps.MaintenanceRecord,
        }
        for ref_type, ref_id in reversed(created_refs):
            model = model_map.get(ref_type)
            if model is None:
                continue
            row = db.get(model, int(ref_id))
            if row is not None:
                db.delete(row)
        db.commit()

    @staticmethod
    def _delete_related_equipment_rows(
        *,
        db: Any,
        deps: SimpleNamespace,
        equipment_ids: set[int],
        item_ids: set[int],
    ) -> None:
        record_filters = []
        work_order_filters = []
        plan_filters = []
        if equipment_ids:
            record_filters.append(
                deps.MaintenanceRecord.source_equipment_id.in_(equipment_ids)
            )
            work_order_filters.extend(
                [
                    deps.MaintenanceWorkOrder.equipment_id.in_(equipment_ids),
                    deps.MaintenanceWorkOrder.source_equipment_id.in_(equipment_ids),
                ]
            )
            plan_filters.append(deps.MaintenancePlan.equipment_id.in_(equipment_ids))
        if item_ids:
            record_filters.append(deps.MaintenanceRecord.source_item_id.in_(item_ids))
            work_order_filters.extend(
                [
                    deps.MaintenanceWorkOrder.item_id.in_(item_ids),
                    deps.MaintenanceWorkOrder.source_item_id.in_(item_ids),
                ]
            )
            plan_filters.append(deps.MaintenancePlan.item_id.in_(item_ids))

        if record_filters:
            for row in db.execute(
                select(deps.MaintenanceRecord).where(or_(*record_filters))
            ).scalars():
                db.delete(row)
            db.flush()
        if work_order_filters:
            for row in db.execute(
                select(deps.MaintenanceWorkOrder).where(or_(*work_order_filters))
            ).scalars():
                db.delete(row)
            db.flush()
        if plan_filters:
            for row in db.execute(
                select(deps.MaintenancePlan).where(or_(*plan_filters))
            ).scalars():
                db.delete(row)
            db.flush()


@dataclass(slots=True)
class RuntimeQualityFixtureHandler(SampleHandler):
    include_supplier: bool = False
    include_first_article: bool = False
    include_repair_order: bool = False
    include_scrap_statistics: bool = False

    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        created_refs: list[tuple[str, int]] = []
        try:
            baseline = deps.seed_production_craft_samples(
                db,
                run_id="baseline",
                cleanup_stale_perf_artifacts=False,
            )
            admin_user = db.get(deps.User, int(baseline.context["admin_user_id"]))
            if admin_user is None:
                raise ValueError("管理员账号不存在，无法准备质量运行时样本")

            if self.include_supplier:
                supplier = deps.create_supplier(
                    db,
                    name=f"质量供应商-{_new_run_id('sup').upper()}",
                    remark="性能压测运行时供应商",
                    is_enabled=True,
                )
                db.commit()
                db.refresh(supplier)
                created_refs.append(("supplier", int(supplier.id)))
                sample_context["supplier_id"] = int(supplier.id)

            first_article = None
            if self.include_first_article or self.include_repair_order or self.include_scrap_statistics:
                first_article = deps.FirstArticleRecord(
                    order_id=int(baseline.context["production_order_id"]),
                    order_process_id=int(baseline.context["order_process_id"]),
                    operator_user_id=int(admin_user.id),
                    verification_date=date(2026, 4, 1),
                    verification_code=f"QA-{_new_run_id('fa').upper()}",
                    result="failed",
                    remark="性能压测运行时首件",
                )
                db.add(first_article)
                db.commit()
                db.refresh(first_article)
                created_refs.append(("first_article", int(first_article.id)))
                sample_context["quality_first_article_id"] = int(first_article.id)

            if self.include_repair_order:
                repair_order = deps.RepairOrder(
                    repair_order_code=f"RO-{_new_run_id('ro').upper()}",
                    source_order_id=int(baseline.context["production_order_id"]),
                    source_order_code=str(baseline.context["production_order_code"]),
                    product_id=int(baseline.context["product_id"]),
                    product_name=str(baseline.context["product_name"]),
                    source_order_process_id=int(baseline.context["order_process_id"]),
                    source_process_code=str(baseline.context["process_code"]),
                    source_process_name=str(baseline.context["process_code"]),
                    sender_user_id=int(admin_user.id),
                    sender_username=admin_user.username,
                    production_quantity=10,
                    repair_quantity=2,
                    repaired_quantity=0,
                    scrap_quantity=0,
                    repair_time=first_article.created_at if first_article else None,
                    status="in_repair",
                    repair_operator_user_id=int(admin_user.id),
                    repair_operator_username=admin_user.username,
                )
                db.add(repair_order)
                db.flush()
                defect_row = deps.RepairDefectPhenomenon(
                    repair_order_id=int(repair_order.id),
                    order_id=repair_order.source_order_id,
                    order_code=repair_order.source_order_code,
                    product_id=repair_order.product_id,
                    product_name=repair_order.product_name,
                    process_id=repair_order.source_order_process_id,
                    process_code=repair_order.source_process_code,
                    process_name=repair_order.source_process_name,
                    phenomenon="虚焊",
                    quantity=2,
                    operator_user_id=int(admin_user.id),
                    operator_username=admin_user.username,
                    production_time=first_article.created_at if first_article else None,
                )
                db.add(defect_row)
                db.commit()
                db.refresh(repair_order)
                created_refs.append(("repair_order", int(repair_order.id)))
                sample_context["quality_repair_order_id"] = int(repair_order.id)
                sample_context["quality_order_process_id"] = int(
                    baseline.context["order_process_id"]
                )
                sample_context["quality_repair_quantity"] = 2

            if self.include_scrap_statistics:
                scrap = deps.ProductionScrapStatistics(
                    order_id=int(baseline.context["production_order_id"]),
                    order_code=str(baseline.context["production_order_code"]),
                    product_id=int(baseline.context["product_id"]),
                    product_name=str(baseline.context["product_name"]),
                    process_id=int(baseline.context["order_process_id"]),
                    process_code=str(baseline.context["process_code"]),
                    process_name=str(baseline.context["process_code"]),
                    operator_user_id=int(admin_user.id),
                    operator_username=admin_user.username,
                    scrap_reason="治具偏移",
                    scrap_quantity=1,
                    last_scrap_time=first_article.created_at if first_article else None,
                    progress="pending_apply",
                )
                db.add(scrap)
                db.commit()
                db.refresh(scrap)
                created_refs.append(("scrap", int(scrap.id)))
                sample_context["quality_scrap_id"] = int(scrap.id)

            _append_context_refs(
                sample_context,
                key=RUNTIME_QUALITY_REFS_KEY,
                refs=created_refs,
            )
        except Exception:
            db.rollback()
            if created_refs:
                cleanup_db = deps.PerfSessionLocal()
                try:
                    self._delete_created_refs(cleanup_db, deps, created_refs)
                finally:
                    cleanup_db.close()
            raise
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        deps = _backend_dependencies()
        created_refs = sample_context.pop(RUNTIME_QUALITY_REFS_KEY, [])
        if not created_refs:
            return None
        db = deps.PerfSessionLocal()
        try:
            self._delete_created_refs(db, deps, created_refs)
        finally:
            db.close()
        return None

    @staticmethod
    def _delete_created_refs(
        db: Any,
        deps: SimpleNamespace,
        created_refs: list[tuple[str, int]],
    ) -> None:
        model_map = {
            "supplier": deps.Supplier,
            "first_article": deps.FirstArticleRecord,
            "repair_order": deps.RepairOrder,
            "scrap": deps.ProductionScrapStatistics,
        }
        for ref_type, ref_id in reversed(created_refs):
            if ref_type == "first_article":
                for row in db.execute(
                    select(deps.FirstArticleDispositionHistory).where(
                        deps.FirstArticleDispositionHistory.first_article_record_id
                        == int(ref_id)
                    )
                ).scalars():
                    db.delete(row)
                for row in db.execute(
                    select(deps.FirstArticleDisposition).where(
                        deps.FirstArticleDisposition.first_article_record_id
                        == int(ref_id)
                    )
                ).scalars():
                    db.delete(row)
            if ref_type == "repair_order":
                for row in db.execute(
                    select(deps.RepairCause).where(
                        deps.RepairCause.repair_order_id == int(ref_id)
                    )
                ).scalars():
                    db.delete(row)
                for row in db.execute(
                    select(deps.RepairReturnRoute).where(
                        deps.RepairReturnRoute.repair_order_id == int(ref_id)
                    )
                ).scalars():
                    db.delete(row)
                for row in db.execute(
                    select(deps.RepairDefectPhenomenon).where(
                        deps.RepairDefectPhenomenon.repair_order_id == int(ref_id)
                    )
                ).scalars():
                    db.delete(row)
            model = model_map.get(ref_type)
            if model is None:
                continue
            row = db.get(model, int(ref_id))
            if row is not None:
                db.delete(row)
        db.commit()


@dataclass(slots=True)
class RuntimeRegistrationRequestReadyHandler(SampleHandler):
    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        created_refs: list[tuple[str, str | int]] = []
        try:
            account = f"rq{str(uuid4().hex)[:6]}"
            request_row, error_message = deps.submit_registration_request(
                db,
                account=account,
                password="Test123456",
            )
            if error_message:
                raise ValueError(error_message)
            if request_row is None:
                raise ValueError("运行时注册申请创建失败")
            created_refs.append(("registration_request", int(request_row.id)))
            created_refs.append(("registration_account", account))
            sample_context["registration_request_id"] = int(request_row.id)
            sample_context["registration_request_account"] = account
            _append_context_refs(
                sample_context,
                key=RUNTIME_AUTH_REFS_KEY,
                refs=created_refs,
            )
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        deps = _backend_dependencies()
        created_refs = sample_context.pop(RUNTIME_AUTH_REFS_KEY, [])
        if not created_refs:
            return None
        db = deps.PerfSessionLocal()
        try:
            request_id = None
            account = None
            for ref_type, ref_value in created_refs:
                if ref_type == "registration_request":
                    request_id = int(ref_value)
                if ref_type == "registration_account":
                    account = str(ref_value)
            if account:
                user_row = (
                    db.execute(select(deps.User).where(deps.User.username == account))
                    .scalars()
                    .first()
                )
                if user_row is not None:
                    db.delete(user_row)
                    db.flush()
            if request_id is not None:
                request_row = db.get(deps.RegistrationRequest, int(request_id))
                if request_row is not None:
                    db.delete(request_row)
            db.commit()
        finally:
            db.close()
        return None


@dataclass(slots=True)
class RuntimeReadonlyMessageReadyHandler(SampleHandler):
    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        try:
            baseline = deps.seed_production_craft_samples(
                db,
                run_id="baseline",
                cleanup_stale_perf_artifacts=False,
            )
            admin_user = db.get(deps.User, int(baseline.context["admin_user_id"]))
            if admin_user is None:
                raise ValueError("管理员账号不存在，无法准备消息运行时样本")

            readonly_user_ids = list(
                db.execute(
                    select(deps.User.id).where(
                        deps.User.username.in_(["ltrdo1", "ltrdo2"])
                    )
                )
                .scalars()
                .all()
            )
            if not readonly_user_ids:
                raise ValueError("未找到只读压测账号，无法准备消息运行时样本")

            result = deps.publish_announcement(
                db,
                req=deps.AnnouncementPublishRequest(
                    title=f"只读消息-{_new_run_id('msg').upper()}",
                    content="性能压测只读消息样本",
                    priority="normal",
                    range_type="users",
                    role_codes=[],
                    user_ids=readonly_user_ids,
                    expires_at=None,
                ),
                operator=admin_user,
            )
            db.commit()
            sample_context["readonly_message_id"] = int(result.message_id)
            _append_context_refs(
                sample_context,
                key=RUNTIME_MESSAGE_IDS_KEY,
                refs=[int(result.message_id)],
            )
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        deps = _backend_dependencies()
        message_ids = sample_context.pop(RUNTIME_MESSAGE_IDS_KEY, [])
        if not message_ids:
            return None
        db = deps.PerfSessionLocal()
        try:
            for message_id in reversed(message_ids):
                row = db.get(deps.Message, int(message_id))
                if row is not None:
                    db.delete(row)
            db.commit()
        finally:
            db.close()
        return None


@dataclass(slots=True)
class RuntimeUserManagementReadyHandler(SampleHandler):
    create_deleted_user: bool = False
    create_role_only: bool = False
    create_session: bool = False

    def prepare(self, sample_context: dict[str, Any]) -> None:
        deps = _backend_dependencies()
        db = deps.PerfSessionLocal()
        created_refs: list[tuple[str, int]] = []
        try:
            role_code = f"ru{uuid4().hex[:6]}"
            role = deps.Role(
                code=role_code,
                name=f"运行时角色-{role_code}",
                description="性能压测运行时角色",
                role_type="custom",
                is_builtin=False,
                is_enabled=True,
            )
            db.add(role)
            db.commit()
            db.refresh(role)
            created_refs.append(("role", int(role.id)))
            sample_context["runtime_role_id"] = int(role.id)
            sample_context["runtime_role_code"] = role.code

            if self.create_role_only:
                _append_context_refs(
                    sample_context,
                    key=RUNTIME_USER_MGMT_REFS_KEY,
                    refs=created_refs,
                )
                return None

            username = f"uu{uuid4().hex[:6]}"
            user = deps.User(
                username=username,
                full_name=f"运行时用户-{username}",
                remark="性能压测运行时用户",
                password_hash=deps.get_password_hash("Test123456"),
                is_active=True,
                is_superuser=False,
                is_deleted=False,
                must_change_password=False,
                stage_id=None,
            )
            user.roles = [role]
            user.processes = []
            db.add(user)
            db.commit()
            db.refresh(user)
            created_refs.append(("user", int(user.id)))
            sample_context["runtime_user_id"] = int(user.id)
            sample_context["runtime_username"] = user.username

            if self.create_session:
                session_row = deps.create_or_reuse_user_session(
                    db,
                    user=user,
                    ip_address="127.0.0.1",
                    terminal_info="perf-runtime-session",
                )
                db.commit()
                created_refs.append(("session", int(session_row.id)))
                sample_context["runtime_session_token_id"] = (
                    session_row.session_token_id
                )

            if self.create_deleted_user:
                delete_result, error_message = deps.delete_user(db, user=user)
                if error_message or delete_result is None:
                    raise ValueError(error_message or "运行时删除用户失败")
                user, _ = delete_result
                sample_context["runtime_deleted_user_id"] = int(user.id)

            _append_context_refs(
                sample_context,
                key=RUNTIME_USER_MGMT_REFS_KEY,
                refs=created_refs,
            )
        except Exception:
            db.rollback()
            self._cleanup(db, deps, created_refs)
            raise
        finally:
            db.close()

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        del strategy
        deps = _backend_dependencies()
        created_refs = sample_context.pop(RUNTIME_USER_MGMT_REFS_KEY, [])
        if not created_refs:
            return None
        db = deps.PerfSessionLocal()
        try:
            self._cleanup(db, deps, created_refs)
        finally:
            db.close()
        return None

    @staticmethod
    def _cleanup(
        db: Any,
        deps: SimpleNamespace,
        created_refs: list[tuple[str, int]],
    ) -> None:
        model_map = {
            "session": deps.UserSession,
            "user": deps.User,
            "role": deps.Role,
        }
        for ref_type, ref_id in reversed(created_refs):
            model = model_map.get(ref_type)
            if model is None:
                continue
            row = db.get(model, int(ref_id))
            if row is not None:
                db.delete(row)
        db.commit()


def build_sample_registry(
    *,
    sample_context: dict[str, Any],
    api_client: Any,
) -> dict[str, SampleHandler]:
    del sample_context, api_client
    draft_template_handler = RuntimeTemplateReadyHandler(publish_before_request=False)
    published_template_handler = RuntimeTemplateReadyHandler(
        publish_before_request=True
    )
    archived_template_handler = RuntimeTemplateReadyHandler(
        publish_before_request=True,
        archive_before_request=True,
    )
    return {
        "order:create-ready": BaselineOrderCreateReadyHandler(),
        "order:line-items-ready": NoOpSampleHandler("order:line-items-ready"),
        "supplier:create-ready": NoOpSampleHandler("supplier:create-ready"),
        "craft:template-draft-ready": draft_template_handler,
        "craft:template-published-ready": published_template_handler,
        "craft:template-archived-ready": archived_template_handler,
        "craft:stage-delete-ready": RuntimeStageDeleteReadyHandler(),
        "craft:template-publish-ready": draft_template_handler,
        "craft:process-create-ready": CraftProcessCreateReadyHandler(),
        "craft:process-runtime-ready": CraftProcessRuntimeReadyHandler(),
        "craft:system-master-ready": SystemMasterTemplateReadyHandler(),
        "product:runtime-version-create-ready": RuntimeProductVersionReadyHandler(
            ensure_draft=False
        ),
        "product:runtime-draft-version-ready": RuntimeProductVersionReadyHandler(
            ensure_draft=True
        ),
        "product:runtime-effective-version-ready": RuntimeProductVersionReadyHandler(
            ensure_draft=False
        ),
        "equipment:runtime-ledger-ready": RuntimeEquipmentFixtureHandler(
            include_equipment=True
        ),
        "equipment:runtime-item-ready": RuntimeEquipmentFixtureHandler(
            include_item=True
        ),
        "equipment:runtime-plan-create-ready": RuntimeEquipmentFixtureHandler(
            include_equipment=True,
            include_item=True,
        ),
        "equipment:runtime-plan-ready": RuntimeEquipmentFixtureHandler(
            include_equipment=True,
            include_item=True,
            include_plan=True,
        ),
        "equipment:runtime-rule-ready": RuntimeEquipmentFixtureHandler(
            include_rule=True
        ),
        "equipment:runtime-param-ready": RuntimeEquipmentFixtureHandler(
            include_equipment=True,
            include_runtime_parameter=True,
        ),
        "equipment:runtime-work-order-pending-ready": RuntimeEquipmentFixtureHandler(
            include_equipment=True,
            include_item=True,
            include_plan=True,
            include_work_order=True,
        ),
        "equipment:runtime-work-order-in-progress-ready": RuntimeEquipmentFixtureHandler(
            include_equipment=True,
            include_item=True,
            include_plan=True,
            include_work_order=True,
            promote_work_order_to_in_progress=True,
        ),
        "equipment:runtime-record-ready": RuntimeEquipmentFixtureHandler(
            include_equipment=True,
            include_item=True,
            include_plan=True,
            include_work_order=True,
            complete_work_order_for_record=True,
        ),
        "quality:runtime-supplier-ready": RuntimeQualityFixtureHandler(
            include_supplier=True
        ),
        "quality:runtime-first-article-failed-ready": RuntimeQualityFixtureHandler(
            include_first_article=True
        ),
        "quality:runtime-repair-order-ready": RuntimeQualityFixtureHandler(
            include_repair_order=True
        ),
        "quality:runtime-scrap-ready": RuntimeQualityFixtureHandler(
            include_scrap_statistics=True
        ),
        "auth:runtime-registration-request-ready": RuntimeRegistrationRequestReadyHandler(),
        "message:runtime-readonly-message-ready": RuntimeReadonlyMessageReadyHandler(),
        "user:runtime-role-ready": RuntimeUserManagementReadyHandler(
            create_role_only=True
        ),
        "user:runtime-user-ready": RuntimeUserManagementReadyHandler(),
        "user:runtime-deleted-user-ready": RuntimeUserManagementReadyHandler(
            create_deleted_user=True
        ),
        "user:runtime-session-user-ready": RuntimeUserManagementReadyHandler(
            create_session=True
        ),
        "production:runtime-order-pending-ready": RuntimeOrderReadyHandler(
            promote_to_in_progress=False
        ),
        "production:runtime-order-in-progress-ready": RuntimeOrderReadyHandler(
            promote_to_in_progress=True
        ),
    }

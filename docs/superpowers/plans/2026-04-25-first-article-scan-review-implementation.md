# First Article Scan Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将首件检验从手输检验码改为“操作员填写实测值、质检员手机扫码复核判定”的闭环。

**Architecture:** 在现有 FastAPI 后端内新增首件扫码复核会话、权限与接口；Flutter 操作员端替换首件检验码输入为二维码等待区；同一前端工程新增极简手机 Web 入口，复用现有登录接口但不进入主壳。合格自动生成正式首件记录，不合格返回操作员修改重发。

**Tech Stack:** FastAPI、SQLAlchemy、Alembic、Pydantic、pytest、Flutter/Dart、flutter_test、integration_test。

---

## 文件结构

后端新增或修改：

- Create: `backend/app/models/first_article_review_session.py`，保存扫码复核会话与 token 哈希。
- Create: `backend/alembic/versions/z8a9b0c1d2e3_add_first_article_review_session.py`，新增会话表和正式首件复核字段。
- Modify: `backend/app/db/base.py`、`backend/app/models/__init__.py`，注册新模型。
- Modify: `backend/app/models/first_article_record.py`，新增 `reviewer_user_id`、`reviewed_at`、`review_remark`。
- Modify: `backend/app/schemas/production.py`，新增扫码会话创建、详情、提交、刷新响应模型。
- Create: `backend/app/services/first_article_review_service.py`，实现 token、会话状态、合格落正式记录、不合格回退。
- Modify: `backend/app/services/production_execution_service.py`，抽出可复用的首件创建核心，移除扫码路径对每日检验码的依赖。
- Modify: `backend/app/api/v1/endpoints/production.py`，新增扫码复核接口并保留旧接口兼容到实现完成前。
- Modify: `backend/app/core/authz_catalog.py`、`backend/app/core/authz_hierarchy_catalog.py`，新增 `quality.first_articles.scan_review` 能力。
- Test: `backend/tests/test_first_article_scan_review_service.py`
- Test: `backend/tests/test_first_article_scan_review_api.py`
- Test: `backend/tests/test_authz_capability_pack_catalog.py`

前端新增或修改：

- Modify: `frontend/lib/features/production/models/production_models.dart`，新增扫码会话模型和请求模型。
- Modify: `frontend/lib/features/production/services/production_service.dart`，新增创建/查询/刷新扫码会话接口。
- Modify: `frontend/lib/features/production/presentation/production_first_article_page.dart`，替换检验码输入为扫码复核两阶段 UI。
- Create: `frontend/lib/features/production/presentation/first_article_scan_review_mobile_page.dart`，手机极简登录与复核页。
- Modify: `frontend/lib/features/auth/services/auth_service.dart`，必要时暴露手机页复用的登录错误处理辅助。
- Modify: `frontend/lib/main.dart` 或当前路由入口文件，注册 `/first-article-review` 路由。
- Modify: `frontend/lib/core/models/authz_models.dart`，补充能力码常量。
- Test: `frontend/test/models/production_models_test.dart`
- Test: `frontend/test/services/production_service_test.dart`
- Test: `frontend/test/widgets/production_first_article_page_test.dart`
- Test: `frontend/test/widgets/first_article_scan_review_mobile_page_test.dart`
- Test: `frontend/integration_test/first_article_scan_review_flow_test.dart`

文档与证据：

- Modify: `evidence/2026-04-25_扫码首件复核实现计划.md`，记录计划、验证、失败重试和迁移口径。

---

### Task 1: 后端扫码会话模型与迁移

**Files:**
- Create: `backend/app/models/first_article_review_session.py`
- Create: `backend/alembic/versions/z8a9b0c1d2e3_add_first_article_review_session.py`
- Modify: `backend/app/db/base.py`
- Modify: `backend/app/models/__init__.py`
- Modify: `backend/app/models/first_article_record.py`
- Test: `backend/tests/test_first_article_scan_review_service.py`

- [ ] **Step 1: 写失败测试，覆盖模型导入与字段**

在 `backend/tests/test_first_article_scan_review_service.py` 新建测试：

```python
from datetime import datetime, timedelta, timezone

from app.models.first_article_record import FirstArticleRecord
from app.models.first_article_review_session import FirstArticleReviewSession


def test_first_article_review_session_model_has_required_fields() -> None:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
    row = FirstArticleReviewSession(
        token_hash="hash-value",
        status="pending",
        expires_at=expires_at,
        order_id=1,
        order_process_id=2,
        pipeline_instance_id=None,
        operator_user_id=3,
        assist_authorization_id=None,
        template_id=None,
        check_content="外观检查",
        test_value="尺寸 10.01",
        participant_user_ids=[3, 4],
    )

    assert row.status == "pending"
    assert row.participant_user_ids == [3, 4]
    assert row.expires_at == expires_at


def test_first_article_record_has_review_fields() -> None:
    row = FirstArticleRecord(
        order_id=1,
        order_process_id=2,
        operator_user_id=3,
        verification_date=datetime.now(timezone.utc).date(),
        verification_code="SCAN-APPROVED",
        result="passed",
        reviewer_user_id=5,
        reviewed_at=datetime.now(timezone.utc),
        review_remark="参数一致",
    )

    assert row.reviewer_user_id == 5
    assert row.review_remark == "参数一致"
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd backend; pytest tests/test_first_article_scan_review_service.py -q`

Expected: FAIL，提示 `app.models.first_article_review_session` 不存在或 `FirstArticleRecord` 不接受复核字段。

- [ ] **Step 3: 新增模型**

创建 `backend/app/models/first_article_review_session.py`：

```python
from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base_class import Base
from app.models.mixins import TimestampMixin


class FirstArticleReviewSession(Base, TimestampMixin):
    __tablename__ = "mes_first_article_review_session"
    __table_args__ = (
        Index("ix_mes_first_article_review_session_token_hash", "token_hash", unique=True),
        Index("ix_mes_first_article_review_session_status", "status"),
        Index("ix_mes_first_article_review_session_expires_at", "expires_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    token_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    order_id: Mapped[int] = mapped_column(ForeignKey("mes_production_order.id", ondelete="CASCADE"), nullable=False, index=True)
    order_process_id: Mapped[int] = mapped_column(ForeignKey("mes_production_order_process.id", ondelete="CASCADE"), nullable=False, index=True)
    pipeline_instance_id: Mapped[int | None] = mapped_column(ForeignKey("mes_production_pipeline_instance.id", ondelete="SET NULL"), nullable=True, index=True)
    operator_user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id", ondelete="RESTRICT"), nullable=False, index=True)
    assist_authorization_id: Mapped[int | None] = mapped_column(ForeignKey("mes_assist_authorization.id", ondelete="SET NULL"), nullable=True, index=True)
    template_id: Mapped[int | None] = mapped_column(ForeignKey("mes_first_article_template.id", ondelete="SET NULL"), nullable=True, index=True)
    check_content: Mapped[str] = mapped_column(Text, nullable=False)
    test_value: Mapped[str] = mapped_column(Text, nullable=False)
    participant_user_ids: Mapped[list[int]] = mapped_column(JSON, nullable=False, default=list)
    reviewer_user_id: Mapped[int | None] = mapped_column(ForeignKey("sys_user.id", ondelete="SET NULL"), nullable=True, index=True)
    review_result: Mapped[str | None] = mapped_column(String(32), nullable=True)
    review_remark: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    first_article_record_id: Mapped[int | None] = mapped_column(ForeignKey("mes_first_article_record.id", ondelete="SET NULL"), nullable=True, index=True)

    order = relationship("ProductionOrder")
    order_process = relationship("ProductionOrderProcess")
    operator = relationship("User", foreign_keys=[operator_user_id])
    reviewer = relationship("User", foreign_keys=[reviewer_user_id])
    first_article_record = relationship("FirstArticleRecord")
```

- [ ] **Step 4: 扩展正式首件记录模型**

在 `backend/app/models/first_article_record.py` 增加字段和关系：

```python
    reviewer_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("sys_user.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    review_remark: Mapped[str | None] = mapped_column(Text, nullable=True)

    reviewer = relationship("User", foreign_keys=[reviewer_user_id])
```

同时确认文件已有 `DateTime` 与 `datetime` import；若没有，补齐：

```python
from datetime import date, datetime
from sqlalchemy import Date, DateTime, ForeignKey, String, Text
```

- [ ] **Step 5: 注册模型**

在 `backend/app/db/base.py` 增加：

```python
from app.models.first_article_review_session import FirstArticleReviewSession
```

在 `backend/app/models/__init__.py` 增加：

```python
from app.models.first_article_review_session import FirstArticleReviewSession
```

并把 `"FirstArticleReviewSession"` 加入 `__all__`。

- [ ] **Step 6: 新增 Alembic 迁移**

创建 `backend/alembic/versions/z8a9b0c1d2e3_add_first_article_review_session.py`。本计划指定 revision 为 `z8a9b0c1d2e3`，挂在首件富表单 schema 迁移 `x1y2z3a4b5c6` 之后；执行前若仓库新增了更新的首件相关迁移，先用 `cd backend; python -m alembic heads` 核对并把 `down_revision` 改为新的首件链路 head。

```python
"""add first article review session

Revision ID: z8a9b0c1d2e3
Revises: x1y2z3a4b5c6
Create Date: 2026-04-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "z8a9b0c1d2e3"
down_revision: Union[str, Sequence[str], None] = "x1y2z3a4b5c6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mes_first_article_review_session",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("token_hash", sa.String(length=128), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("order_process_id", sa.Integer(), nullable=False),
        sa.Column("pipeline_instance_id", sa.Integer(), nullable=True),
        sa.Column("operator_user_id", sa.Integer(), nullable=False),
        sa.Column("assist_authorization_id", sa.Integer(), nullable=True),
        sa.Column("template_id", sa.Integer(), nullable=True),
        sa.Column("check_content", sa.Text(), nullable=False),
        sa.Column("test_value", sa.Text(), nullable=False),
        sa.Column("participant_user_ids", sa.JSON(), nullable=False),
        sa.Column("reviewer_user_id", sa.Integer(), nullable=True),
        sa.Column("review_result", sa.String(length=32), nullable=True),
        sa.Column("review_remark", sa.Text(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("first_article_record_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["assist_authorization_id"], ["mes_assist_authorization.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["first_article_record_id"], ["mes_first_article_record.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["operator_user_id"], ["sys_user.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["order_id"], ["mes_production_order.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["order_process_id"], ["mes_production_order_process.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["pipeline_instance_id"], ["mes_production_pipeline_instance.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["reviewer_user_id"], ["sys_user.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["template_id"], ["mes_first_article_template.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_mes_first_article_review_session_token_hash", "mes_first_article_review_session", ["token_hash"], unique=True)
    op.create_index("ix_mes_first_article_review_session_status", "mes_first_article_review_session", ["status"])
    op.create_index("ix_mes_first_article_review_session_expires_at", "mes_first_article_review_session", ["expires_at"])
    op.create_index("ix_mes_first_article_review_session_order_id", "mes_first_article_review_session", ["order_id"])
    op.create_index("ix_mes_first_article_review_session_order_process_id", "mes_first_article_review_session", ["order_process_id"])
    op.create_index("ix_mes_first_article_review_session_operator_user_id", "mes_first_article_review_session", ["operator_user_id"])
    op.create_index("ix_mes_first_article_review_session_reviewer_user_id", "mes_first_article_review_session", ["reviewer_user_id"])
    op.add_column("mes_first_article_record", sa.Column("reviewer_user_id", sa.Integer(), nullable=True))
    op.add_column("mes_first_article_record", sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("mes_first_article_record", sa.Column("review_remark", sa.Text(), nullable=True))
    op.create_foreign_key(
        "fk_mes_first_article_record_reviewer_user_id_sys_user",
        "mes_first_article_record",
        "sys_user",
        ["reviewer_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_mes_first_article_record_reviewer_user_id", "mes_first_article_record", ["reviewer_user_id"])


def downgrade() -> None:
    op.drop_index("ix_mes_first_article_record_reviewer_user_id", table_name="mes_first_article_record")
    op.drop_constraint("fk_mes_first_article_record_reviewer_user_id_sys_user", "mes_first_article_record", type_="foreignkey")
    op.drop_column("mes_first_article_record", "review_remark")
    op.drop_column("mes_first_article_record", "reviewed_at")
    op.drop_column("mes_first_article_record", "reviewer_user_id")
    op.drop_index("ix_mes_first_article_review_session_reviewer_user_id", table_name="mes_first_article_review_session")
    op.drop_index("ix_mes_first_article_review_session_operator_user_id", table_name="mes_first_article_review_session")
    op.drop_index("ix_mes_first_article_review_session_order_process_id", table_name="mes_first_article_review_session")
    op.drop_index("ix_mes_first_article_review_session_order_id", table_name="mes_first_article_review_session")
    op.drop_index("ix_mes_first_article_review_session_expires_at", table_name="mes_first_article_review_session")
    op.drop_index("ix_mes_first_article_review_session_status", table_name="mes_first_article_review_session")
    op.drop_index("ix_mes_first_article_review_session_token_hash", table_name="mes_first_article_review_session")
    op.drop_table("mes_first_article_review_session")
```

- [ ] **Step 7: 运行模型测试**

Run: `cd backend; pytest tests/test_first_article_scan_review_service.py -q`

Expected: PASS。

- [ ] **Step 8: 提交**

```bash
git add backend/app/models/first_article_review_session.py backend/app/models/first_article_record.py backend/app/db/base.py backend/app/models/__init__.py backend/alembic/versions/z8a9b0c1d2e3_add_first_article_review_session.py backend/tests/test_first_article_scan_review_service.py
git commit -m "新增首件扫码复核会话模型"
```

---

### Task 2: 权限能力包接入

**Files:**
- Modify: `backend/app/core/authz_catalog.py`
- Modify: `backend/app/core/authz_hierarchy_catalog.py`
- Modify: `frontend/lib/core/models/authz_models.dart`
- Test: `backend/tests/test_authz_capability_pack_catalog.py`

- [ ] **Step 1: 写失败测试**

在 `backend/tests/test_authz_capability_pack_catalog.py` 追加：

```python
from app.core.authz_catalog import ACTION_PERMISSION_CATALOG
from app.core.authz_hierarchy_catalog import FEATURE_DEFINITIONS


def test_first_article_scan_review_permission_is_in_quality_catalog() -> None:
    action_codes = {item.permission_code for item in ACTION_PERMISSION_CATALOG}
    feature_codes = {item.permission_code for item in FEATURE_DEFINITIONS}

    assert "quality.first_articles.scan_review" in action_codes
    assert "feature.quality.first_articles.scan_review" in feature_codes
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd backend; pytest tests/test_authz_capability_pack_catalog.py::test_first_article_scan_review_permission_is_in_quality_catalog -q`

Expected: FAIL，提示权限码不存在。

- [ ] **Step 3: 新增后端权限目录项**

在 `backend/app/core/authz_catalog.py` 首件权限附近增加：

```python
PERM_QUALITY_FIRST_ARTICLES_SCAN_REVIEW = "quality.first_articles.scan_review"
```

在质量动作权限列表中加入：

```python
    (
        PERM_QUALITY_FIRST_ARTICLES_SCAN_REVIEW,
        "扫码复核首件",
        AUTHZ_MODULE_QUALITY,
        "first_article_management",
    ),
```

- [ ] **Step 4: 新增能力包特性定义**

在 `backend/app/core/authz_hierarchy_catalog.py` 的质量特性区域加入：

```python
    FeatureDefinition(
        permission_code="feature.quality.first_articles.scan_review",
        permission_name="扫码复核首件",
        module_code="quality",
        page_code="first_article_management",
        dependency_permission_codes=(
            "page.quality.view",
            "page.first_article_management.view",
            "quality.first_articles.scan_review",
        ),
    ),
```

- [ ] **Step 5: 前端补充能力码常量**

在 `frontend/lib/core/models/authz_models.dart` 的 `QualityPermissionCodes` 中加入：

```dart
  static const String firstArticlesScanReview =
      'quality.first_articles.scan_review';
```

在 `QualityFeaturePermissionCodes` 中加入：

```dart
  static const String firstArticlesScanReview =
      'feature.quality.first_articles.scan_review';
```

- [ ] **Step 6: 运行权限测试**

Run: `cd backend; pytest tests/test_authz_capability_pack_catalog.py -q`

Expected: PASS。

- [ ] **Step 7: 提交**

```bash
git add backend/app/core/authz_catalog.py backend/app/core/authz_hierarchy_catalog.py frontend/lib/core/models/authz_models.dart backend/tests/test_authz_capability_pack_catalog.py
git commit -m "新增首件扫码复核能力包权限"
```

---

### Task 3: 后端扫码复核服务

**Files:**
- Create: `backend/app/services/first_article_review_service.py`
- Modify: `backend/app/services/production_execution_service.py`
- Test: `backend/tests/test_first_article_scan_review_service.py`

- [ ] **Step 1: 写服务层失败测试**

在 `backend/tests/test_first_article_scan_review_service.py` 追加服务行为测试。测试夹具复用现有生产模块测试中的订单、工序、用户创建辅助；若没有可直接复用的工厂，先在本测试文件内创建最小订单、工序、用户和模板。

```python
from datetime import datetime, timedelta, timezone

import pytest

from app.models.first_article_review_session import FirstArticleReviewSession
from app.services.first_article_review_service import (
    create_first_article_review_session,
    refresh_first_article_review_session,
    submit_first_article_review_result,
)


def test_create_review_session_stores_hash_not_plain_token(db, production_order_context, operator_user) -> None:
    result = create_first_article_review_session(
        db,
        order_id=production_order_context.order.id,
        order_process_id=production_order_context.process.id,
        pipeline_instance_id=None,
        template_id=None,
        check_content="外观无划伤",
        test_value="长度 10.01",
        participant_user_ids=[operator_user.id],
        assist_authorization_id=None,
        operator=operator_user,
    )

    row = db.get(FirstArticleReviewSession, result.session_id)
    assert row is not None
    assert row.status == "pending"
    assert result.token not in row.token_hash
    assert result.review_url.endswith(f"token={result.token}")


def test_refresh_cancels_old_session(db, production_order_context, operator_user) -> None:
    created = create_first_article_review_session(
        db,
        order_id=production_order_context.order.id,
        order_process_id=production_order_context.process.id,
        pipeline_instance_id=None,
        template_id=None,
        check_content="外观无划伤",
        test_value="长度 10.01",
        participant_user_ids=[],
        assist_authorization_id=None,
        operator=operator_user,
    )

    refreshed = refresh_first_article_review_session(
        db,
        session_id=created.session_id,
        operator=operator_user,
        check_content="外观无划伤",
        test_value="长度 10.02",
        participant_user_ids=[],
    )

    old_row = db.get(FirstArticleReviewSession, created.session_id)
    new_row = db.get(FirstArticleReviewSession, refreshed.session_id)
    assert old_row.status == "cancelled"
    assert new_row.status == "pending"
    assert refreshed.token != created.token


def test_failed_review_does_not_create_first_article_record(db, production_order_context, operator_user, reviewer_user_with_scan_permission) -> None:
    created = create_first_article_review_session(
        db,
        order_id=production_order_context.order.id,
        order_process_id=production_order_context.process.id,
        pipeline_instance_id=None,
        template_id=None,
        check_content="外观无划伤",
        test_value="长度 10.01",
        participant_user_ids=[],
        assist_authorization_id=None,
        operator=operator_user,
    )

    result = submit_first_article_review_result(
        db,
        token=created.token,
        reviewer=reviewer_user_with_scan_permission,
        review_result="failed",
        review_remark="尺寸复核不一致",
    )

    row = db.get(FirstArticleReviewSession, created.session_id)
    assert result.status == "rejected"
    assert row.first_article_record_id is None
    assert row.review_remark == "尺寸复核不一致"
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd backend; pytest tests/test_first_article_scan_review_service.py -q`

Expected: FAIL，提示服务模块不存在。

- [ ] **Step 3: 实现 token 与结果类型**

创建 `backend/app/services/first_article_review_service.py`，先写常量和结果类：

```python
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hashlib
import secrets

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.authz_catalog import PERM_QUALITY_FIRST_ARTICLES_SCAN_REVIEW
from app.models.first_article_review_session import FirstArticleReviewSession
from app.models.user import User
from app.services.production_execution_service import create_first_article_record_from_review

REVIEW_SESSION_TTL = timedelta(minutes=5)
REVIEW_TOKEN_BYTES = 32
REVIEW_URL_PATH = "/first-article-review"


@dataclass(frozen=True, slots=True)
class FirstArticleReviewSessionTokenResult:
    session_id: int
    token: str
    review_url: str
    expires_at: datetime
    status: str


@dataclass(frozen=True, slots=True)
class FirstArticleReviewSubmitResult:
    session_id: int
    status: str
    first_article_record_id: int | None
    reviewer_user_id: int
    reviewed_at: datetime
    review_remark: str | None


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _new_token() -> str:
    return secrets.token_urlsafe(REVIEW_TOKEN_BYTES)


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _review_url(token: str) -> str:
    return f"{REVIEW_URL_PATH}?token={token}"
```

- [ ] **Step 4: 实现创建与刷新**

继续在同一文件中加入：

```python
def create_first_article_review_session(
    db: Session,
    *,
    order_id: int,
    order_process_id: int,
    pipeline_instance_id: int | None,
    template_id: int | None,
    check_content: str,
    test_value: str,
    participant_user_ids: list[int],
    assist_authorization_id: int | None,
    operator: User,
) -> FirstArticleReviewSessionTokenResult:
    normalized_check_content = check_content.strip()
    normalized_test_value = test_value.strip()
    if not normalized_check_content:
        raise ValueError("首件内容不能为空")
    if not normalized_test_value:
        raise ValueError("首件测试值不能为空")

    token = _new_token()
    expires_at = _now() + REVIEW_SESSION_TTL
    row = FirstArticleReviewSession(
        token_hash=_hash_token(token),
        status="pending",
        expires_at=expires_at,
        order_id=order_id,
        order_process_id=order_process_id,
        pipeline_instance_id=pipeline_instance_id,
        operator_user_id=operator.id,
        assist_authorization_id=assist_authorization_id,
        template_id=template_id,
        check_content=normalized_check_content,
        test_value=normalized_test_value,
        participant_user_ids=list(dict.fromkeys(participant_user_ids)),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return FirstArticleReviewSessionTokenResult(
        session_id=row.id,
        token=token,
        review_url=_review_url(token),
        expires_at=row.expires_at,
        status=row.status,
    )


def refresh_first_article_review_session(
    db: Session,
    *,
    session_id: int,
    operator: User,
    check_content: str,
    test_value: str,
    participant_user_ids: list[int],
) -> FirstArticleReviewSessionTokenResult:
    row = db.get(FirstArticleReviewSession, session_id)
    if row is None:
        raise ValueError("首件扫码复核会话不存在")
    if row.operator_user_id != operator.id:
        raise ValueError("只能刷新本人发起的首件扫码复核")
    if row.status == "pending":
        row.status = "cancelled"
        db.flush()
    return create_first_article_review_session(
        db,
        order_id=row.order_id,
        order_process_id=row.order_process_id,
        pipeline_instance_id=row.pipeline_instance_id,
        template_id=row.template_id,
        check_content=check_content,
        test_value=test_value,
        participant_user_ids=participant_user_ids,
        assist_authorization_id=row.assist_authorization_id,
        operator=operator,
    )
```

- [ ] **Step 5: 实现提交复核**

继续在同一文件中加入：

```python
def _load_session_by_token(db: Session, token: str) -> FirstArticleReviewSession:
    token_hash = _hash_token(token.strip())
    row = (
        db.execute(
            select(FirstArticleReviewSession).where(
                FirstArticleReviewSession.token_hash == token_hash
            )
        )
        .scalars()
        .first()
    )
    if row is None:
        raise ValueError("二维码无效")
    if row.status == "cancelled":
        raise ValueError("二维码已刷新，请重新扫码")
    if row.status in {"approved", "rejected"}:
        raise ValueError("本次首件复核已完成")
    if row.expires_at <= _now():
        row.status = "expired"
        db.commit()
        raise ValueError("二维码已失效，请操作员刷新后重新扫码")
    return row


def _user_has_permission(user: User, permission_code: str) -> bool:
    return any(
        permission.permission_code == permission_code
        for role in user.roles
        for permission in role.permissions
    )


def submit_first_article_review_result(
    db: Session,
    *,
    token: str,
    reviewer: User,
    review_result: str,
    review_remark: str | None,
) -> FirstArticleReviewSubmitResult:
    if not _user_has_permission(reviewer, PERM_QUALITY_FIRST_ARTICLES_SCAN_REVIEW):
        raise PermissionError("当前账号无扫码复核首件权限")
    normalized_result = review_result.strip().lower()
    if normalized_result not in {"passed", "failed"}:
        raise ValueError("复核结果必须为 passed 或 failed")

    row = _load_session_by_token(db, token)
    reviewed_at = _now()
    row.reviewer_user_id = reviewer.id
    row.review_result = normalized_result
    row.review_remark = (review_remark or "").strip() or None
    row.reviewed_at = reviewed_at

    first_article_record_id = None
    if normalized_result == "passed":
        record = create_first_article_record_from_review(db, session=row, reviewer=reviewer)
        first_article_record_id = record.id
        row.first_article_record_id = record.id
        row.status = "approved"
    else:
        row.status = "rejected"

    db.commit()
    db.refresh(row)
    return FirstArticleReviewSubmitResult(
        session_id=row.id,
        status=row.status,
        first_article_record_id=first_article_record_id,
        reviewer_user_id=reviewer.id,
        reviewed_at=reviewed_at,
        review_remark=row.review_remark,
    )
```

- [ ] **Step 6: 抽出正式首件创建核心**

在 `backend/app/services/production_execution_service.py` 中新增函数：

```python
def create_first_article_record_from_review(
    db: Session,
    *,
    session: FirstArticleReviewSession,
    reviewer: User,
) -> FirstArticleRecord:
    return _create_first_article_record_core(
        db,
        order_id=session.order_id,
        order_process_id=session.order_process_id,
        pipeline_instance_id=session.pipeline_instance_id,
        template_id=session.template_id,
        check_content=session.check_content,
        test_value=session.test_value,
        result="passed",
        participant_user_ids=session.participant_user_ids,
        verification_code=f"SCAN-{session.id}",
        remark=session.review_remark,
        operator_user_id=session.operator_user_id,
        reviewer_user_id=reviewer.id,
        reviewed_at=session.reviewed_at,
        review_remark=session.review_remark,
    )
```

并把当前 `submit_first_article` 中创建 `FirstArticleRecord`、参与人、生产记录和订单事件的主体抽成 `_create_first_article_record_core(...)`。旧 `submit_first_article` 仍先校验每日检验码，再调用该核心函数，保证现有测试在过渡期通过。

- [ ] **Step 7: 运行服务测试**

Run: `cd backend; pytest tests/test_first_article_scan_review_service.py -q`

Expected: PASS。

- [ ] **Step 8: 提交**

```bash
git add backend/app/services/first_article_review_service.py backend/app/services/production_execution_service.py backend/tests/test_first_article_scan_review_service.py
git commit -m "实现首件扫码复核服务"
```

---

### Task 4: 后端 API 与 schema

**Files:**
- Modify: `backend/app/schemas/production.py`
- Modify: `backend/app/api/v1/endpoints/production.py`
- Test: `backend/tests/test_first_article_scan_review_api.py`

- [ ] **Step 1: 写 API 失败测试**

创建 `backend/tests/test_first_article_scan_review_api.py`：

```python
def test_create_first_article_review_session_api(client, operator_token, production_order_context) -> None:
    response = client.post(
        f"/api/v1/production/orders/{production_order_context.order.id}/first-article/review-sessions",
        headers={"Authorization": f"Bearer {operator_token}"},
        json={
            "order_process_id": production_order_context.process.id,
            "pipeline_instance_id": None,
            "template_id": None,
            "check_content": "外观无划伤",
            "test_value": "长度 10.01",
            "participant_user_ids": [],
            "assist_authorization_id": None,
        },
    )

    assert response.status_code == 201
    data = response.json()["data"]
    assert data["status"] == "pending"
    assert "/first-article-review?token=" in data["review_url"]


def test_submit_scan_review_requires_scan_permission(client, operator_token, review_token) -> None:
    response = client.post(
        "/api/v1/production/first-article/review-sessions/submit",
        headers={"Authorization": f"Bearer {operator_token}"},
        json={"token": review_token, "review_result": "passed", "review_remark": "参数一致"},
    )

    assert response.status_code == 403
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd backend; pytest tests/test_first_article_scan_review_api.py -q`

Expected: FAIL，提示路由或 schema 不存在。

- [ ] **Step 3: 新增 schema**

在 `backend/app/schemas/production.py` 增加：

```python
class FirstArticleReviewSessionCreateRequest(BaseModel):
    order_process_id: int = Field(gt=0)
    pipeline_instance_id: int | None = Field(default=None, gt=0)
    template_id: int | None = Field(default=None, gt=0)
    check_content: str = Field(min_length=1, max_length=4096)
    test_value: str = Field(min_length=1, max_length=4096)
    participant_user_ids: list[int] = Field(default_factory=list)
    assist_authorization_id: int | None = Field(default=None, gt=0)


class FirstArticleReviewSessionRefreshRequest(BaseModel):
    check_content: str = Field(min_length=1, max_length=4096)
    test_value: str = Field(min_length=1, max_length=4096)
    participant_user_ids: list[int] = Field(default_factory=list)


class FirstArticleReviewSessionSubmitRequest(BaseModel):
    token: str = Field(min_length=16, max_length=256)
    review_result: str = Field(min_length=1, max_length=32)
    review_remark: str | None = Field(default=None, max_length=1024)

    @field_validator("review_result")
    @classmethod
    def validate_review_result(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"passed", "failed"}:
            raise ValueError("review_result must be passed or failed")
        return normalized


class FirstArticleReviewSessionResult(BaseModel):
    session_id: int
    review_url: str | None = None
    expires_at: datetime
    status: str
    first_article_record_id: int | None = None
    reviewer_user_id: int | None = None
    reviewed_at: datetime | None = None
    review_remark: str | None = None
```

- [ ] **Step 4: 新增路由**

在 `backend/app/api/v1/endpoints/production.py` import 新 schema 与服务函数，并加入：

```python
@router.post(
    "/orders/{order_id}/first-article/review-sessions",
    response_model=ApiResponse[FirstArticleReviewSessionResult],
    status_code=201,
)
def create_first_article_review_session_api(
    order_id: int,
    payload: FirstArticleReviewSessionCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(PERM_PROD_EXECUTION_FIRST_ARTICLE)),
) -> ApiResponse[FirstArticleReviewSessionResult]:
    try:
        result = create_first_article_review_session(
            db,
            order_id=order_id,
            order_process_id=payload.order_process_id,
            pipeline_instance_id=payload.pipeline_instance_id,
            template_id=payload.template_id,
            check_content=payload.check_content,
            test_value=payload.test_value,
            participant_user_ids=payload.participant_user_ids,
            assist_authorization_id=payload.assist_authorization_id,
            operator=current_user,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return success_response(
        FirstArticleReviewSessionResult(
            session_id=result.session_id,
            review_url=result.review_url,
            expires_at=result.expires_at,
            status=result.status,
        ),
        message="first_article_review_session_created",
    )
```

再加入刷新与提交接口，提交接口使用 `require_permission(PERM_QUALITY_FIRST_ARTICLES_SCAN_REVIEW)`。

- [ ] **Step 5: 运行 API 测试**

Run: `cd backend; pytest tests/test_first_article_scan_review_api.py -q`

Expected: PASS。

- [ ] **Step 6: 回归生产模块测试**

Run: `cd backend; pytest tests/test_production_module_integration.py -q`

Expected: PASS。

- [ ] **Step 7: 提交**

```bash
git add backend/app/schemas/production.py backend/app/api/v1/endpoints/production.py backend/tests/test_first_article_scan_review_api.py
git commit -m "新增首件扫码复核接口"
```

---

### Task 5: Flutter 模型与服务

**Files:**
- Modify: `frontend/lib/features/production/models/production_models.dart`
- Modify: `frontend/lib/features/production/services/production_service.dart`
- Test: `frontend/test/models/production_models_test.dart`
- Test: `frontend/test/services/production_service_test.dart`

- [ ] **Step 1: 写模型失败测试**

在 `frontend/test/models/production_models_test.dart` 增加：

```dart
test('FirstArticleReviewSessionResult parses scan review response', () {
  final result = FirstArticleReviewSessionResult.fromJson({
    'session_id': 7,
    'review_url': '/first-article-review?token=abc',
    'expires_at': '2026-04-25T12:05:00Z',
    'status': 'pending',
    'first_article_record_id': null,
    'reviewer_user_id': null,
    'reviewed_at': null,
    'review_remark': null,
  });

  expect(result.sessionId, 7);
  expect(result.reviewUrl, '/first-article-review?token=abc');
  expect(result.status, 'pending');
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd frontend; flutter test test/models/production_models_test.dart`

Expected: FAIL，提示模型不存在。

- [ ] **Step 3: 新增 Dart 模型**

在 `production_models.dart` 增加：

```dart
class FirstArticleReviewSessionResult {
  const FirstArticleReviewSessionResult({
    required this.sessionId,
    required this.reviewUrl,
    required this.expiresAt,
    required this.status,
    required this.firstArticleRecordId,
    required this.reviewerUserId,
    required this.reviewedAt,
    required this.reviewRemark,
  });

  final int sessionId;
  final String? reviewUrl;
  final DateTime expiresAt;
  final String status;
  final int? firstArticleRecordId;
  final int? reviewerUserId;
  final DateTime? reviewedAt;
  final String? reviewRemark;

  factory FirstArticleReviewSessionResult.fromJson(Map<String, dynamic> json) {
    return FirstArticleReviewSessionResult(
      sessionId: (json['session_id'] as int?) ?? 0,
      reviewUrl: json['review_url'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      status: (json['status'] as String?) ?? '',
      firstArticleRecordId: json['first_article_record_id'] as int?,
      reviewerUserId: json['reviewer_user_id'] as int?,
      reviewedAt: _parseDateOrNull(json['reviewed_at']),
      reviewRemark: json['review_remark'] as String?,
    );
  }
}
```

- [ ] **Step 4: 写服务失败测试**

在 `frontend/test/services/production_service_test.dart` 增加：

```dart
test('createFirstArticleReviewSession posts operator draft', () async {
  final service = ProductionService(session);
  final result = await service.createFirstArticleReviewSession(
    orderId: 9,
    orderProcessId: 3,
    pipelineInstanceId: null,
    templateId: null,
    checkContent: '外观无划伤',
    testValue: '长度 10.01',
    participantUserIds: const [1, 2],
    assistAuthorizationId: null,
  );

  expect(result.status, 'pending');
  expect(lastRequestPath, '/production/orders/9/first-article/review-sessions');
  expect(lastRequestBody['check_content'], '外观无划伤');
});
```

- [ ] **Step 5: 实现服务方法**

在 `production_service.dart` 增加：

```dart
  Future<FirstArticleReviewSessionResult> createFirstArticleReviewSession({
    required int orderId,
    required int orderProcessId,
    required int? pipelineInstanceId,
    required int? templateId,
    required String checkContent,
    required String testValue,
    required List<int> participantUserIds,
    required int? assistAuthorizationId,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/first-article/review-sessions');
    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'order_process_id': orderProcessId,
            'pipeline_instance_id': pipelineInstanceId,
            'template_id': templateId,
            'check_content': checkContent,
            'test_value': testValue,
            'participant_user_ids': participantUserIds,
            'assist_authorization_id': assistAuthorizationId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(_extractErrorMessage(body, response.statusCode), response.statusCode);
    }
    return FirstArticleReviewSessionResult.fromJson(
      (body['data'] as Map<String, dynamic>?) ?? const {},
    );
  }
```

同步补充 `refreshFirstArticleReviewSession`、`getFirstArticleReviewSessionStatus`、`submitFirstArticleReviewResult`。

- [ ] **Step 6: 运行前端模型与服务测试**

Run: `cd frontend; flutter test test/models/production_models_test.dart test/services/production_service_test.dart`

Expected: PASS。

- [ ] **Step 7: 提交**

```bash
git add frontend/lib/features/production/models/production_models.dart frontend/lib/features/production/services/production_service.dart frontend/test/models/production_models_test.dart frontend/test/services/production_service_test.dart
git commit -m "接入首件扫码复核前端服务"
```

---

### Task 6: 操作员端首件录入页面

**Files:**
- Modify: `frontend/lib/features/production/presentation/production_first_article_page.dart`
- Test: `frontend/test/widgets/production_first_article_page_test.dart`

- [ ] **Step 1: 写页面失败测试**

在 `frontend/test/widgets/production_first_article_page_test.dart` 增加：

```dart
testWidgets('shows QR waiting state after operator creates review session', (tester) async {
  final service = _FakeProductionService()
    ..reviewSessionResult = FirstArticleReviewSessionResult(
      sessionId: 88,
      reviewUrl: '/first-article-review?token=abc',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      status: 'pending',
      firstArticleRecordId: null,
      reviewerUserId: null,
      reviewedAt: null,
      reviewRemark: null,
    );

  await tester.pumpWidget(buildPage(service: service));
  await tester.enterText(find.widgetWithText(TextField, '首件内容'), '外观无划伤');
  await tester.enterText(find.widgetWithText(TextField, '首件测试值'), '长度 10.01');
  expect(find.text('首件检验码'), findsNothing);

  await tester.tap(find.text('发起扫码复核'));
  await tester.pumpAndSettle();

  expect(find.text('等待质检扫码复核'), findsOneWidget);
  expect(find.text('刷新二维码'), findsOneWidget);
  expect(service.lastReviewDraft?.checkContent, '外观无划伤');
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd frontend; flutter test test/widgets/production_first_article_page_test.dart`

Expected: FAIL，仍存在检验码输入且无扫码状态。

- [ ] **Step 3: 改造页面状态**

在 `production_first_article_page.dart` 删除 `_verificationCodeController`，增加：

```dart
FirstArticleReviewSessionResult? _reviewSession;
String? _reviewRejectMessage;
Timer? _reviewPollTimer;
```

在 `dispose()` 中取消 `_reviewPollTimer`。

- [ ] **Step 4: 改造提交方法为发起扫码复核**

将 `_submit()` 改名为 `_startScanReview()`，调用 `createFirstArticleReviewSession`。保留首件内容和测试值非空校验，不再校验首件检验码。

- [ ] **Step 5: 增加二维码等待 UI**

在检验结果区域替换原检验码 TextField：

```dart
Widget _buildScanReviewPanel() {
  final session = _reviewSession;
  if (session == null) {
    return const SizedBox.shrink();
  }
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('等待质检扫码复核', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SelectableText(session.reviewUrl ?? '-'),
          const SizedBox(height: 12),
          Text('有效期至：${_formatDateTime(session.expiresAt)}'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _refreshScanReview,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新二维码'),
          ),
        ],
      ),
    ),
  );
}
```

首版可先显示 URL 文本；二维码渲染库接入放在 Task 8 统一做视觉完善。

- [ ] **Step 6: 处理 rejected 与 approved**

轮询会话状态时：

```dart
if (result.status == 'approved') {
  Navigator.of(context).pop(true);
}
if (result.status == 'rejected') {
  setState(() {
    _reviewSession = null;
    _reviewRejectMessage = result.reviewRemark ?? '质检复核不合格，请修改后重新发起';
  });
}
```

- [ ] **Step 7: 运行页面测试**

Run: `cd frontend; flutter test test/widgets/production_first_article_page_test.dart`

Expected: PASS。

- [ ] **Step 8: 提交**

```bash
git add frontend/lib/features/production/presentation/production_first_article_page.dart frontend/test/widgets/production_first_article_page_test.dart
git commit -m "改造操作员首件扫码复核入口"
```

---

### Task 7: 手机端极简扫码复核页面

**Files:**
- Create: `frontend/lib/features/production/presentation/first_article_scan_review_mobile_page.dart`
- Modify: `frontend/lib/main.dart`
- Test: `frontend/test/widgets/first_article_scan_review_mobile_page_test.dart`

- [ ] **Step 1: 写手机页失败测试**

创建 `frontend/test/widgets/first_article_scan_review_mobile_page_test.dart`：

```dart
testWidgets('mobile scan review page logs in and submits passed result', (tester) async {
  final authService = _FakeAuthService(token: 'mobile-token');
  final productionService = _FakeProductionService()
    ..detail = FirstArticleReviewSessionDetail(
      sessionId: 88,
      status: 'pending',
      orderCode: 'MO-001',
      productName: '产品A',
      processName: '装配',
      operatorUsername: 'operator',
      checkContent: '外观无划伤',
      testValue: '长度 10.01',
      parameters: const [],
    );

  await tester.pumpWidget(buildMobilePage(
    token: 'scan-token',
    authService: authService,
    productionService: productionService,
  ));

  await tester.enterText(find.widgetWithText(TextField, '账号'), 'qa');
  await tester.enterText(find.widgetWithText(TextField, '密码'), 'pw');
  await tester.tap(find.text('登录'));
  await tester.pumpAndSettle();

  expect(find.text('MO-001'), findsOneWidget);
  expect(find.text('长度 10.01'), findsOneWidget);
  await tester.tap(find.text('合格'));
  await tester.tap(find.text('提交复核'));
  await tester.pumpAndSettle();

  expect(find.text('复核已提交'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd frontend; flutter test test/widgets/first_article_scan_review_mobile_page_test.dart`

Expected: FAIL，页面不存在。

- [ ] **Step 3: 新建极简页面**

创建 `first_article_scan_review_mobile_page.dart`，实现：

```dart
class FirstArticleScanReviewMobilePage extends StatefulWidget {
  const FirstArticleScanReviewMobilePage({
    super.key,
    required this.baseUrl,
    required this.token,
    this.authService,
    this.productionServiceFactory,
  });

  final String baseUrl;
  final String token;
  final AuthService? authService;
  final ProductionService Function(AppSession session)? productionServiceFactory;

  @override
  State<FirstArticleScanReviewMobilePage> createState() =>
      _FirstArticleScanReviewMobilePageState();
}
```

页面内部只实现登录表单、详情展示、合格/不合格选择、备注和提交按钮。

- [ ] **Step 4: 注册路由**

在 `frontend/lib/main.dart` 或当前路由入口处解析：

```dart
final uri = Uri.base;
if (uri.path == '/first-article-review') {
  final token = uri.queryParameters['token'] ?? '';
  runApp(FirstArticleScanReviewMobileApp(token: token));
  return;
}
```

- [ ] **Step 5: 运行手机页测试**

Run: `cd frontend; flutter test test/widgets/first_article_scan_review_mobile_page_test.dart`

Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add frontend/lib/features/production/presentation/first_article_scan_review_mobile_page.dart frontend/lib/main.dart frontend/test/widgets/first_article_scan_review_mobile_page_test.dart
git commit -m "新增首件扫码复核手机页"
```

---

### Task 8: 二维码渲染、轮询与端到端验证

**Files:**
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/features/production/presentation/production_first_article_page.dart`
- Test: `frontend/integration_test/first_article_scan_review_flow_test.dart`
- Modify: `evidence/2026-04-25_扫码首件复核实现计划.md`

- [ ] **Step 1: 增加二维码依赖**

在 `frontend/pubspec.yaml` 添加稳定二维码渲染库：

```yaml
dependencies:
  qr_flutter: ^4.1.0
```

Run: `cd frontend; flutter pub get`

Expected: 成功解析依赖。

- [ ] **Step 2: 替换 URL 文本为二维码**

在操作员端扫码等待区域加入：

```dart
QrImageView(
  data: session.reviewUrl ?? '',
  version: QrVersions.auto,
  size: 240,
)
```

保留 `SelectableText(session.reviewUrl ?? '-')` 作为调试/无法扫码时的备用文本。

- [ ] **Step 3: 增加轮询**

在 `_startScanReview()` 成功后启动：

```dart
void _startReviewPolling() {
  _reviewPollTimer?.cancel();
  _reviewPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
    _loadReviewSessionStatus();
  });
}
```

在 approved、rejected、expired、cancelled 状态停止轮询。

- [ ] **Step 4: 写集成测试**

创建 `frontend/integration_test/first_article_scan_review_flow_test.dart`，覆盖：

```dart
testWidgets('operator creates scan review and reviewer approves', (tester) async {
  await tester.pumpWidget(buildIntegrationAppWithScanReviewFakes());
  await tester.tap(find.text('生产'));
  await tester.tap(find.text('订单查询'));
  await tester.tap(find.text('开始首件'));
  await tester.enterText(find.widgetWithText(TextField, '首件内容'), '外观无划伤');
  await tester.enterText(find.widgetWithText(TextField, '首件测试值'), '长度 10.01');
  await tester.tap(find.text('发起扫码复核'));
  await tester.pumpAndSettle();

  expect(find.byType(QrImageView), findsOneWidget);
  fakeScanReviewBackend.approveLatestSession();
  await tester.pump(const Duration(seconds: 4));

  expect(find.text('开始首件成功'), findsOneWidget);
});
```

- [ ] **Step 5: 运行 Flutter 验证**

Run: `cd frontend; flutter test test/widgets/production_first_article_page_test.dart test/widgets/first_article_scan_review_mobile_page_test.dart`

Expected: PASS。

Run: `cd frontend; flutter test integration_test/first_article_scan_review_flow_test.dart`

Expected: PASS。

- [ ] **Step 6: 运行后端验证**

Run: `cd backend; pytest tests/test_first_article_scan_review_service.py tests/test_first_article_scan_review_api.py tests/test_production_module_integration.py -q`

Expected: PASS。

- [ ] **Step 7: 更新 evidence 并提交**

在 implementation evidence 中记录所有命令、结果、失败重试和迁移口径“无迁移，直接替换”。

```bash
git add frontend/pubspec.yaml frontend/pubspec.lock frontend/lib/features/production/presentation/production_first_article_page.dart frontend/integration_test/first_article_scan_review_flow_test.dart evidence/2026-04-25_扫码首件复核实现计划.md
git commit -m "补齐首件扫码复核二维码与集成验证"
```

---

## 计划自检

- Spec 覆盖：权限、5 分钟有效期、刷新作废、手机极简登录、只读复核详情、合格自动生效、不合格退回、审计与测试均已映射到任务。
- 未决字段：无。
- 类型一致性：会话状态统一使用 `pending / approved / rejected / expired / cancelled`；能力码统一使用 `quality.first_articles.scan_review`。
- 迁移口径：无迁移，直接替换；历史首件记录保留原样。

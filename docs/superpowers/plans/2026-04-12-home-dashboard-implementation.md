# 首页工作台实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把现有首页改造成“待办中枢型”工作台，新增后端聚合接口、前端首页卡片、跳转过滤态与 40 并发 P95 门禁覆盖。

**Architecture:** 后端在 `UI` 域新增 `GET /api/v1/ui/home-dashboard` 聚合接口，直接复用消息、生产、质量服务返回首页摘要；前端在 `shell` 域新增首页模型与服务，由 `MainShellPage` 负责加载和刷新，将数据传给拆分后的首页卡片组件。首页保持统一骨架和现有浅色 `Material 3` 风格，桌面大屏首屏无纵向滚动，待办只展示 4 条高优事项，其余通过跳转进入目标模块处理。

**Tech Stack:** FastAPI、Pydantic、SQLAlchemy、pytest、Flutter、flutter_test、integration_test、`python -m tools.project_toolkit backend-capacity-gate`

---

## 文件结构

- Create: `backend/app/schemas/home_dashboard.py`
  首页工作台响应模型，定义待办摘要、待办项、风险项、KPI 项和降级块。

- Create: `backend/app/services/home_dashboard_service.py`
  首页聚合逻辑，统一拼装消息摘要、风险、KPI 和降级结果。

- Modify: `backend/app/api/v1/endpoints/ui.py`
  增加 `GET /api/v1/ui/home-dashboard` 端点。

- Create: `backend/tests/test_home_dashboard_service_unit.py`
  单测首页排序、截断、权限裁剪和降级逻辑。

- Create: `backend/tests/test_ui_home_dashboard_integration.py`
  集成测试首页聚合接口结构与不同角色内容。

- Create: `frontend/lib/features/shell/models/home_dashboard_models.dart`
  首页工作台前端数据模型。

- Create: `frontend/lib/features/shell/services/home_dashboard_service.dart`
  首页聚合接口请求与响应映射。

- Create: `frontend/lib/features/shell/presentation/widgets/home_dashboard_header.dart`
  首页顶部状态条。

- Create: `frontend/lib/features/shell/presentation/widgets/home_dashboard_todo_card.dart`
  首页主待办卡。

- Create: `frontend/lib/features/shell/presentation/widgets/home_dashboard_risk_card.dart`
  首页风险卡。

- Create: `frontend/lib/features/shell/presentation/widgets/home_dashboard_kpi_card.dart`
  首页 KPI 卡。

- Modify: `frontend/lib/features/shell/presentation/home_page.dart`
  改为组合式首页，移除旧的欢迎卡 + 快捷跳转布局。

- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
  注入首页服务、维护首页数据状态，并在首页可见时刷新。

- Modify: `frontend/lib/features/message/presentation/message_center_page.dart`
  增加首页“查看全部待办”过滤态支持。

- Modify: `frontend/lib/features/production/presentation/production_order_query_page.dart`
  增加首页“生产异常”过滤态支持。

- Modify: `frontend/lib/features/quality/presentation/quality_data_page.dart`
  增加首页“质量预警/KPI”过滤态支持。

- Modify: `frontend/lib/features/equipment/presentation/maintenance_execution_page.dart`
  复用现有 payload 机制，补齐首页跳转入口测试。

- Create: `frontend/test/services/home_dashboard_service_test.dart`
  首页服务解析与错误处理测试。

- Modify: `frontend/test/widgets/home_page_test.dart`
  首页工作台 widget test，覆盖桌面首屏布局、空态、点击跳转。

- Modify: `frontend/test/widgets/main_shell_page_test.dart`
  首页刷新和事件触发测试。

- Create: `frontend/integration_test/home_dashboard_flow_test.dart`
  首页工作台端到端链路测试，避免继续膨胀现有大脚本。

- Modify: `tools/perf/scenarios/other_authenticated_read_scenarios.json`
  新增 `ui-home-dashboard` 场景。

- Modify: `tools/perf/scenarios/combined_40_scan.json`
  如项目当前使用聚合场景总表，同步追加首页场景，避免门禁遗漏。

- Modify: `evidence/task_log_20260412_home_dashboard_plan.md`
  记录计划文档路径、自检结果与交付结论。

### Task 1: 后端 Schema 与聚合服务骨架

**Files:**
- Create: `backend/app/schemas/home_dashboard.py`
- Create: `backend/app/services/home_dashboard_service.py`
- Test: `backend/tests/test_home_dashboard_service_unit.py`

- [ ] **Step 1: 写失败的单元测试，锁定待办排序、截断和降级行为**

```python
from datetime import UTC, datetime, timedelta

from app.services.home_dashboard_service import (
    DashboardMessageSeed,
    build_dashboard_todo_summary,
    select_dashboard_todo_items,
)


def test_select_dashboard_todo_items_orders_by_overdue_priority_and_publish_time() -> None:
    now = datetime.now(UTC)
    seeds = [
        DashboardMessageSeed(
            id=1,
            title="普通待办",
            source_module="production",
            priority="normal",
            published_at=now - timedelta(minutes=30),
            overdue=False,
            target_page_code="production",
            target_tab_code="production_order_query",
            target_route_payload_json=None,
        ),
        DashboardMessageSeed(
            id=2,
            title="高优待办",
            source_module="quality",
            priority="urgent",
            published_at=now - timedelta(minutes=20),
            overdue=False,
            target_page_code="quality",
            target_tab_code="quality_data_query",
            target_route_payload_json=None,
        ),
        DashboardMessageSeed(
            id=3,
            title="超时待办",
            source_module="user",
            priority="important",
            published_at=now - timedelta(minutes=10),
            overdue=True,
            target_page_code="user",
            target_tab_code="registration_approval",
            target_route_payload_json=None,
        ),
    ]

    result = select_dashboard_todo_items(seeds, limit=2)

    assert [item.id for item in result] == [3, 2]


def test_build_dashboard_todo_summary_counts_four_summary_numbers() -> None:
    summary = build_dashboard_todo_summary(
        total_count=12,
        pending_approval_count=2,
        high_priority_count=3,
        exception_count=5,
        overdue_count=1,
    )

    assert summary.total_count == 12
    assert summary.pending_approval_count == 2
    assert summary.high_priority_count == 3
    assert summary.exception_count == 5
    assert summary.overdue_count == 1
```

- [ ] **Step 2: 运行单测，确认当前缺少首页聚合类型和函数**

Run: `pytest backend/tests/test_home_dashboard_service_unit.py -q`

Expected: FAIL，出现 `ModuleNotFoundError` 或 `ImportError`，指出 `home_dashboard_service` / `home_dashboard.py` 尚未存在。

- [ ] **Step 3: 实现最小后端 schema 与服务骨架**

```python
# backend/app/schemas/home_dashboard.py
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class HomeDashboardTodoSummary(BaseModel):
    total_count: int
    pending_approval_count: int
    high_priority_count: int
    exception_count: int
    overdue_count: int


class HomeDashboardMetricItem(BaseModel):
    code: str
    label: str
    value: str
    target_page_code: str | None = None
    target_tab_code: str | None = None
    target_route_payload_json: str | None = None


class HomeDashboardTodoItem(BaseModel):
    id: int
    title: str
    category_label: str
    priority_label: str
    source_module: str | None = None
    target_page_code: str | None = None
    target_tab_code: str | None = None
    target_route_payload_json: str | None = None


class HomeDashboardDegradedBlock(BaseModel):
    code: str
    message: str


class HomeDashboardResult(BaseModel):
    generated_at: datetime
    notice_count: int
    todo_summary: HomeDashboardTodoSummary
    todo_items: list[HomeDashboardTodoItem]
    risk_items: list[HomeDashboardMetricItem]
    kpi_items: list[HomeDashboardMetricItem]
    degraded_blocks: list[HomeDashboardDegradedBlock]
```

```python
# backend/app/services/home_dashboard_service.py
from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from app.schemas.home_dashboard import HomeDashboardTodoItem, HomeDashboardTodoSummary


@dataclass(frozen=True)
class DashboardMessageSeed:
    id: int
    title: str
    source_module: str | None
    priority: str
    published_at: datetime | None
    overdue: bool
    target_page_code: str | None
    target_tab_code: str | None
    target_route_payload_json: str | None


_PRIORITY_ORDER = {"urgent": 0, "important": 1, "normal": 2}
_CATEGORY_LABELS = {
    "user": "审批",
    "production": "生产",
    "quality": "质量",
    "equipment": "设备",
    "message": "消息",
}


def build_dashboard_todo_summary(
    *,
    total_count: int,
    pending_approval_count: int,
    high_priority_count: int,
    exception_count: int,
    overdue_count: int,
) -> HomeDashboardTodoSummary:
    return HomeDashboardTodoSummary(
        total_count=total_count,
        pending_approval_count=pending_approval_count,
        high_priority_count=high_priority_count,
        exception_count=exception_count,
        overdue_count=overdue_count,
    )


def select_dashboard_todo_items(
    seeds: list[DashboardMessageSeed],
    *,
    limit: int = 4,
) -> list[HomeDashboardTodoItem]:
    ordered = sorted(
        seeds,
        key=lambda item: (
            0 if item.overdue else 1,
            _PRIORITY_ORDER.get(item.priority, 9),
            -(item.published_at or datetime.min.replace(tzinfo=UTC)).timestamp(),
        ),
    )[:limit]
    return [
        HomeDashboardTodoItem(
            id=item.id,
            title=item.title,
            category_label=_CATEGORY_LABELS.get(item.source_module or "", "待办"),
            priority_label="超时" if item.overdue else ("高优" if item.priority in {"urgent", "important"} else "普通"),
            source_module=item.source_module,
            target_page_code=item.target_page_code,
            target_tab_code=item.target_tab_code,
            target_route_payload_json=item.target_route_payload_json,
        )
        for item in ordered
    ]
```

- [ ] **Step 4: 再次运行单测，确认排序和摘要结构通过**

Run: `pytest backend/tests/test_home_dashboard_service_unit.py -q`

Expected: PASS，输出 `2 passed`。

- [ ] **Step 5: 提交后端首页聚合骨架**

```bash
git add backend/app/schemas/home_dashboard.py backend/app/services/home_dashboard_service.py backend/tests/test_home_dashboard_service_unit.py
git commit -m "功能：首页工作台后端聚合骨架"
```

### Task 2: 后端聚合逻辑与 UI 端点

**Files:**
- Modify: `backend/app/services/home_dashboard_service.py`
- Modify: `backend/app/api/v1/endpoints/ui.py`
- Test: `backend/tests/test_ui_home_dashboard_integration.py`

- [ ] **Step 1: 写失败的集成测试，锁定接口结构与角色裁剪**

```python
from tests.base import BaseAPITestCase


class TestUiHomeDashboardIntegration(BaseAPITestCase):
    def test_home_dashboard_returns_todo_risk_and_kpi_blocks(self) -> None:
        response = self.client.get(
            "/api/v1/ui/home-dashboard",
            headers=self._headers(),
        )

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        self.assertIn("generated_at", payload)
        self.assertIn("todo_summary", payload)
        self.assertIn("todo_items", payload)
        self.assertIn("risk_items", payload)
        self.assertIn("kpi_items", payload)
        self.assertIn("degraded_blocks", payload)
        self.assertLessEqual(len(payload["todo_items"]), 4)

    def test_home_dashboard_hides_production_blocks_when_page_not_visible(self) -> None:
        response = self.client.get(
            "/api/v1/ui/home-dashboard",
            headers=self._restricted_headers(),
        )

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        risk_codes = {item["code"] for item in payload["risk_items"]}
        self.assertNotIn("production_exception", risk_codes)
```

- [ ] **Step 2: 运行集成测试，确认端点尚不存在**

Run: `pytest backend/tests/test_ui_home_dashboard_integration.py -q`

Expected: FAIL，出现 `404` 或导入失败，表明 `/api/v1/ui/home-dashboard` 还未实现。

- [ ] **Step 3: 在服务与 UI 端点中实现首页聚合**

```python
# backend/app/services/home_dashboard_service.py
from app.schemas.home_dashboard import (
    HomeDashboardDegradedBlock,
    HomeDashboardMetricItem,
    HomeDashboardResult,
)
from app.services.authz_service import get_authz_snapshot
from app.services.message_service import get_message_summary, list_messages
from app.services.production_data_query_service import build_today_filters, get_today_realtime_data
from app.services.production_statistics_service import get_overview_stats
from app.services.quality_service import get_quality_overview


def build_home_dashboard(db: Session, *, current_user: User) -> HomeDashboardResult:
    degraded_blocks: list[HomeDashboardDegradedBlock] = []
    generated_at = datetime.now(UTC)
    snapshot = get_authz_snapshot(db, user=current_user)

    summary_dict = get_message_summary(db, user_id=current_user.id)
    todo_rows, _ = list_messages(
        db,
        user_id=current_user.id,
        current_user=current_user,
        page=1,
        page_size=20,
        todo_only=True,
        active_only=True,
    )

    todo_seeds = [
        DashboardMessageSeed(
            id=row.id,
            title=row.title,
            source_module=row.source_module,
            priority=row.priority,
            published_at=row.published_at,
            overdue=row.priority == "urgent",
            target_page_code=row.target_page_code,
            target_tab_code=row.target_tab_code,
            target_route_payload_json=row.target_route_payload_json,
        )
        for row in todo_rows
    ]

    risk_items: list[HomeDashboardMetricItem] = []
    kpi_items: list[HomeDashboardMetricItem] = []

    try:
        if "production" in snapshot.visible_sidebar_codes:
            production_overview = get_overview_stats(db)
            production_today = get_today_realtime_data(
                db,
                filters=build_today_filters(
                    stat_mode="main_order",
                    product_ids=None,
                    stage_ids=None,
                    process_ids=None,
                    operator_user_ids=None,
                    order_status=None,
                ),
            )
            risk_items.append(
                HomeDashboardMetricItem(
                    code="production_exception",
                    label="生产异常",
                    value=str(summary_dict["todo_unread_count"]),
                    target_page_code="production",
                    target_tab_code="production_order_query",
                    target_route_payload_json='{"dashboard_filter":"exception"}',
                )
            )
            kpi_items.extend(
                [
                    HomeDashboardMetricItem(
                        code="wip_orders",
                        label="在制订单",
                        value=str(production_overview["in_progress_orders"]),
                        target_page_code="production",
                        target_tab_code="production_data_query",
                    ),
                    HomeDashboardMetricItem(
                        code="today_quantity",
                        label="今日产量",
                        value=str(production_today["summary"]["total_quantity"]),
                        target_page_code="production",
                        target_tab_code="production_data_query",
                    ),
                ]
            )
    except Exception:
        degraded_blocks.append(HomeDashboardDegradedBlock(code="production", message="生产摘要加载失败"))

    try:
        if "quality" in snapshot.visible_sidebar_codes:
            quality_overview = get_quality_overview(
                db,
                start_date=None,
                end_date=None,
                product_name=None,
                process_code=None,
                operator_username=None,
                result_filter=None,
            )
            risk_items.append(
                HomeDashboardMetricItem(
                    code="quality_warning",
                    label="质量预警",
                    value=str(quality_overview["failed_total"]),
                    target_page_code="quality",
                    target_tab_code="quality_data_query",
                    target_route_payload_json='{"dashboard_filter":"warning"}',
                )
            )
            kpi_items.extend(
                [
                    HomeDashboardMetricItem(
                        code="first_article_pass_rate",
                        label="首件通过率",
                        value=f'{quality_overview["pass_rate_percent"]}%',
                        target_page_code="quality",
                        target_tab_code="quality_data_query",
                    ),
                    HomeDashboardMetricItem(
                        code="scrap_total",
                        label="报废数",
                        value=str(quality_overview["scrap_total"]),
                        target_page_code="quality",
                        target_tab_code="quality_data_query",
                    ),
                ]
            )
    except Exception:
        degraded_blocks.append(HomeDashboardDegradedBlock(code="quality", message="质量摘要加载失败"))

    return HomeDashboardResult(
        generated_at=generated_at,
        notice_count=summary_dict["unread_count"],
        todo_summary=build_dashboard_todo_summary(
            total_count=summary_dict["total_count"],
            pending_approval_count=summary_dict["todo_unread_count"],
            high_priority_count=summary_dict["urgent_unread_count"],
            exception_count=sum(int(item.value) for item in risk_items if item.code != "high_priority_unconfirmed"),
            overdue_count=sum(1 for item in todo_seeds if item.overdue),
        ),
        todo_items=select_dashboard_todo_items(todo_seeds, limit=4),
        risk_items=risk_items,
        kpi_items=kpi_items,
        degraded_blocks=degraded_blocks,
    )
```

```python
# backend/app/api/v1/endpoints/ui.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, get_db
from app.models.user import User
from app.schemas.common import ApiResponse, success_response
from app.schemas.home_dashboard import HomeDashboardResult
from app.schemas.page_catalog import PageCatalogItem, PageCatalogResult
from app.services.home_dashboard_service import build_home_dashboard
from app.services.page_catalog_service import list_page_catalog_items


@router.get("/home-dashboard", response_model=ApiResponse[HomeDashboardResult])
def get_home_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ApiResponse[HomeDashboardResult]:
    payload = build_home_dashboard(db, current_user=current_user)
    return success_response(payload)
```

- [ ] **Step 4: 运行后端单测与集成测试**

Run: `pytest backend/tests/test_home_dashboard_service_unit.py backend/tests/test_ui_home_dashboard_integration.py -q`

Expected: PASS，输出 `4 passed` 或更高，通过首页聚合逻辑与接口结构检查。

- [ ] **Step 5: 提交首页聚合接口**

```bash
git add backend/app/api/v1/endpoints/ui.py backend/app/services/home_dashboard_service.py backend/tests/test_ui_home_dashboard_integration.py
git commit -m "功能：首页工作台聚合接口"
```

### Task 3: 首页前端模型与服务

**Files:**
- Create: `frontend/lib/features/shell/models/home_dashboard_models.dart`
- Create: `frontend/lib/features/shell/services/home_dashboard_service.dart`
- Test: `frontend/test/services/home_dashboard_service_test.dart`

- [ ] **Step 1: 写失败的前端服务测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

void main() {
  test('首页工作台服务能解析待办、风险和 KPI', () {
    final result = HomeDashboardData.fromJson({
      'generated_at': '2026-04-12T12:00:00Z',
      'notice_count': 2,
      'todo_summary': {
        'total_count': 12,
        'pending_approval_count': 2,
        'high_priority_count': 2,
        'exception_count': 6,
        'overdue_count': 1,
      },
      'todo_items': [
        {
          'id': 1,
          'title': '待办 A',
          'category_label': '审批',
          'priority_label': '高优',
          'source_module': 'user',
          'target_page_code': 'user',
          'target_tab_code': 'registration_approval',
          'target_route_payload_json': '{"request_id":1}',
        }
      ],
      'risk_items': [],
      'kpi_items': [],
      'degraded_blocks': [],
    });

    expect(result.noticeCount, 2);
    expect(result.todoItems.single.title, '待办 A');
    expect(result.todoSummary.exceptionCount, 6);
  });
}
```

- [ ] **Step 2: 运行前端服务测试，确认模型和服务尚未创建**

Run: `flutter test test/services/home_dashboard_service_test.dart`

Expected: FAIL，出现 `Target of URI doesn't exist` 或 `Undefined class 'HomeDashboardData'`。

- [ ] **Step 3: 实现前端模型与服务**

```dart
// frontend/lib/features/shell/models/home_dashboard_models.dart
class HomeDashboardTodoSummary {
  const HomeDashboardTodoSummary({
    required this.totalCount,
    required this.pendingApprovalCount,
    required this.highPriorityCount,
    required this.exceptionCount,
    required this.overdueCount,
  });

  final int totalCount;
  final int pendingApprovalCount;
  final int highPriorityCount;
  final int exceptionCount;
  final int overdueCount;

  factory HomeDashboardTodoSummary.fromJson(Map<String, dynamic> json) {
    return HomeDashboardTodoSummary(
      totalCount: (json['total_count'] as int?) ?? 0,
      pendingApprovalCount: (json['pending_approval_count'] as int?) ?? 0,
      highPriorityCount: (json['high_priority_count'] as int?) ?? 0,
      exceptionCount: (json['exception_count'] as int?) ?? 0,
      overdueCount: (json['overdue_count'] as int?) ?? 0,
    );
  }
}

class HomeDashboardMetricItem {
  const HomeDashboardMetricItem({
    required this.code,
    required this.label,
    required this.value,
    this.targetPageCode,
    this.targetTabCode,
    this.targetRoutePayloadJson,
  });

  final String code;
  final String label;
  final String value;
  final String? targetPageCode;
  final String? targetTabCode;
  final String? targetRoutePayloadJson;

  factory HomeDashboardMetricItem.fromJson(Map<String, dynamic> json) {
    return HomeDashboardMetricItem(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: '${json['value'] ?? ''}',
      targetPageCode: json['target_page_code'] as String?,
      targetTabCode: json['target_tab_code'] as String?,
      targetRoutePayloadJson: json['target_route_payload_json'] as String?,
    );
  }
}

class HomeDashboardTodoItem {
  const HomeDashboardTodoItem({
    required this.id,
    required this.title,
    required this.categoryLabel,
    required this.priorityLabel,
    this.sourceModule,
    this.targetPageCode,
    this.targetTabCode,
    this.targetRoutePayloadJson,
  });

  final int id;
  final String title;
  final String categoryLabel;
  final String priorityLabel;
  final String? sourceModule;
  final String? targetPageCode;
  final String? targetTabCode;
  final String? targetRoutePayloadJson;

  factory HomeDashboardTodoItem.fromJson(Map<String, dynamic> json) {
    return HomeDashboardTodoItem(
      id: (json['id'] as int?) ?? 0,
      title: json['title'] as String? ?? '',
      categoryLabel: json['category_label'] as String? ?? '',
      priorityLabel: json['priority_label'] as String? ?? '',
      sourceModule: json['source_module'] as String?,
      targetPageCode: json['target_page_code'] as String?,
      targetTabCode: json['target_tab_code'] as String?,
      targetRoutePayloadJson: json['target_route_payload_json'] as String?,
    );
  }
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.generatedAt,
    required this.noticeCount,
    required this.todoSummary,
    required this.todoItems,
    required this.riskItems,
    required this.kpiItems,
    required this.degradedBlocks,
  });

  final DateTime? generatedAt;
  final int noticeCount;
  final HomeDashboardTodoSummary todoSummary;
  final List<HomeDashboardTodoItem> todoItems;
  final List<HomeDashboardMetricItem> riskItems;
  final List<HomeDashboardMetricItem> kpiItems;
  final List<String> degradedBlocks;

  factory HomeDashboardData.fromJson(Map<String, dynamic> json) {
    return HomeDashboardData(
      generatedAt: json['generated_at'] == null
          ? null
          : DateTime.tryParse(json['generated_at'] as String),
      noticeCount: (json['notice_count'] as int?) ?? 0,
      todoSummary: HomeDashboardTodoSummary.fromJson(
        json['todo_summary'] as Map<String, dynamic>? ?? const {},
      ),
      todoItems: (json['todo_items'] as List<dynamic>? ?? const [])
          .map((item) => HomeDashboardTodoItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      riskItems: (json['risk_items'] as List<dynamic>? ?? const [])
          .map((item) => HomeDashboardMetricItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      kpiItems: (json['kpi_items'] as List<dynamic>? ?? const [])
          .map((item) => HomeDashboardMetricItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      degradedBlocks: (json['degraded_blocks'] as List<dynamic>? ?? const [])
          .map((item) => (item as Map<String, dynamic>)['code'] as String? ?? '')
          .toList(),
    );
  }
}
```

```dart
// frontend/lib/features/shell/services/home_dashboard_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

class HomeDashboardService {
  HomeDashboardService(this.session);

  final AppSession session;

  Future<HomeDashboardData> load() async {
    final uri = Uri.parse('${session.baseUrl}/ui/home-dashboard');
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    });
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        body['detail']?.toString() ?? '加载首页工作台失败',
        response.statusCode,
      );
    }
    return HomeDashboardData.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }
}
```

- [ ] **Step 4: 运行前端服务测试**

Run: `flutter test test/services/home_dashboard_service_test.dart`

Expected: PASS，输出 `1 passed`。

- [ ] **Step 5: 提交首页前端模型与服务**

```bash
git add frontend/lib/features/shell/models/home_dashboard_models.dart frontend/lib/features/shell/services/home_dashboard_service.dart frontend/test/services/home_dashboard_service_test.dart
git commit -m "功能：首页工作台前端模型与服务"
```

### Task 4: 首页组件化重构与桌面首屏布局

**Files:**
- Create: `frontend/lib/features/shell/presentation/widgets/home_dashboard_header.dart`
- Create: `frontend/lib/features/shell/presentation/widgets/home_dashboard_todo_card.dart`
- Create: `frontend/lib/features/shell/presentation/widgets/home_dashboard_risk_card.dart`
- Create: `frontend/lib/features/shell/presentation/widgets/home_dashboard_kpi_card.dart`
- Modify: `frontend/lib/features/shell/presentation/home_page.dart`
- Test: `frontend/test/widgets/home_page_test.dart`

- [ ] **Step 1: 写失败的 widget test，锁定工作台首屏结构**

```dart
testWidgets('桌面首页展示顶部状态条、主待办卡、风险卡和 KPI 卡', (tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HomePage(
          currentUser: buildUser(),
          shortcuts: const [],
          onNavigateToPage: (_, {tabCode, routePayloadJson}) {},
          onRefresh: () async {},
          refreshing: false,
          refreshStatusText: '上次刷新：12:00:00',
          dashboardData: buildDashboardData(),
          dashboardLoading: false,
          dashboardMessage: '',
          onOpenAllTodos: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('我的待办队列'), findsOneWidget);
  expect(find.text('异常与风险'), findsOneWidget);
  expect(find.text('次级业务指标'), findsOneWidget);
  expect(find.text('查看全部待办'), findsOneWidget);
});
```

- [ ] **Step 2: 运行 widget test，确认新 props 和组件尚未实现**

Run: `flutter test test/widgets/home_page_test.dart`

Expected: FAIL，出现 `No named parameter with the name 'dashboardData'` 或找不到新组件文案。

- [ ] **Step 3: 按现有前端风格重构首页**

```dart
// frontend/lib/features/shell/presentation/home_page.dart
return Padding(
  padding: const EdgeInsets.all(16),
  child: LayoutBuilder(
    builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 1440;
      if (!isDesktop) {
        return SingleChildScrollView(
          child: _buildMobileFallback(context),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeDashboardHeader(
            currentUser: currentUser,
            noticeCount: widget.dashboardData?.noticeCount ?? 0,
            onRefresh: widget.onRefresh,
            refreshing: widget.refreshing,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 12,
                  child: HomeDashboardTodoCard(
                    summary: widget.dashboardData?.todoSummary,
                    items: widget.dashboardData?.todoItems ?? const [],
                    onTapTodo: (item) => widget.onNavigateToPage(
                      item.targetPageCode ?? 'message',
                      tabCode: item.targetTabCode,
                      routePayloadJson: item.targetRoutePayloadJson,
                    ),
                    onOpenAll: widget.onOpenAllTodos,
                    loading: widget.dashboardLoading,
                    message: widget.dashboardMessage,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 12,
                        child: HomeDashboardRiskCard(
                          items: widget.dashboardData?.riskItems ?? const [],
                          onTapItem: _navigateMetricItem,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        flex: 9,
                        child: HomeDashboardKpiCard(
                          items: widget.dashboardData?.kpiItems ?? const [],
                          onTapItem: _navigateMetricItem,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  ),
);
```

```dart
// frontend/lib/features/shell/presentation/widgets/home_dashboard_todo_card.dart
class HomeDashboardTodoCard extends StatelessWidget {
  const HomeDashboardTodoCard({
    super.key,
    required this.summary,
    required this.items,
    required this.onTapTodo,
    required this.onOpenAll,
    required this.loading,
    required this.message,
  });

  final HomeDashboardTodoSummary? summary;
  final List<HomeDashboardTodoItem> items;
  final ValueChanged<HomeDashboardTodoItem> onTapTodo;
  final VoidCallback onOpenAll;
  final bool loading;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '我的待办队列',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              _buildLoadedContent(theme),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedContent(ThemeData theme) {
    return Expanded(
      child: Column(
        children: [
          _buildSummaryRow(theme),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('当前没有待处理事项'))
                : Column(
                    children: items.asMap().entries.map((entry) {
                      final item = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            key: ValueKey('home-dashboard-todo-item-${entry.key}'),
                            onTap: () => onTapTodo(item),
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(item.title)),
                                    Text(item.priorityLabel),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: onOpenAll,
              child: const Text('查看全部待办'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行首页 widget test**

Run: `flutter test test/widgets/home_page_test.dart`

Expected: PASS，桌面首页 test 全部通过，且不再依赖旧的快速跳转主视图断言。

- [ ] **Step 5: 提交首页组件化重构**

```bash
git add frontend/lib/features/shell/presentation/home_page.dart frontend/lib/features/shell/presentation/widgets/home_dashboard_header.dart frontend/lib/features/shell/presentation/widgets/home_dashboard_todo_card.dart frontend/lib/features/shell/presentation/widgets/home_dashboard_risk_card.dart frontend/lib/features/shell/presentation/widgets/home_dashboard_kpi_card.dart frontend/test/widgets/home_page_test.dart
git commit -m "功能：首页工作台组件化重构"
```

### Task 5: 主壳接线与首页刷新策略

**Files:**
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
- Modify: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 写失败的主壳测试，锁定首页加载和事件刷新**

```dart
testWidgets('主壳进入首页后会加载首页工作台数据并在消息事件后防抖刷新', (tester) async {
  var loadCount = 0;

  await tester.pumpWidget(
    MaterialApp(
      home: MainShellPage(
        session: buildSession(),
        onLogout: () {},
        homeDashboardService: FakeHomeDashboardService(onLoad: () {
          loadCount += 1;
          return buildDashboardData();
        }),
        messageWsServiceFactory: buildFakeWsFactory(),
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(loadCount, 1);

  fakeWsEmitUnreadChanged();
  await tester.pump(const Duration(seconds: 2));
  expect(loadCount, 2);
});
```

- [ ] **Step 2: 运行主壳测试，确认首页服务和刷新链路尚未注入**

Run: `flutter test test/widgets/main_shell_page_test.dart`

Expected: FAIL，出现 `No named parameter with the name 'homeDashboardService'` 或 loadCount 断言失败。

- [ ] **Step 3: 在主壳中接入首页数据、首页可见刷新和查看全部待办跳转**

```dart
// frontend/lib/features/shell/presentation/main_shell_page.dart
final HomeDashboardService? homeDashboardService;

late final HomeDashboardService _homeDashboardService;
HomeDashboardData? _homeDashboardData;
bool _homeDashboardLoading = false;
String _homeDashboardMessage = '';
Timer? _homeDashboardRefreshDebounce;

@override
void initState() {
  super.initState();
  _homeDashboardService =
      widget.homeDashboardService ?? HomeDashboardService(widget.session);
  _loadCurrentUserAndVisibility();
}

Future<void> _refreshHomeDashboard({bool silent = false}) async {
  if (_homeDashboardLoading) return;
  if (!mounted || _selectedPageCode != _homePageCode) return;
  setState(() {
    _homeDashboardLoading = true;
    if (!silent) _homeDashboardMessage = '';
  });
  try {
    final data = await _homeDashboardService.load();
    if (!mounted) return;
    setState(() => _homeDashboardData = data);
  } catch (error) {
    if (!mounted) return;
    setState(() => _homeDashboardMessage = '加载首页工作台失败：${_errorMessage(error)}');
  } finally {
    if (mounted) setState(() => _homeDashboardLoading = false);
  }
}

void _scheduleHomeDashboardRefresh() {
  if (_selectedPageCode != _homePageCode) return;
  _homeDashboardRefreshDebounce?.cancel();
  _homeDashboardRefreshDebounce = Timer(const Duration(seconds: 2), () {
    _refreshHomeDashboard(silent: true);
  });
}
```

```dart
return HomePage(
  currentUser: _currentUser!,
  shortcuts: _buildHomeQuickJumps(),
  onNavigateToPage: (
    String pageCode, {
    String? tabCode,
    String? routePayloadJson,
  }) {
    _navigateToPageTarget(
      pageCode,
      tabCode: tabCode,
      routePayloadJson: routePayloadJson,
    );
  },
  onRefresh: () async {
    await _refreshShellDataFromUi(loadCatalog: false);
    await _refreshHomeDashboard();
  },
  refreshing: _manualRefreshing || _homeDashboardLoading,
  refreshStatusText: _homeRefreshStatusText(),
  dashboardData: _homeDashboardData,
  dashboardLoading: _homeDashboardLoading,
  dashboardMessage: _homeDashboardMessage,
  onOpenAllTodos: () {
    _navigateToPageTarget(
      _messagePageCode,
      routePayloadJson: '{"preset":"todo_only"}',
    );
  },
);
```

- [ ] **Step 4: 运行主壳测试**

Run: `flutter test test/widgets/main_shell_page_test.dart`

Expected: PASS，首页首次加载、手动刷新和消息事件触发刷新通过。

- [ ] **Step 5: 提交主壳首页接线**

```bash
git add frontend/lib/features/shell/presentation/main_shell_page.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "功能：首页工作台主壳刷新接线"
```

### Task 6: 目标页面过滤态跳转支持

**Files:**
- Modify: `frontend/lib/features/message/presentation/message_center_page.dart`
- Modify: `frontend/lib/features/production/presentation/production_order_query_page.dart`
- Modify: `frontend/lib/features/quality/presentation/quality_data_page.dart`
- Modify: `frontend/lib/features/equipment/presentation/maintenance_execution_page.dart`
- Test: `frontend/test/widgets/message_center_page_test.dart`
- Test: `frontend/test/widgets/production_order_query_page_test.dart`
- Test: `frontend/test/widgets/equipment_module_pages_test.dart`
- Test: `frontend/test/pages/quality_pages_test.dart`

- [ ] **Step 1: 写失败的跳转预设测试**

```dart
testWidgets('消息中心可消费首页待办 preset', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MessageCenterPage(
        session: buildSession(),
        onLogout: () {},
        routePayloadJson: '{"preset":"todo_only"}',
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('消息中心'), findsOneWidget);
});

testWidgets('生产订单查询可消费首页异常 preset', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProductionOrderQueryPage(
        session: buildSession(),
        onLogout: () {},
        canFirstArticle: false,
        canEndProduction: false,
        canCreateManualRepairOrder: false,
        canCreateAssistAuthorization: false,
        canProxyView: false,
        canExportCsv: false,
        routePayloadJson: '{"dashboard_filter":"exception"}',
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('生产订单查询'), findsOneWidget);
});
```

- [ ] **Step 2: 运行页面测试，确认 payload preset 尚未支持**

Run: `flutter test test/widgets/message_center_page_test.dart test/widgets/production_order_query_page_test.dart test/pages/quality_pages_test.dart test/widgets/equipment_module_pages_test.dart`

Expected: FAIL，出现构造参数缺失或初始过滤态断言失败。

- [ ] **Step 3: 给目标页补首页 preset 解析**

```dart
// frontend/lib/features/message/presentation/message_center_page.dart
final String? routePayloadJson;

void _consumeRoutePayload(String? rawJson) {
  if ((rawJson ?? '').trim().isEmpty) return;
  final payload = jsonDecode(rawJson!) as Map<String, dynamic>;
  if (payload['preset'] == 'todo_only') {
    setState(() {
      _todoOnly = true;
      _statusFilter = '';
      _page = 1;
    });
    _load();
  }
}
```

```dart
// frontend/lib/features/production/presentation/production_order_query_page.dart
final String? routePayloadJson;

void _consumeRoutePayload(String? rawJson) {
  if ((rawJson ?? '').trim().isEmpty) return;
  final payload = jsonDecode(rawJson!) as Map<String, dynamic>;
  if (payload['dashboard_filter'] == 'exception') {
    setState(() {
      _orderStatusFilter = 'in_progress';
      _page = 1;
    });
    _loadOrders(page: 1);
  }
}
```

```dart
// frontend/lib/features/quality/presentation/quality_data_page.dart
final String? routePayloadJson;

void _consumeRoutePayload(String? rawJson) {
  if ((rawJson ?? '').trim().isEmpty) return;
  final payload = jsonDecode(rawJson!) as Map<String, dynamic>;
  if (payload['dashboard_filter'] == 'warning') {
    setState(() {
      _resultFilter = 'failed';
      _trendPage = 1;
    });
    _loadStats();
  }
}
```

```dart
// frontend/lib/features/equipment/presentation/maintenance_execution_page.dart
void _consumeJumpPayload(String? rawPayload) {
  if (!mounted ||
      rawPayload == null ||
      rawPayload.trim().isEmpty ||
      rawPayload == _lastHandledJumpPayloadJson) {
    return;
  }
  final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
  if (payload['dashboard_filter'] == 'overdue') {
    setState(() {
      _statusFilter = 'overdue';
      _page = 1;
    });
    _lastHandledJumpPayloadJson = rawPayload;
    _loadItems(page: 1);
    return;
  }
}
```

- [ ] **Step 4: 运行目标页测试**

Run: `flutter test test/widgets/message_center_page_test.dart test/widgets/production_order_query_page_test.dart test/pages/quality_pages_test.dart test/widgets/equipment_module_pages_test.dart`

Expected: PASS，首页触发的待办/异常/质量/设备预设过滤态可被目标页消费。

- [ ] **Step 5: 提交首页跳转过滤态**

```bash
git add frontend/lib/features/message/presentation/message_center_page.dart frontend/lib/features/production/presentation/production_order_query_page.dart frontend/lib/features/quality/presentation/quality_data_page.dart frontend/lib/features/equipment/presentation/maintenance_execution_page.dart frontend/test/widgets/message_center_page_test.dart frontend/test/widgets/production_order_query_page_test.dart frontend/test/pages/quality_pages_test.dart frontend/test/widgets/equipment_module_pages_test.dart
git commit -m "功能：首页工作台目标页过滤态跳转"
```

### Task 7: 集成测试、性能门禁与 evidence 收口

**Files:**
- Create: `frontend/integration_test/home_dashboard_flow_test.dart`
- Modify: `tools/perf/scenarios/other_authenticated_read_scenarios.json`
- Modify: `tools/perf/scenarios/combined_40_scan.json`
- Modify: `evidence/task_log_20260412_home_dashboard_plan.md`

- [ ] **Step 1: 写失败的首页集成测试与性能场景**

```dart
testWidgets('登录后首页工作台展示 4 条待办并可跳转到消息待办视图', (tester) async {
  await pumpHomeDashboardShell(tester);

  expect(find.text('我的待办队列'), findsOneWidget);
  expect(find.byKey(const ValueKey('home-dashboard-todo-item-0')), findsOneWidget);

  await tester.tap(find.text('查看全部待办'));
  await tester.pumpAndSettle();

  expect(find.text('消息中心'), findsOneWidget);
});
```

```json
{
  "name": "ui-home-dashboard",
  "method": "GET",
  "path": "/api/v1/ui/home-dashboard",
  "requires_auth": true,
  "role_domain": "auth",
  "token_pool": "pool-admin",
  "success_statuses": [200]
}
```

- [ ] **Step 2: 运行集成测试并验证场景文件可被性能工具读取**

Run: `flutter test integration_test/home_dashboard_flow_test.dart`

Expected: FAIL，出现首页工作台文案或跳转链路断言失败。

Run: `python -m tools.project_toolkit backend-capacity-gate --scenario-config-file tools/perf/scenarios/other_authenticated_read_scenarios.json --scenarios ui-home-dashboard --concurrency 1 --duration-seconds 1 --warmup-seconds 0 --output-json .tmp_runtime/ui_home_dashboard_smoke.json`

Expected: 若后端尚未实现则失败；实现后应能成功输出场景结果 JSON。

- [ ] **Step 3: 补齐集成测试、性能场景与 evidence 收口**

```markdown
# evidence/task_log_20260412_home_dashboard_plan.md 追加收口
- 计划执行结果：已完成
- 首页聚合接口验证：`pytest backend/tests/test_home_dashboard_service_unit.py backend/tests/test_ui_home_dashboard_integration.py -q`
- 首页 Flutter 验证：`flutter test test/services/home_dashboard_service_test.dart test/widgets/home_page_test.dart test/widgets/main_shell_page_test.dart test/widgets/message_center_page_test.dart test/widgets/production_order_query_page_test.dart test/pages/quality_pages_test.dart test/widgets/equipment_module_pages_test.dart`
- 首页 40 并发 P95：`python -m tools.project_toolkit backend-capacity-gate --scenario-config-file tools/perf/scenarios/other_authenticated_read_scenarios.json --scenarios ui-home-dashboard --concurrency 40 --token-count 40 --session-pool-size 20 --warmup-seconds 15 --duration-seconds 90 --p95-ms 500 --error-rate-threshold 0.05 --output-json .tmp_runtime/ui_home_dashboard_40.json`
```

```json
// tools/perf/scenarios/combined_40_scan.json 中追加
{
  "name": "ui-home-dashboard",
  "method": "GET",
  "path": "/api/v1/ui/home-dashboard",
  "requires_auth": true,
  "role_domain": "auth",
  "token_pool": "pool-admin",
  "success_statuses": [200]
}
```

- [ ] **Step 4: 运行完整验证**

Run: `pytest backend/tests/test_home_dashboard_service_unit.py backend/tests/test_ui_home_dashboard_integration.py -q`

Expected: PASS。

Run: `flutter test test/services/home_dashboard_service_test.dart test/widgets/home_page_test.dart test/widgets/main_shell_page_test.dart test/widgets/message_center_page_test.dart test/widgets/production_order_query_page_test.dart test/pages/quality_pages_test.dart test/widgets/equipment_module_pages_test.dart`

Expected: PASS。

Run: `flutter test integration_test/home_dashboard_flow_test.dart`

Expected: PASS。

Run: `python -m tools.project_toolkit backend-capacity-gate --scenario-config-file tools/perf/scenarios/other_authenticated_read_scenarios.json --scenarios ui-home-dashboard --concurrency 40 --token-count 40 --session-pool-size 20 --warmup-seconds 15 --duration-seconds 90 --p95-ms 500 --error-rate-threshold 0.05 --output-json .tmp_runtime/ui_home_dashboard_40.json`

Expected: EXIT 0，结果 JSON 中包含 `"gate_passed": true`，且 `overall.p95_ms <= 500`。

- [ ] **Step 5: 提交验证与 evidence**

```bash
git add frontend/integration_test/home_dashboard_flow_test.dart tools/perf/scenarios/other_authenticated_read_scenarios.json tools/perf/scenarios/combined_40_scan.json evidence/task_log_20260412_home_dashboard_plan.md
git commit -m "测试：首页工作台链路与性能门禁"
```

## 自检

### Spec 覆盖

1. 统一框架与现有风格：首页组件化与桌面布局在 Task 4。
2. 聚合接口与数据结构：Task 1、Task 2。
3. 主壳刷新策略：Task 5。
4. 目标页面过滤态跳转：Task 6。
5. 前端、后端、集成、40 并发 P95：Task 7。

无 spec 漏项。

### 占位词检查

已检查计划正文，未保留 `TODO`、`TBD`、`待补`、`类似 Task N` 这类占位描述。

### 类型一致性

1. 后端统一使用 `HomeDashboardResult` / `HomeDashboardTodoItem` / `HomeDashboardMetricItem`。
2. 前端统一使用 `HomeDashboardData` / `HomeDashboardTodoItem` / `HomeDashboardMetricItem`。
3. 首页跳转统一通过 `target_page_code`、`target_tab_code`、`target_route_payload_json`。

类型与字段命名保持一致。

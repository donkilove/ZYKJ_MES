# 消息中心公告管理子页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在消息模块下新增“公告管理”子页，补齐当前生效公告列表、发布公告、下线公告、权限显隐与回归验证，替换消息中心主页面中的旧公告发布入口。

**Architecture:** 后端先为公告补齐显式管理语义，新增“当前生效公告列表”和“下线公告”接口，并在权限目录中拆出查看/发布/下线三类能力；前端再新增 `MessagePage` 作为消息模块的 tab 容器，承载 `MessageCenterPage` 与新的 `AnnouncementManagementPage`，服务层补充对应 API，最后移除消息中心页头中的旧发布入口并完成回归测试。

**Tech Stack:** Python、FastAPI、SQLAlchemy、Flutter、Dart、`pytest`、`flutter_test`

---

## 文件结构

### 需要修改的后端文件

- `backend/app/models/message.py`
  - 扩展公告状态语义，允许 `offline` 作为人工下线态。
- `backend/app/schemas/message.py`
  - 为公告管理补充列表筛选与下线结果结构，或复用现有 `MessageListResult` 增加最小返回结构。
- `backend/app/services/message_service.py`
  - 新增当前生效公告查询、公告下线、公告状态判断与审计写入。
- `backend/app/api/v1/endpoints/messages.py`
  - 暴露公告管理列表与公告下线接口。
- `backend/app/core/page_catalog.py`
  - 为消息模块新增 `announcement_management` 子页。
- `backend/app/core/authz_catalog.py`
  - 新增 `announcement_management` 页面权限与公告查看/下线 action 权限。
- `backend/app/core/authz_hierarchy_catalog.py`
  - 新增公告管理 feature 定义。
- `backend/app/services/authz_service.py`
  - 补齐公告管理 feature 的显示名称与能力描述。

### 需要修改的后端测试文件

- `backend/tests/test_message_service_unit.py`
- `backend/tests/test_message_module_integration.py`

### 需要修改的前端文件

- `frontend/lib/features/message/models/message_models.dart`
  - 扩展公告状态显示与公告管理页所需字段。
- `frontend/lib/features/message/services/message_service.dart`
  - 增加获取当前生效公告、下线公告 API。
- `frontend/lib/features/message/presentation/message_center_page.dart`
  - 去掉旧的发布公告入口参数与行为。
- `frontend/lib/features/message/presentation/widgets/message_center_header.dart`
  - 去掉发布公告按钮相关输入。
- `frontend/lib/features/message/presentation/widgets/message_center_action_bar.dart`
  - 移除“发布公告”按钮。
- `frontend/lib/features/message/presentation/widgets/message_center_action_dialogs.dart`
  - 保留发布对话框复用能力，供公告管理页调用。
- `frontend/lib/features/message/presentation/announcement_management_page.dart`
  - 新建公告管理页。
- `frontend/lib/features/message/presentation/message_page.dart`
  - 新建消息模块 tab 容器页。
- `frontend/lib/features/message/presentation/widgets/message_page_shell.dart`
  - 新建消息模块 tab 壳组件。
- `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
  - 将消息模块改为返回 `MessagePage`，透传 `visibleTabCodes` 与 capability。

### 需要修改的前端测试文件

- `frontend/test/services/message_service_test.dart`
- `frontend/test/widgets/message_center_page_test.dart`
- `frontend/test/widgets/main_shell_page_registry_test.dart`
- `frontend/test/widgets/main_shell_page_test.dart`
- `frontend/test/widgets/announcement_management_page_test.dart`
  - 新建公告管理页 widget 测试。

### 计划内不修改的文件

- 登录页公开公告页面代码
- WebSocket 协议与消息详情/跳转协议
- 与公告管理无关的其他业务模块页面

## Task 1: 先补后端公告管理语义与服务层

**Files:**
- Modify: `backend/app/models/message.py`
- Modify: `backend/app/schemas/message.py`
- Modify: `backend/app/services/message_service.py`
- Test: `backend/tests/test_message_service_unit.py`

- [ ] **Step 1: 先写服务层失败测试，定义“当前生效公告”只返回 active 且未过期的公告**

```python
def test_list_active_announcements_returns_only_active_unexpired_rows(self):
    now = datetime.now(UTC)
    db = MagicMock()
    db.execute.side_effect = [
        _FakeScalarResult(one=1),
        _FakeScalarResult(
            all_rows=[
                SimpleNamespace(
                    id=71,
                    message_type="announcement",
                    priority="important",
                    title="生效公告",
                    summary="摘要",
                    content="正文",
                    source_module="message",
                    source_type="announcement",
                    source_code="all",
                    created_by_user_id=1,
                    target_page_code=None,
                    target_tab_code=None,
                    target_route_payload_json=None,
                    status="active",
                    published_at=now,
                    expires_at=now + timedelta(days=1),
                )
            ]
        ),
    ]

    items, total = message_service.list_active_announcements(
        db,
        page=1,
        page_size=20,
        public_only=False,
    )

    self.assertEqual(total, 1)
    self.assertEqual(len(items), 1)
    self.assertEqual(items[0].title, "生效公告")
    self.assertEqual(items[0].status, "active")
```

- [ ] **Step 2: 运行单测确认它先失败**

Run: `python -m pytest backend/tests/test_message_service_unit.py -k "active_announcements" -q`

Expected: FAIL，提示 `list_active_announcements` 未定义。

- [ ] **Step 3: 在服务层补最小实现与公告状态映射**

```python
def list_active_announcements(
    db: Session,
    *,
    page: int,
    page_size: int,
    public_only: bool = False,
    priority: str | None = None,
) -> tuple[list[MessageItem], int]:
    now = datetime.now(UTC)
    filters = [
        Message.message_type == "announcement",
        Message.source_type == "announcement",
        Message.status == "active",
        or_(Message.expires_at.is_(None), Message.expires_at > now),
    ]
    if public_only:
        filters.append(Message.source_code == "all")
    if priority:
        filters.append(Message.priority == priority.strip().lower())

    total = (
        db.execute(select(func.count()).select_from(Message).where(*filters))
        .scalar_one()
    )
    rows = (
        db.execute(
            select(Message)
            .where(*filters)
            .order_by(Message.published_at.desc(), Message.id.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        .scalars()
        .all()
    )
    items = [_to_public_announcement_item(row) for row in rows]
    return items, int(total or 0)

def _resolve_message_status(
    msg: Message,
    *,
    now: datetime,
    user_permission_codes: set[str] | None,
) -> tuple[str, str | None]:
    if msg.status == "offline":
        return "offline", "offline"
    if msg.status == "archived":
        return "archived", "archived"
    ...
```

- [ ] **Step 4: 再写公告下线的失败测试，明确只能把公告改为 offline**

```python
def test_offline_announcement_updates_status_and_writes_audit(self):
    announcement = SimpleNamespace(
        id=88,
        title="全员公告",
        message_type="announcement",
        status="active",
        source_type="announcement",
    )
    db = MagicMock()
    db.execute.return_value = _FakeScalarResult(one=announcement)
    operator = SimpleNamespace(id=1, username="admin")

    with patch.object(message_service, "write_audit_log") as write_audit_log:
        changed = message_service.offline_announcement(
            db,
            announcement_id=88,
            operator=operator,
            reason="manual_offline",
        )

    self.assertTrue(changed)
    self.assertEqual(announcement.status, "offline")
    db.flush.assert_called_once()
    write_audit_log.assert_called_once()
```

- [ ] **Step 5: 运行单测确认它先失败**

Run: `python -m pytest backend/tests/test_message_service_unit.py -k "offline_announcement" -q`

Expected: FAIL，提示 `offline_announcement` 未定义。

- [ ] **Step 6: 用最小实现补下线逻辑与状态文案**

```python
def offline_announcement(
    db: Session,
    *,
    announcement_id: int,
    operator: User,
    reason: str | None = None,
) -> bool:
    announcement = (
        db.execute(
            select(Message).where(
                Message.id == announcement_id,
                Message.message_type == "announcement",
                Message.source_type == "announcement",
            )
        )
        .scalar_one_or_none()
    )
    if announcement is None:
        return False
    if announcement.status != "active":
        raise ValueError("仅生效中的公告允许下线")
    announcement.status = "offline"
    _write_message_state_audit_log(
        db,
        message=announcement,
        action_code="message.announcements.offline",
        action_name="下线站内公告",
        previous_status="active",
        current_status="offline",
        reason=reason or "manual_offline",
    )
    db.flush()
    return True
```

- [ ] **Step 7: 扩展模型/Schema 中的最小字段语义并验证通过**

```python
class MessageItem(BaseModel):
    ...
    status: str
    inactive_reason: str | None = None
    ...

class AnnouncementOfflineResult(BaseModel):
    message_id: int
    status: str
```

Run: `python -m pytest backend/tests/test_message_service_unit.py -k "active_announcements or offline_announcement" -q`

Expected: PASS，新增公告服务层测试通过。

- [ ] **Step 8: 提交服务层语义补齐**

```bash
git add backend/app/models/message.py backend/app/schemas/message.py backend/app/services/message_service.py backend/tests/test_message_service_unit.py
git commit -m "补齐公告管理服务层语义"
```

## Task 2: 暴露后端接口并补齐页面目录与权限

**Files:**
- Modify: `backend/app/api/v1/endpoints/messages.py`
- Modify: `backend/app/core/page_catalog.py`
- Modify: `backend/app/core/authz_catalog.py`
- Modify: `backend/app/core/authz_hierarchy_catalog.py`
- Modify: `backend/app/services/authz_service.py`
- Test: `backend/tests/test_message_module_integration.py`

- [ ] **Step 1: 先写集成失败测试，定义“当前生效公告接口 + 下线接口”行为**

```python
def test_active_announcements_endpoint_and_offline_endpoint(self) -> None:
    publish_response = self.client.post(
        "/api/v1/messages/announcements",
        headers=self._headers(),
        json={
            "title": "可下线公告",
            "content": f"{self.case_token} 公告内容",
            "priority": "important",
            "range_type": "all",
            "role_codes": [],
            "user_ids": [],
            "expires_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    self.assertEqual(publish_response.status_code, 200, publish_response.text)
    message_id = publish_response.json()["data"]["message_id"]
    self.message_ids.append(message_id)

    active_list = self.client.get(
        "/api/v1/messages/announcements/active",
        headers=self._headers(),
    )
    self.assertEqual(active_list.status_code, 200, active_list.text)
    active_ids = [item["id"] for item in active_list.json()["data"]["items"]]
    self.assertIn(message_id, active_ids)

    offline_response = self.client.post(
        f"/api/v1/messages/announcements/{message_id}/offline",
        headers=self._headers(),
    )
    self.assertEqual(offline_response.status_code, 200, offline_response.text)
    self.assertEqual(offline_response.json()["data"]["status"], "offline")

    active_after_offline = self.client.get(
        "/api/v1/messages/announcements/active",
        headers=self._headers(),
    )
    self.assertEqual(active_after_offline.status_code, 200, active_after_offline.text)
    active_after_ids = [item["id"] for item in active_after_offline.json()["data"]["items"]]
    self.assertNotIn(message_id, active_after_ids)
```

- [ ] **Step 2: 运行集成测试确认它先失败**

Run: `python -m pytest backend/tests/test_message_module_integration.py -k "active_announcements_endpoint_and_offline_endpoint" -q`

Expected: FAIL，提示新增端点不存在或返回 404。

- [ ] **Step 3: 在端点层补接口，并提交最小成功返回**

```python
@router.get("/announcements/active", response_model=ApiResponse[MessageListResult])
def api_list_active_announcements(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    public_only: bool = Query(False),
    priority: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("message.announcements.view")),
) -> ApiResponse[MessageListResult]:
    items, total = list_active_announcements(
        db,
        page=page,
        page_size=page_size,
        public_only=public_only,
        priority=priority,
    )
    return success_response(
        MessageListResult(items=items, total=total, page=page, page_size=page_size)
    )

@router.post(
    "/announcements/{message_id}/offline",
    response_model=ApiResponse[AnnouncementOfflineResult],
)
def api_offline_announcement(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("message.announcements.offline")),
) -> ApiResponse[AnnouncementOfflineResult]:
    ok = offline_announcement(
        db,
        announcement_id=message_id,
        operator=current_user,
    )
    if not ok:
        raise HTTPException(status_code=404, detail="公告不存在")
    db.commit()
    return success_response(AnnouncementOfflineResult(message_id=message_id, status="offline"))
```

- [ ] **Step 4: 再写权限与页面目录失败测试，要求消息模块暴露 `announcement_management`**

```python
def test_announcement_management_page_and_permissions_registered(self):
    from app.core.page_catalog import PAGE_BY_CODE
    from app.core.authz_catalog import PAGE_PERMISSION_BY_PAGE_CODE, PERMISSION_BY_CODE
    from app.core.authz_hierarchy_catalog import FEATURE_BY_PERMISSION_CODE

    self.assertIn("announcement_management", PAGE_BY_CODE)
    self.assertEqual(PAGE_BY_CODE["announcement_management"]["parent_code"], "message")
    self.assertIn("page.announcement_management.view", PAGE_PERMISSION_BY_PAGE_CODE.values())
    self.assertIn("message.announcements.view", PERMISSION_BY_CODE)
    self.assertIn("message.announcements.offline", PERMISSION_BY_CODE)
    self.assertIn("feature.message.announcement.view", FEATURE_BY_PERMISSION_CODE)
    self.assertIn("feature.message.announcement.offline", FEATURE_BY_PERMISSION_CODE)
```

- [ ] **Step 5: 运行测试确认目录与权限定义先失败**

Run: `python -m pytest backend/tests/test_message_module_integration.py -k "announcement_management_page_and_permissions_registered" -q`

Expected: FAIL，提示 `announcement_management` 或新权限不存在。

- [ ] **Step 6: 用最小改动补 page catalog、authz catalog、feature catalog**

```python
# page_catalog.py
PAGE_ANNOUNCEMENT_MANAGEMENT = "announcement_management"
...
{
    "code": PAGE_ANNOUNCEMENT_MANAGEMENT,
    "name": "公告管理",
    "page_type": PAGE_TYPE_TAB,
    "parent_code": PAGE_MESSAGE,
    "always_visible": False,
    "sort_order": 82,
},

# authz_catalog.py
("announcement_management", "公告管理", AUTHZ_MODULE_MESSAGE, "message"),
...
("message.announcements.view", "查看公告管理", AUTHZ_MODULE_MESSAGE, "announcement_management"),
("message.announcements.offline", "下线站内公告", AUTHZ_MODULE_MESSAGE, "announcement_management"),

# authz_hierarchy_catalog.py
FeatureDefinition(
    permission_code="feature.message.announcement.view",
    permission_name="查看公告管理",
    module_code="message",
    page_code="announcement_management",
    action_permission_codes=("message.announcements.view",),
),
FeatureDefinition(
    permission_code="feature.message.announcement.offline",
    permission_name="下线站内公告",
    module_code="message",
    page_code="announcement_management",
    action_permission_codes=("message.announcements.offline",),
    dependency_permission_codes=("feature.message.announcement.view",),
),
```

- [ ] **Step 7: 运行后端公告管理相关测试确认通过**

Run: `python -m pytest backend/tests/test_message_service_unit.py backend/tests/test_message_module_integration.py -k "announcement or active_announcements or offline" -q`

Expected: PASS，新增公告接口、权限、目录与原公开公告能力同时通过。

- [ ] **Step 8: 提交接口与权限目录补齐**

```bash
git add backend/app/api/v1/endpoints/messages.py backend/app/core/page_catalog.py backend/app/core/authz_catalog.py backend/app/core/authz_hierarchy_catalog.py backend/app/services/authz_service.py backend/tests/test_message_module_integration.py
git commit -m "新增公告管理接口与权限目录"
```

## Task 3: 补前端消息服务与公告管理页

**Files:**
- Modify: `frontend/lib/features/message/models/message_models.dart`
- Modify: `frontend/lib/features/message/services/message_service.dart`
- Create: `frontend/lib/features/message/presentation/announcement_management_page.dart`
- Create: `frontend/test/widgets/announcement_management_page_test.dart`
- Modify: `frontend/test/services/message_service_test.dart`

- [ ] **Step 1: 先写 service 失败测试，定义当前生效公告查询和下线请求**

```dart
test('supports active announcement listing and offline action', () async {
  final server = await TestHttpServer.start({
    'GET /messages/announcements/active': (request) {
      expect(request.uri.queryParameters['public_only'], 'true');
      return TestResponse.json(
        200,
        body: {
          'data': {
            'items': [
              {
                'id': 31,
                'message_type': 'announcement',
                'priority': 'urgent',
                'title': '停机公告',
                'summary': '今晚停机',
                'content': '今晚 20:00 维护',
                'source_module': 'message',
                'source_type': 'announcement',
                'source_code': 'all',
                'status': 'active',
                'published_at': '2026-05-05T10:00:00Z',
                'expires_at': '2026-05-06T10:00:00Z',
                'is_read': false,
                'delivery_status': 'pending',
                'delivery_attempt_count': 0,
              }
            ],
            'total': 1,
            'page': 1,
            'page_size': 20,
          }
        },
      );
    },
    'POST /messages/announcements/31/offline': (_) => TestResponse.json(
      200,
      body: {
        'data': {'message_id': 31, 'status': 'offline'},
      },
    ),
  });
  addTearDown(server.close);

  final service = MessageService(
    AppSession(baseUrl: server.baseUrl, accessToken: 'token'),
  );

  final result = await service.getActiveAnnouncements(publicOnly: true);
  final offline = await service.offlineAnnouncement(31);

  expect(result.items.single.title, '停机公告');
  expect(offline.status, 'offline');
});
```

- [ ] **Step 2: 运行 service 测试确认它先失败**

Run: `flutter test test/services/message_service_test.dart -r expanded`

Expected: FAIL，提示 `getActiveAnnouncements` 或 `offlineAnnouncement` 未定义。

- [ ] **Step 3: 在模型与 MessageService 中补最小实现**

```dart
class AnnouncementOfflineResult {
  const AnnouncementOfflineResult({
    required this.messageId,
    required this.status,
  });

  final int messageId;
  final String status;

  factory AnnouncementOfflineResult.fromJson(Map<String, dynamic> json) {
    return AnnouncementOfflineResult(
      messageId: (json['message_id'] as int?) ?? 0,
      status: json['status'] as String? ?? '',
    );
  }
}

Future<MessageListResult> getActiveAnnouncements({
  int page = 1,
  int pageSize = 20,
  bool publicOnly = false,
  String? priority,
}) async {
  final params = <String, String>{
    'page': '$page',
    'page_size': '$pageSize',
    if (publicOnly) 'public_only': 'true',
    if (priority != null && priority.isNotEmpty) 'priority': priority,
  };
  final uri = Uri.parse('$_base/announcements/active').replace(queryParameters: params);
  final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
  _checkStatus(resp);
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  return MessageListResult.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
}

Future<AnnouncementOfflineResult> offlineAnnouncement(int messageId) async {
  final uri = Uri.parse('$_base/announcements/$messageId/offline');
  final resp = await http.post(uri, headers: _headers).timeout(const Duration(seconds: 30));
  _checkStatus(resp);
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  return AnnouncementOfflineResult.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
}
```

- [ ] **Step 4: 先写公告管理页的失败 widget 测试**

```dart
testWidgets('公告管理页展示当前公告并支持下线', (tester) async {
  final service = _FakeAnnouncementManagementService()
    ..items = [
      MessageItem.fromJson({
        'id': 31,
        'message_type': 'announcement',
        'priority': 'urgent',
        'title': '停机公告',
        'summary': '今晚停机',
        'content': '今晚 20:00 维护',
        'source_module': 'message',
        'source_type': 'announcement',
        'source_code': 'all',
        'status': 'active',
        'published_at': '2026-05-05T10:00:00Z',
        'expires_at': '2026-05-06T10:00:00Z',
        'is_read': false,
        'delivery_status': 'pending',
        'delivery_attempt_count': 0,
      }),
    ];

  await tester.pumpWidget(
    MaterialApp(
      home: AnnouncementManagementPage(
        session: AppSession(baseUrl: '', accessToken: ''),
        onLogout: () {},
        service: service,
        canPublishAnnouncement: true,
        canOfflineAnnouncement: true,
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('公告管理'), findsOneWidget);
  expect(find.text('停机公告'), findsOneWidget);
  await tester.tap(find.text('下线'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('确认下线'));
  await tester.pumpAndSettle();

  expect(service.offlineIds, [31]);
})
```

- [ ] **Step 5: 运行 widget 测试确认它先失败**

Run: `flutter test test/widgets/announcement_management_page_test.dart -r expanded`

Expected: FAIL，提示 `AnnouncementManagementPage` 未定义。

- [ ] **Step 6: 新建公告管理页的最小实现**

```dart
class AnnouncementManagementPage extends StatefulWidget {
  const AnnouncementManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canPublishAnnouncement,
    required this.canOfflineAnnouncement,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canPublishAnnouncement;
  final bool canOfflineAnnouncement;
  final MessageService? service;

  @override
  State<AnnouncementManagementPage> createState() => _AnnouncementManagementPageState();
}

class _AnnouncementManagementPageState extends State<AnnouncementManagementPage> {
  late final MessageService _service;
  bool _loading = false;
  String _error = '';
  MessageListResult _result = const MessageListResult(items: [], total: 0, page: 1, pageSize: 20);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MessageService(widget.session);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final result = await _service.getActiveAnnouncements();
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
  ...
}
```

- [ ] **Step 7: 运行服务测试与公告管理页测试确认通过**

Run: `flutter test test/services/message_service_test.dart test/widgets/announcement_management_page_test.dart -r expanded`

Expected: PASS，新增 API 与页面主路径通过。

- [ ] **Step 8: 提交前端服务层与公告管理页**

```bash
git add frontend/lib/features/message/models/message_models.dart frontend/lib/features/message/services/message_service.dart frontend/lib/features/message/presentation/announcement_management_page.dart frontend/test/services/message_service_test.dart frontend/test/widgets/announcement_management_page_test.dart
git commit -m "新增公告管理页与消息服务接口"
```

## Task 4: 将消息模块改为 tab 容器并接入公告管理子页

**Files:**
- Create: `frontend/lib/features/message/presentation/message_page.dart`
- Create: `frontend/lib/features/message/presentation/widgets/message_page_shell.dart`
- Modify: `frontend/lib/features/message/presentation/message_center_page.dart`
- Modify: `frontend/lib/features/message/presentation/widgets/message_center_header.dart`
- Modify: `frontend/lib/features/message/presentation/widgets/message_center_action_bar.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
- Test: `frontend/test/widgets/message_center_page_test.dart`
- Test: `frontend/test/widgets/main_shell_page_registry_test.dart`
- Test: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 先写 registry 失败测试，要求消息模块返回新的 `MessagePage` 容器**

```dart
test('消息模块会返回 MessagePage 并透传可见页签与能力', () {
  const registry = MainShellPageRegistry();
  final state = MainShellViewState(
    currentUser: buildCurrentUser(),
    authzSnapshot: buildSnapshot(
      visibleSidebarCodes: const ['message'],
      tabCodesByParent: const {
        'message': ['message_center', 'announcement_management'],
      },
      moduleItems: [
        buildModuleItem(
          'message',
          capabilityCodes: const [
            'feature.message.center.view',
            'feature.message.announcement.view',
            'feature.message.announcement.publish',
            'feature.message.announcement.offline',
          ],
        ),
      ],
    ),
    catalog: buildCatalogWithAnnouncementManagement(),
    tabCodesByParent: const {
      'message': ['message_center', 'announcement_management'],
    },
    selectedPageCode: 'message',
  );

  final widget = registry.build(
    pageCode: 'message',
    session: testSession,
    state: state,
    onLogout: () {},
    onRefreshShellData: ({bool loadCatalog = true}) async {},
    onNavigateToPageTarget:
        ({required pageCode, String? tabCode, String? routePayloadJson}) {},
    onVisibilityConfigSaved: () {},
    onUnreadCountChanged: (_) {},
    messageService: MessageService(testSession),
    softwareSettingsController: softwareSettingsController,
    timeSyncController: timeSyncController,
  );

  expect(widget, isA<MessagePage>());
});
```

- [ ] **Step 2: 运行 registry 测试确认它先失败**

Run: `flutter test test/widgets/main_shell_page_registry_test.dart -r expanded`

Expected: FAIL，提示 `MessagePage` 未定义或 registry 仍返回 `MessageCenterPage`。

- [ ] **Step 3: 新建消息模块 tab 容器页与 shell**

```dart
class MessagePage extends StatefulWidget {
  const MessagePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
    required this.capabilityCodes,
    this.moduleActive = true,
    this.preferredTabCode,
    this.routePayloadJson,
    this.messageService,
    this.refreshTick = 0,
    this.onUnreadCountChanged,
    this.onNavigateToPage,
    DateTime Function()? nowProvider,
  }) : nowProvider = nowProvider ?? DateTime.now;

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;
  final Set<String> capabilityCodes;
  final bool moduleActive;
  final String? preferredTabCode;
  final String? routePayloadJson;
  final MessageService? messageService;
  final int refreshTick;
  final void Function(int count)? onUnreadCountChanged;
  final void Function(String pageCode, {String? tabCode, String? routePayloadJson})? onNavigateToPage;
  final DateTime Function() nowProvider;
  ...
}
```

- [ ] **Step 4: 再写消息中心失败测试，要求旧页面不再显示“发布公告”**

```dart
testWidgets('message center 主页面不再显示发布公告按钮', (tester) async {
  final service = _FakeMessageService();

  await _pumpMessageCenterPage(
    tester,
    service: service,
    canPublishAnnouncement: true,
  );

  expect(find.text('发布公告'), findsNothing);
  expect(find.text('执行维护'), findsOneWidget);
});
```

- [ ] **Step 5: 运行消息中心测试确认它先失败**

Run: `flutter test test/widgets/message_center_page_test.dart -r expanded`

Expected: FAIL，因为当前页头仍显示“发布公告”。

- [ ] **Step 6: 从消息中心页头移除发布公告入口，并在 registry 中接入 `MessagePage`**

```dart
class MessageCenterHeader extends StatelessWidget {
  const MessageCenterHeader({
    super.key,
    required this.nowText,
    required this.errorText,
    required this.loading,
    required this.onRefresh,
    required this.onMaintenance,
    required this.onMarkAllRead,
    required this.onMarkBatchRead,
    required this.batchReadCount,
  });
  ...
}

// main_shell_page_registry.dart
case 'message':
  final capabilityCodes = capabilityCodesFor('message');
  return MessagePage(
    session: session,
    onLogout: onLogout,
    visibleTabCodes: tabCodesFor('message'),
    capabilityCodes: capabilityCodes,
    moduleActive: moduleActiveFor('message'),
    preferredTabCode: state.preferredTabCode,
    routePayloadJson: state.preferredRoutePayloadJson,
    messageService: messageService,
    refreshTick: state.messageRefreshTick,
    onUnreadCountChanged: onUnreadCountChanged,
    onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
      onNavigateToPageTarget(
        pageCode: pageCode,
        tabCode: tabCode,
        routePayloadJson: routePayloadJson,
      );
    },
    nowProvider: timeSyncController.effectiveClock.now,
  );
```

- [ ] **Step 7: 写主壳集成测试，验证“公告管理”页签可见且能切换**

```dart
testWidgets('主壳消息模块可切到公告管理子页', (tester) async {
  await _pumpMainShellPage(
    tester,
    authService: _TestShellAuthService(),
    authzService: _TestShellAuthzService(
      snapshot: _buildSnapshot(
        visibleSidebarCodes: const ['message'],
        tabCodesByParent: const {
          'message': ['message_center', 'announcement_management'],
        },
        moduleItems: [
          _buildModuleItem(
            'message',
            capabilityCodes: const [
              'feature.message.center.view',
              'feature.message.announcement.view',
              'feature.message.announcement.publish',
              'feature.message.announcement.offline',
            ],
          ),
        ],
      ),
    ),
    pageCatalogService: _TestShellPageCatalogService(),
    messageService: _TestShellMessageService(),
    onLogout: ({String? reason}) {},
  );

  await tester.tap(find.byKey(const ValueKey('main-shell-menu-message')));
  await tester.pumpAndSettle();
  expect(find.text('公告管理'), findsWidgets);
  await tester.tap(find.text('公告管理').last);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('announcement-management-page')), findsOneWidget);
});
```

- [ ] **Step 8: 运行消息模块相关 widget 测试确认通过**

Run: `flutter test test/widgets/message_center_page_test.dart test/widgets/main_shell_page_registry_test.dart test/widgets/main_shell_page_test.dart test/widgets/announcement_management_page_test.dart -r expanded`

Expected: PASS，消息模块可见页签、旧按钮移除和主壳集成链路通过。

- [ ] **Step 9: 提交消息模块 tab 化与主壳集成**

```bash
git add frontend/lib/features/message/presentation/message_page.dart frontend/lib/features/message/presentation/widgets/message_page_shell.dart frontend/lib/features/message/presentation/message_center_page.dart frontend/lib/features/message/presentation/widgets/message_center_header.dart frontend/lib/features/message/presentation/widgets/message_center_action_bar.dart frontend/lib/features/shell/presentation/main_shell_page_registry.dart frontend/test/widgets/message_center_page_test.dart frontend/test/widgets/main_shell_page_registry_test.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "将消息模块改为公告管理双页签"
```

## Task 5: 全链路回归与提交前收口

**Files:**
- Verify only

- [ ] **Step 1: 跑后端公告管理相关测试**

Run: `python -m pytest backend/tests/test_message_service_unit.py backend/tests/test_message_module_integration.py -k "announcement or active_announcements or offline" -q`

Expected: PASS，公告服务层、接口层、公开公告链路一起为绿。

- [ ] **Step 2: 跑前端消息模块相关测试**

Run: `flutter test test/services/message_service_test.dart test/widgets/announcement_management_page_test.dart test/widgets/message_center_page_test.dart test/widgets/main_shell_page_registry_test.dart test/widgets/main_shell_page_test.dart -r expanded`

Expected: PASS，消息模块服务、消息中心、公告管理页、主壳 registry、主壳集成全部通过。

- [ ] **Step 3: 跑一条登录页公开公告回归**

Run: `python -m pytest backend/tests/test_message_module_integration.py -k "public_announcements_endpoint_only_returns_active_all_announcements" -q`

Expected: PASS，下线/状态扩展没有破坏登录页公开公告能力。

- [ ] **Step 4: 检查提交范围与空白错误**

Run: `git status --short --untracked-files=all`

Expected: 只包含本任务相关文件。

Run: `git diff --check`

Expected: 无 trailing whitespace、无冲突标记、无格式错误。

- [ ] **Step 5: 提交最终收口**

```bash
git add backend/app/models/message.py backend/app/schemas/message.py backend/app/services/message_service.py backend/app/api/v1/endpoints/messages.py backend/app/core/page_catalog.py backend/app/core/authz_catalog.py backend/app/core/authz_hierarchy_catalog.py backend/app/services/authz_service.py backend/tests/test_message_service_unit.py backend/tests/test_message_module_integration.py frontend/lib/features/message/models/message_models.dart frontend/lib/features/message/services/message_service.dart frontend/lib/features/message/presentation/announcement_management_page.dart frontend/lib/features/message/presentation/message_page.dart frontend/lib/features/message/presentation/message_center_page.dart frontend/lib/features/message/presentation/widgets/message_page_shell.dart frontend/lib/features/message/presentation/widgets/message_center_header.dart frontend/lib/features/message/presentation/widgets/message_center_action_bar.dart frontend/lib/features/shell/presentation/main_shell_page_registry.dart frontend/test/services/message_service_test.dart frontend/test/widgets/announcement_management_page_test.dart frontend/test/widgets/message_center_page_test.dart frontend/test/widgets/main_shell_page_registry_test.dart frontend/test/widgets/main_shell_page_test.dart
git commit -m "新增消息模块公告管理能力"
```

## 自检结果

### Spec coverage

- “消息模块下新增公告管理子页”：Task 2、Task 4 覆盖。
- “当前生效公告列表”：Task 1、Task 2、Task 3 覆盖。
- “发布公告”：Task 3、Task 4 复用并迁移入口。
- “下线公告”：Task 1、Task 2、Task 3 覆盖。
- “页面目录/权限/主壳集成”：Task 2、Task 4 覆盖。
- “公开公告不回归”：Task 2、Task 5 覆盖。

### Placeholder scan

- 计划中没有 `TODO`、`TBD`、`implement later`、`similar to Task N` 一类占位表述。
- 所有需要新增的方法、页面和测试都给出了具体文件路径、代码片段和命令。

### Type consistency

- 后端统一使用 `list_active_announcements()`、`offline_announcement()`。
- 前端统一使用 `getActiveAnnouncements()`、`offlineAnnouncement()`、`AnnouncementManagementPage`、`MessagePage`。
- 页面编码统一使用 `announcement_management`。


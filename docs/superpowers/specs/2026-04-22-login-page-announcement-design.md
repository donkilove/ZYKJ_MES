# 登录页公告功能实现设计

## 1. 概述

**目标：** 将登录页面的公告功能从硬编码静态数据改为从后端动态获取，实现真正的可用功能。

**问题现状：**
- 登录页公告使用硬编码静态数据（占位功能）
- 后端已有完整的公告功能（发布、存储）
- 前端已有发布公告的对话框
- 缺少从后端获取公告列表的代码

**技术背景：**
- 后端使用 `message_type='announcement'` 区分公告与其他消息
- 复用现有消息列表 API 获取公告
- 支持 Markdown 富文本渲染

---

## 2. 功能需求

| 需求 | 说明 |
|------|------|
| 动态加载 | 登录时从后端获取公告列表 |
| Markdown 渲染 | 支持基本 Markdown 格式（加粗、列表、链接） |
| 优先级显示 | 普通=蓝色，重要=橙色，紧急=红色 |
| 有效期显示 | 显示剩余有效时间 |
| 降级处理 | 后端不可用时优雅降级 |
| 按优先级排序 | 紧急 > 重要 > 普通 > 其他 |

---

## 3. 架构设计

### 3.1 组件关系

```
LoginPage
  └── _LoginPageState
        ├── _announcements: List<MessageItem>     # 公告列表
        ├── _loadingAnnouncements: bool           # 加载状态
        ├── _loadAnnouncements()                  # 加载公告
        └── _buildAnnouncementCard()             # 构建公告卡片

MessageService
  └── getAnnouncements()                         # 获取公告列表（新增）

Backend API
  └── GET /messages?message_type=announcement    # 复用现有 API
```

### 3.2 数据流

1. 用户打开登录页
2. `initState` 调用 `_loadAnnouncements()`
3. `_loadAnnouncements()` 调用 `MessageService.getAnnouncements()`
4. 获取公告列表后更新状态
5. `_buildAnnouncementCard` 根据数据渲染

---

## 4. 详细设计

### 4.1 MessageService 新增方法

**文件：** `frontend/lib/features/message/services/message_service.dart`

```dart
Future<List<MessageItem>> getAnnouncements({
  int pageSize = 20,
  String? priority,
  DateTime? since,
}) async {
  final uri = Uri.parse('$_base/messages').replace(
    queryParameters: {
      'message_type': 'announcement',
      'page_size': pageSize.toString(),
      'status': 'active',
      if (priority != null) 'priority': priority,
    },
  );

  final response = await _client.get(uri, headers: _headers);
  final body = json.decode(response.body) as Map<String, dynamic>;
  final apiResponse = ApiResponse.fromJson(body);

  if (apiResponse.code != 0) {
    throw ApiException(apiResponse.code, apiResponse.message);
  }

  final result = apiResponse.data as Map<String, dynamic>;
  final items = result['items'] as List<dynamic>;
  return items.map((e) => MessageItem.fromJson(e as Map<String, dynamic>)).toList();
}
```

### 4.2 LoginPage 修改

**文件：** `frontend/lib/features/misc/presentation/login_page.dart`

#### 4.2.1 移除硬编码数据

移除以下静态数据：
```dart
// 删除
static const List<_NoticeSection> _noticeSections = [
  _NoticeSection(
    title: '生产运行提醒',
    items: ['...'],
  ),
  // ...
];
```

#### 4.2.2 新增状态

```dart
class _LoginPageState extends State<LoginPage> {
  // 新增
  List<MessageItem> _announcements = [];
  bool _loadingAnnouncements = false;
  String? _announcementError;
}
```

#### 4.2.3 新增加载方法

```dart
Future<void> _loadAnnouncements() async {
  if (_session == null) return;

  setState(() {
    _loadingAnnouncements = true;
    _announcementError = null;
  });

  try {
    final service = MessageService(_session);
    final items = await service.getAnnouncements(pageSize: 10);
    if (mounted) {
      setState(() {
        _announcements = items;
        _loadingAnnouncements = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _announcementError = e.toString();
        _loadingAnnouncements = false;
      });
    }
  }
}
```

#### 4.2.4 修改 initState

```dart
@override
void initState() {
  super.initState();
  _baseUrlController = TextEditingController(text: widget.initialBaseUrl ?? '');
  _authService = AuthService();
  _session = widget.initialSession;

  _loadAnnouncements(); // 新增
}
```

#### 4.2.5 修改 _buildAnnouncementCard

```dart
Widget _buildAnnouncementCard(ThemeData theme, {required bool fillHeight}) {
  if (_loadingAnnouncements) {
    return _buildLoadingCard(theme);
  }

  if (_announcements.isEmpty) {
    return _buildEmptyAnnouncementCard(theme);
  }

  return _buildAnnouncementList(theme, _announcements, fillHeight: fillHeight);
}
```

### 4.3 公告卡片组件

**文件：** 新增 `frontend/lib/features/message/presentation/widgets/announcement_card.dart`

```dart
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.item,
  });

  final MessageItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = _getPriorityColor(item.priority);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: priorityColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PriorityBadge(priority: item.priority),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (item.expiresAt != null)
                _ExpiryBadge(expiresAt: item.expiresAt!),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: item.content ?? item.summary ?? '',
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. API 接口

### 5.1 获取公告列表

**端点：** `GET /messages`

**参数：**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| message_type | string | 是 | 固定为 `announcement` |
| status | string | 是 | 固定为 `active` |
| page_size | int | 否 | 默认 20 |
| priority | string | 否 | 筛选优先级 |

**响应：** 复用现有 `MessageListResult`

---

## 6. 测试计划

### 6.1 单元测试

| 测试项 | 说明 |
|--------|------|
| `MessageService.getAnnouncements` | 验证 API 调用和响应解析 |
| `_loadAnnouncements` 成功路径 | 验证数据加载 |
| `_loadAnnouncements` 失败路径 | 验证错误处理 |

### 6.2 Widget 测试

| 测试项 | 说明 |
|--------|------|
| `_AnnouncementCard` 渲染 | 验证各优先级样式 |
| 公告为空时显示 | 验证空状态 |
| Markdown 渲染 | 验证富文本显示 |

### 6.3 集成测试

| 测试项 | 说明 |
|--------|------|
| 登录页公告加载 | 验证完整流程 |

---

## 7. 验收标准

- [ ] `MessageService.getAnnouncements()` 方法正常工作
- [ ] 登录页从后端获取公告列表
- [ ] 公告按优先级排序显示
- [ ] 支持 Markdown 渲染
- [ ] 优先级标签样式正确（普通/重要/紧急）
- [ ] 有效期显示正确
- [ ] 后端不可用时优雅降级
- [ ] 相关测试通过

---

## 8. 后续扩展

- 公告分类/标签功能
- 公告已读状态
- 公告推送通知
- 公告数据统计

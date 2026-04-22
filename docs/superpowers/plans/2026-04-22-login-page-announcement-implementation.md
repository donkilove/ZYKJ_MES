# 登录页公告功能实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将登录页公告从硬编码静态数据改为从后端动态获取，支持 Markdown 渲染和优先级显示

**架构：** 修改 LoginPage 从 MessageService 获取公告列表，复用现有消息列表 API（过滤 message_type='announcement'）

**技术栈：** Flutter, Dart, Markdown 渲染, Widget Testing

---

## 文件清单

| 文件 | 职责 |
|------|------|
| `frontend/lib/features/message/services/message_service.dart` | 新增 `getAnnouncements()` 方法 |
| `frontend/lib/features/message/models/message_models.dart` | 确认 MessageItem 模型 |
| `frontend/lib/features/misc/presentation/login_page.dart` | 修改为动态获取公告 |
| `frontend/lib/features/message/presentation/widgets/announcement_card.dart` | 新建公告卡片组件 |
| `frontend/test/widgets/login_page_announcement_test.dart` | 新建登录页公告测试 |

---

## 任务 1：确认 MessageItem 模型

**文件：**
- 确认：`frontend/lib/features/message/models/message_models.dart:100-150`

- [ ] **步骤 1：阅读 MessageItem 模型**

确认 `MessageItem` 是否包含所需字段：
- `id`, `title`, `content`, `summary`
- `priority` (normal/important/urgent)
- `expiresAt`
- `publishedAt`

如果缺少字段，记录需要修改的 schema。

---

## 任务 2：MessageService 新增 getAnnouncements 方法

**文件：**
- 修改：`frontend/lib/features/message/services/message_service.dart`

- [ ] **步骤 1：阅读现有 MessageService 实现**

确认：
- API 基础路径
- 请求/响应处理模式
- 错误处理方式

- [ ] **步骤 2：添加 getAnnouncements 方法**

在 `MessageService` 类中添加：

```dart
Future<List<MessageItem>> getAnnouncements({
  int pageSize = 20,
  String? priority,
}) async {
  final queryParams = <String, String>{
    'message_type': 'announcement',
    'page_size': pageSize.toString(),
    'status': 'active',
    if (priority != null) 'priority': priority,
  };

  final uri = Uri.parse('$_base/messages').replace(queryParameters: queryParams);
  final response = await _client.get(uri, headers: _headers);
  final body = json.decode(response.body) as Map<String, dynamic>;
  final apiResponse = ApiResponse.fromJson(body);

  if (apiResponse.code != 0) {
    throw ApiException(apiResponse.code, apiResponse.message);
  }

  final data = apiResponse.data as Map<String, dynamic>;
  final items = data['items'] as List<dynamic>;
  return items.map((e) => MessageItem.fromJson(e as Map<String, dynamic>)).toList();
}
```

- [ ] **步骤 3：运行分析验证**

运行：`cd frontend && flutter analyze lib/features/message/services/message_service.dart`
预期：No issues found

- [ ] **步骤 4：提交更改**

```bash
git add frontend/lib/features/message/services/message_service.dart
git commit -m "feat(message): 新增 getAnnouncements 方法"
```

---

## 任务 3：创建 AnnouncementCard 组件

**文件：**
- 创建：`frontend/lib/features/message/presentation/widgets/announcement_card.dart`

- [ ] **步骤 1：创建 AnnouncementCard 组件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:mes_client/features/message/models/message_models.dart';

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.item,
  });

  final MessageItem item;

  Color get _priorityColor {
    return switch (item.priority) {
      'urgent' => Colors.red,
      'important' => Colors.orange,
      _ => Colors.blue,
    };
  }

  String get _priorityLabel {
    return switch (item.priority) {
      'urgent' => '紧急',
      'important' => '重要',
      _ => '普通',
    };
  }

  String _formatExpiry(DateTime expiresAt) {
    final now = DateTime.now();
    final diff = expiresAt.difference(now);
    if (diff.isNegative) {
      return '已过期';
    }
    if (diff.inDays > 0) {
      return '剩余 ${diff.inDays} 天';
    }
    if (diff.inHours > 0) {
      return '剩余 ${diff.inHours} 小时';
    }
    return '即将过期';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _priorityColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _priorityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _priorityLabel,
                  style: TextStyle(
                    color: _priorityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatExpiry(item.expiresAt!),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (item.content != null && item.content!.isNotEmpty)
            MarkdownBody(
              data: item.content!,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyMedium,
              ),
            )
          else if (item.summary != null && item.summary!.isNotEmpty)
            Text(
              item.summary!,
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}
```

- [ ] **步骤 2：添加 flutter_markdown 依赖**

检查 `pubspec.yaml` 是否包含 `flutter_markdown`：
```yaml
dependencies:
  flutter_markdown: ^0.7.0
```

如果不存在，添加依赖。

- [ ] **步骤 3：运行分析验证**

运行：`cd frontend && flutter analyze lib/features/message/presentation/widgets/announcement_card.dart`
预期：No issues found

- [ ] **步骤 4：提交更改**

```bash
git add frontend/lib/features/message/presentation/widgets/announcement_card.dart
git add pubspec.yaml  # 如果修改了
git commit -m "feat(message): 创建 AnnouncementCard 组件"
```

---

## 任务 4：修改 LoginPage 获取动态公告

**文件：**
- 修改：`frontend/lib/features/misc/presentation/login_page.dart`

- [ ] **步骤 1：阅读现有 LoginPage 实现**

确认：
- 现有状态管理方式
- `_buildAnnouncementCard` 方法位置
- `_session` 初始化方式

- [ ] **步骤 2：移除硬编码公告数据**

删除 `_NoticeSection` 类和静态数据：

```dart
// 删除以下内容：
class _NoticeSection { ... }

static const List<_NoticeSection> _noticeSections = [ ... ];
```

- [ ] **步骤 3：添加状态变量**

在 `_LoginPageState` 类中添加：

```dart
List<MessageItem> _announcements = [];
bool _loadingAnnouncements = false;
String? _announcementError;
```

- [ ] **步骤 4：修改 initState 添加加载公告**

在 `initState` 方法末尾添加：

```dart
_loadAnnouncements();
```

添加 `_loadAnnouncements` 方法：

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

- [ ] **步骤 5：修改 _buildAnnouncementCard 方法**

将 `_buildAnnouncementCard` 方法改为：

```dart
Widget _buildAnnouncementCard(ThemeData theme, {required bool fillHeight}) {
  if (_loadingAnnouncements) {
    return _buildLoadingAnnouncementCard(theme);
  }

  if (_announcementError != null) {
    return _buildErrorAnnouncementCard(theme, _announcementError!);
  }

  if (_announcements.isEmpty) {
    return _buildEmptyAnnouncementCard(theme);
  }

  return _buildAnnouncementList(theme, _announcements, fillHeight: fillHeight);
}

Widget _buildLoadingAnnouncementCard(ThemeData theme) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('加载公告...', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    ),
  );
}

Widget _buildErrorAnnouncementCard(ThemeData theme, String error) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
          const SizedBox(height: 8),
          Text('公告加载失败', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            error,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptyAnnouncementCard(ThemeData theme) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, color: theme.colorScheme.outline, size: 32),
            const SizedBox(height: 8),
            Text('暂无公告', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    ),
  );
}

Widget _buildAnnouncementList(
  ThemeData theme,
  List<MessageItem> items, {
  required bool fillHeight,
}) {
  final cards = items.map((item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AnnouncementCard(item: item),
  )).toList();

  if (fillHeight) {
    return ListView(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      children: cards,
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: cards,
  );
}
```

- [ ] **步骤 6：添加必要的 import**

确保文件头部包含：

```dart
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/presentation/widgets/announcement_card.dart';
```

- [ ] **步骤 7：运行分析验证**

运行：`cd frontend && flutter analyze lib/features/misc/presentation/login_page.dart`
预期：No issues found

- [ ] **步骤 8：提交更改**

```bash
git add frontend/lib/features/misc/presentation/login_page.dart
git commit -m "feat(login): 登录页公告改为从后端动态获取"
```

---

## 任务 5：编写测试

**文件：**
- 创建：`frontend/test/widgets/login_page_announcement_test.dart`

- [ ] **步骤 1：创建测试文件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/presentation/widgets/announcement_card.dart';

void main() {
  group('AnnouncementCard', () {
    testWidgets('显示普通优先级公告', (tester) async {
      final item = MessageItem(
        id: 1,
        messageType: 'announcement',
        priority: 'normal',
        title: '测试公告',
        content: '这是测试内容',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementCard(item: item),
          ),
        ),
      );

      expect(find.text('普通'), findsOneWidget);
      expect(find.text('测试公告'), findsOneWidget);
      expect(find.text('这是测试内容'), findsOneWidget);
    });

    testWidgets('显示重要优先级公告', (tester) async {
      final item = MessageItem(
        id: 2,
        messageType: 'announcement',
        priority: 'important',
        title: '重要公告',
        content: '重要内容',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementCard(item: item),
          ),
        ),
      );

      expect(find.text('重要'), findsOneWidget);
      expect(find.text('重要公告'), findsOneWidget);
    });

    testWidgets('显示紧急优先级公告', (tester) async {
      final item = MessageItem(
        id: 3,
        messageType: 'announcement',
        priority: 'urgent',
        title: '紧急公告',
        content: '紧急内容',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementCard(item: item),
          ),
        ),
      );

      expect(find.text('紧急'), findsOneWidget);
      expect(find.text('紧急公告'), findsOneWidget);
    });

    testWidgets('显示有效期倒计时', (tester) async {
      final expiresAt = DateTime.now().add(const Duration(days: 5));
      final item = MessageItem(
        id: 4,
        messageType: 'announcement',
        priority: 'normal',
        title: '限时公告',
        content: '限时内容',
        expiresAt: expiresAt,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementCard(item: item),
          ),
        ),
      );

      expect(find.textContaining('剩余'), findsOneWidget);
      expect(find.textContaining('天'), findsOneWidget);
    });

    testWidgets('无 content 时显示 summary', (tester) async {
      final item = MessageItem(
        id: 5,
        messageType: 'announcement',
        priority: 'normal',
        title: '摘要公告',
        summary: '这是摘要内容',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementCard(item: item),
          ),
        ),
      );

      expect(find.text('这是摘要内容'), findsOneWidget);
    });
  });
}
```

- [ ] **步骤 2：运行测试验证**

运行：`cd frontend && flutter test test/widgets/login_page_announcement_test.dart`
预期：所有测试通过

- [ ] **步骤 3：提交更改**

```bash
git add frontend/test/widgets/login_page_announcement_test.dart
git commit -m "test(message): 添加 AnnouncementCard 组件测试"
```

---

## 任务 6：运行完整测试验证

- [ ] **步骤 1：运行相关测试**

运行：`cd frontend && flutter test test/widgets/`
预期：所有测试通过

- [ ] **步骤 2：运行分析**

运行：`cd frontend && flutter analyze`
预期：No issues found

---

## 验收检查清单

- [ ] `MessageService.getAnnouncements()` 方法正常工作
- [ ] 登录页从后端获取公告列表
- [ ] `AnnouncementCard` 组件渲染正确
- [ ] 优先级样式正确（普通=蓝色，重要=橙色，紧急=红色）
- [ ] 有效期倒计时显示正确
- [ ] Markdown 内容渲染正确
- [ ] 加载状态显示
- [ ] 错误状态降级处理
- [ ] 空状态显示
- [ ] 相关测试通过

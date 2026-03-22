import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/message_models.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/message_service.dart';
import '../services/user_service.dart';

class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.canPublishAnnouncement = false,
    this.onUnreadCountChanged,
    this.onNavigateToPage,
    this.service,
    this.userService,
    this.refreshTick = 0,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canPublishAnnouncement;
  final void Function(int count)? onUnreadCountChanged;
  final void Function(
    String pageCode, {
    String? tabCode,
    String? routePayloadJson,
  })?
  onNavigateToPage;
  final MessageService? service;
  final UserService? userService;
  final int refreshTick;

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage> {
  late final MessageService _service;
  late final UserService _userService;
  Timer? _pollTimer;

  bool _loading = false;
  String _error = '';
  List<MessageItem> _items = [];
  MessageItem? _selectedItem;
  int _total = 0;
  int _page = 1;
  static const int _pageSize = 20;

  // 概览统计
  int _unreadCount = 0;
  int _todoCount = 0;
  int _urgentCount = 0;
  final Set<int> _selectedIds = <int>{};

  // 筛选条件
  final _keywordCtrl = TextEditingController();
  String _statusFilter = '';
  String _typeFilter = '';
  String _priorityFilter = '';
  String _sourceModuleFilter = '';
  DateTimeRange? _dateRange;
  bool _todoOnly = false;
  bool _includeInactive = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MessageService(widget.session);
    _userService = widget.userService ?? UserService(widget.session);
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _load(reset: false);
    });
  }

  @override
  void didUpdateWidget(covariant MessageCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTick != oldWidget.refreshTick) {
      _load(reset: false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = '';
      if (reset) _page = 1;
    });
    try {
      final result = await _service.listMessages(
        page: _page,
        pageSize: _pageSize,
        keyword: _keywordCtrl.text.trim().isEmpty
            ? null
            : _keywordCtrl.text.trim(),
        status: _statusFilter.isEmpty ? null : _statusFilter,
        messageType: _typeFilter.isEmpty ? null : _typeFilter,
        priority: _priorityFilter.isEmpty ? null : _priorityFilter,
        sourceModule: _sourceModuleFilter.isEmpty ? null : _sourceModuleFilter,
        startTime: _dateRange?.start,
        endTime: _dateRange?.end,
        todoOnly: _todoOnly,
        activeOnly: !_includeInactive,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _selectedItem = result.items.isEmpty
            ? null
            : result.items.firstWhere(
                (item) => item.id == _selectedItem?.id,
                orElse: () => result.items.first,
              );
        _selectedIds.removeWhere((id) => !_items.any((item) => item.id == id));
      });
      _refreshStats();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshStats() async {
    try {
      final summary = await _service.getSummary();
      widget.onUnreadCountChanged?.call(summary.unreadCount);
      if (!mounted) return;
      setState(() {
        _unreadCount = summary.unreadCount;
        _todoCount = summary.todoUnreadCount;
        _urgentCount = summary.urgentUnreadCount;
      });
    } catch (_) {}
  }

  Future<void> _markRead(MessageItem item) async {
    if (item.isRead) return;
    try {
      await _service.markRead(item.id);
      await _load(reset: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) widget.onLogout();
    } catch (_) {}
  }

  Future<void> _markBatchRead() async {
    if (_selectedIds.isEmpty) {
      return;
    }
    try {
      await _service.markBatchRead(_selectedIds.toList()..sort());
      await _load(reset: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      await _load(reset: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) widget.onLogout();
    } catch (_) {}
  }

  Future<void> _publishAnnouncement() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _AnnouncementPublishDialog(
          userService: _userService,
          service: _service,
        );
      },
    );
    if (changed == true && mounted) {
      await _load(reset: false);
    }
  }

  void _resetFilters() {
    setState(() {
      _keywordCtrl.clear();
      _statusFilter = '';
      _typeFilter = '';
      _priorityFilter = '';
      _sourceModuleFilter = '';
      _dateRange = null;
      _todoOnly = false;
      _includeInactive = false;
      _selectedIds.clear();
    });
    _load();
  }

  void _toggleSelected(int messageId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(messageId);
      } else {
        _selectedIds.remove(messageId);
      }
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _load();
    }
  }

  void _navigateToPage(MessageItem item) {
    final pageCode = item.targetPageCode;
    if (pageCode == null || pageCode.isEmpty) return;
    widget.onNavigateToPage?.call(
      pageCode,
      tabCode: item.targetTabCode,
      routePayloadJson: item.targetRoutePayloadJson,
    );
  }

  String _formatDateTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  void _showDetailDialog(MessageItem item) {
    showDialog(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);
        final rows = <Widget>[
          _detailRow('标题', item.title, theme),
          _detailRow('类型', item.messageTypeName, theme),
          _detailRow('优先级', item.priorityName, theme),
          if (item.summary != null && item.summary!.isNotEmpty)
            _detailRow('摘要', item.summary!, theme),
          if (item.content != null && item.content!.isNotEmpty)
            _detailRow('内容', item.content!, theme),
          if (item.sourceModuleName.isNotEmpty)
            _detailRow('来源模块', item.sourceModuleName, theme),
          if (item.sourceCode != null && item.sourceCode!.isNotEmpty)
            _detailRow('来源编号', item.sourceCode!, theme),
          if (item.publishedAt != null)
            _detailRow('发布时间', _formatDateTime(item.publishedAt!), theme),
          _detailRow('状态', item.isRead ? '已读' : '未读', theme),
          if (item.readAt != null)
            _detailRow('阅读时间', _formatDateTime(item.readAt!), theme),
        ];
        return AlertDialog(
          title: const Text('消息详情'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: rows),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(theme),
        const Divider(height: 1),
        _buildOverview(theme),
        const Divider(height: 1),
        _buildFilterBar(theme),
        const Divider(height: 1),
        Expanded(child: _buildBody(theme)),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            '消息中心',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _error,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _loading ? null : _resetFilters,
            icon: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text('重置'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('刷新'),
          ),
          if (widget.canPublishAnnouncement) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _publishAnnouncement,
              icon: const Icon(Icons.campaign_outlined, size: 16),
              label: const Text('发布公告'),
            ),
          ],
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _markAllRead,
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('全部已读'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _loading || _selectedIds.isEmpty ? null : _markBatchRead,
            icon: const Icon(Icons.playlist_add_check, size: 16),
            label: Text(
              '批量已读${_selectedIds.isEmpty ? '' : '(${_selectedIds.length})'}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _overviewCard(theme, '未读消息', _unreadCount, theme.colorScheme.primary),
          const SizedBox(width: 12),
          _overviewCard(theme, '待处理', _todoCount, Colors.orange),
          const SizedBox(width: 12),
          _overviewCard(theme, '紧急未读', _urgentCount, theme.colorScheme.error),
          const SizedBox(width: 12),
          _overviewCard(theme, '全部消息', _total, theme.colorScheme.outline),
        ],
      ),
    );
  }

  Widget _overviewCard(ThemeData theme, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 36,
            child: TextField(
              controller: _keywordCtrl,
              decoration: const InputDecoration(
                hintText: '搜索标题/摘要',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          _filterDropdown(
            '状态',
            _statusFilter,
            {'': '全部', 'unread': '未读', 'read': '已读'},
            (v) => setState(() {
              _statusFilter = v;
              _load();
            }),
          ),
          _filterDropdown(
            '分类',
            _typeFilter,
            {
              '': '全部',
              'todo': '待处理',
              'notice': '通知',
              'announcement': '公告',
              'warning': '预警',
            },
            (v) => setState(() {
              _typeFilter = v;
              _load();
            }),
          ),
          _filterDropdown(
            '优先级',
            _priorityFilter,
            {'': '全部', 'urgent': '紧急', 'important': '重要', 'normal': '普通'},
            (v) => setState(() {
              _priorityFilter = v;
              _load();
            }),
          ),
          _filterDropdown(
            '来源模块',
            _sourceModuleFilter,
            {
              '': '全部',
              'user': '用户',
              'production': '生产',
              'quality': '品质',
              'equipment': '设备',
              'product': '产品',
              'craft': '工艺',
            },
            (v) => setState(() {
              _sourceModuleFilter = v;
              _load();
            }),
          ),
          FilterChip(
            label: const Text('仅看待处理'),
            selected: _todoOnly,
            onSelected: (value) {
              setState(() => _todoOnly = value);
              _load();
            },
          ),
          FilterChip(
            label: const Text('包含历史消息'),
            selected: _includeInactive,
            onSelected: (value) {
              setState(() => _includeInactive = value);
              _load();
            },
          ),
          _dateRangeButton(theme),
        ],
      ),
    );
  }

  Widget _filterDropdown(
    String label,
    String current,
    Map<String, String> options,
    void Function(String) onChanged,
  ) {
    return DropdownButton<String>(
      value: current,
      isDense: true,
      underline: const SizedBox(),
      hint: Text(label),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _dateRangeButton(ThemeData theme) {
    final hasRange = _dateRange != null;
    return OutlinedButton.icon(
      onPressed: _pickDateRange,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(
          color: hasRange
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
      ),
      icon: Icon(
        Icons.date_range,
        size: 16,
        color: hasRange ? theme.colorScheme.primary : null,
      ),
      label: Text(
        hasRange
            ? '${_fmtDate(_dateRange!.start)} ~ ${_fmtDate(_dateRange!.end)}'
            : '推送时间',
        style: TextStyle(
          fontSize: 13,
          color: hasRange ? theme.colorScheme.primary : null,
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Widget _buildBody(ThemeData theme) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无消息',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _buildMessageTile(_items[index], theme),
              ),
            ),
            if (_total > _pageSize)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '共 $_total 条，当前第 $_page 页',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
        if (constraints.maxWidth < 1100) {
          return list;
        }
        return Row(
          children: [
            Expanded(child: list),
            const VerticalDivider(width: 1),
            SizedBox(width: 360, child: _buildPreview(theme)),
          ],
        );
      },
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final item = _selectedItem;
    if (item == null) {
      return Center(
        child: Text(
          '请选择一条消息查看详情预览',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }
    final disabledReason = item.isActive ? null : item.inactiveReasonName;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '消息详情预览',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _detailRow('标题', item.title, theme),
          _detailRow('分类', item.messageTypeName, theme),
          _detailRow('优先级', item.priorityName, theme),
          if (item.summary != null && item.summary!.isNotEmpty)
            _detailRow('摘要', item.summary!, theme),
          if (item.content != null && item.content!.isNotEmpty)
            _detailRow('正文', item.content!, theme),
          if (item.sourceModuleName.isNotEmpty)
            _detailRow('来源模块', item.sourceModuleName, theme),
          if (item.sourceCode != null && item.sourceCode!.isNotEmpty)
            _detailRow('来源对象', item.sourceCode!, theme),
          if (item.publishedAt != null)
            _detailRow('推送时间', _formatDateTime(item.publishedAt!), theme),
          _detailRow('当前状态', item.isRead ? '已读' : '未读', theme),
          if (item.readAt != null)
            _detailRow('已读时间', _formatDateTime(item.readAt!), theme),
          if (disabledReason != null) _detailRow('跳转状态', disabledReason, theme),
          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () => _showDetailDialog(item),
                child: const Text('弹窗查看'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: item.isActive && widget.onNavigateToPage != null
                    ? () {
                        _markRead(item);
                        _navigateToPage(item);
                      }
                    : null,
                child: const Text('跳转业务'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(MessageItem item, ThemeData theme) {
    final isUnread = !item.isRead;
    final priorityColor = item.priority == 'urgent'
        ? theme.colorScheme.error
        : item.priority == 'important'
        ? Colors.orange
        : null;
    final hasTarget =
        item.isActive &&
        item.targetPageCode != null &&
        item.targetPageCode!.isNotEmpty;
    final inactiveReason = item.isActive ? null : item.inactiveReasonName;

    return InkWell(
      onTap: () {
        setState(() => _selectedItem = item);
        _markRead(item);
        if (MediaQuery.of(context).size.width < 1100) {
          _showDetailDialog(item);
        }
      },
      child: Container(
        color: isUnread
            ? theme.colorScheme.primaryContainer.withAlpha(38)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 未读指示点
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnread
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (priorityColor != null)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withAlpha(38),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.priorityName,
                            style: TextStyle(
                              fontSize: 11,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.messageTypeName,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (item.summary != null && item.summary!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.summary!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.sourceModuleName.isNotEmpty)
                        Text(
                          item.sourceModuleName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      if (item.sourceCode != null &&
                          item.sourceCode!.isNotEmpty) ...[
                        Text(' · ', style: theme.textTheme.labelSmall),
                        Text(
                          item.sourceCode!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (item.publishedAt != null)
                        Text(
                          _formatTime(item.publishedAt!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // 操作按钮区
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Checkbox(
                  value: _selectedIds.contains(item.id),
                  onChanged: (value) =>
                      _toggleSelected(item.id, value ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                if (!item.isActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      inactiveReason!,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                if (hasTarget && widget.onNavigateToPage != null)
                  TextButton(
                    onPressed: () {
                      _markRead(item);
                      _navigateToPage(item);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('跳转', style: TextStyle(fontSize: 12)),
                  ),
                if (!item.isRead)
                  TextButton(
                    onPressed: () => _markRead(item),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('已读', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${local.month}-${local.day}';
  }
}

class _AnnouncementPublishDialog extends StatefulWidget {
  const _AnnouncementPublishDialog({
    required this.userService,
    required this.service,
  });

  final UserService userService;
  final MessageService service;

  @override
  State<_AnnouncementPublishDialog> createState() =>
      _AnnouncementPublishDialogState();
}

class _AnnouncementPublishDialogState
    extends State<_AnnouncementPublishDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _loadingOptions = true;
  bool _submitting = false;
  String _error = '';
  String _priority = 'normal';
  String _rangeType = 'all';
  DateTime? _expiresAt;
  List<RoleItem> _roles = const [];
  List<UserItem> _users = const [];
  final Set<String> _selectedRoleCodes = <String>{};
  final Set<int> _selectedUserIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _error = '';
    });
    try {
      final results = await Future.wait([
        widget.userService.listAllRoles(),
        widget.userService.listUsers(page: 1, pageSize: 200, isActive: true),
      ]);
      if (!mounted) {
        return;
      }
      final roleResult = results[0] as RoleListResult;
      final userResult = results[1] as UserListResult;
      setState(() {
        _roles = roleResult.items.where((item) => item.isEnabled).toList();
        _users = userResult.items
            .where((item) => item.isActive && !item.isDeleted)
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingOptions = false);
      }
    }
  }

  Future<void> _pickExpiresAt() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _expiresAt ?? now,
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _expiresAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (pickedTime == null || !mounted) {
      return;
    }
    setState(() {
      _expiresAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatLocalDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = '请填写标题和正文');
      return;
    }
    if (_rangeType == 'roles' && _selectedRoleCodes.isEmpty) {
      setState(() => _error = '请选择至少一个角色');
      return;
    }
    if (_rangeType == 'users' && _selectedUserIds.isEmpty) {
      setState(() => _error = '请选择至少一个用户');
      return;
    }

    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final result = await widget.service.publishAnnouncement(
        AnnouncementPublishRequest(
          title: title,
          content: content,
          priority: _priority,
          rangeType: _rangeType,
          roleCodes: _selectedRoleCodes.toList()..sort(),
          userIds: _selectedUserIds.toList()..sort(),
          expiresAt: _expiresAt,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('公告已发布，覆盖 ${result.recipientCount} 人')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildSelectionArea() {
    if (_rangeType == 'all') {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.groups_2_outlined),
        title: Text('发送给全部启用用户'),
        subtitle: Text('发布后将自动生成全员收件记录'),
      );
    }
    if (_loadingOptions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_rangeType == 'roles') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _roles
            .map(
              (role) => FilterChip(
                label: Text('${role.name}(${role.code})'),
                selected: _selectedRoleCodes.contains(role.code),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedRoleCodes.add(role.code);
                    } else {
                      _selectedRoleCodes.remove(role.code);
                    }
                  });
                },
              ),
            )
            .toList(),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final label = user.fullName?.trim().isNotEmpty == true
              ? '${user.fullName}(${user.username})'
              : user.username;
          return CheckboxListTile(
            value: _selectedUserIds.contains(user.id),
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            subtitle: Text(user.roleName ?? user.roleCode ?? '未分配角色'),
            onChanged: (selected) {
              setState(() {
                if (selected ?? false) {
                  _selectedUserIds.add(user.id);
                } else {
                  _selectedUserIds.remove(user.id);
                }
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('发布公告'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '正文',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: '优先级',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('普通')),
                  DropdownMenuItem(value: 'important', child: Text('重要')),
                  DropdownMenuItem(value: 'urgent', child: Text('紧急')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('发送范围'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('全员'),
                    selected: _rangeType == 'all',
                    onSelected: (_) => setState(() => _rangeType = 'all'),
                  ),
                  ChoiceChip(
                    label: const Text('指定角色'),
                    selected: _rangeType == 'roles',
                    onSelected: (_) => setState(() => _rangeType = 'roles'),
                  ),
                  ChoiceChip(
                    label: const Text('指定用户'),
                    selected: _rangeType == 'users',
                    onSelected: (_) => setState(() => _rangeType = 'users'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSelectionArea(),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('生效时间'),
                subtitle: Text(_formatLocalDateTime(DateTime.now())),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('失效时间'),
                subtitle: Text(
                  _expiresAt == null
                      ? '不设置'
                      : _formatLocalDateTime(_expiresAt!),
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _submitting ? null : _pickExpiresAt,
                      child: const Text('选择'),
                    ),
                    if (_expiresAt != null)
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _expiresAt = null),
                        child: const Text('清空'),
                      ),
                  ],
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '发布中...' : '确认发布'),
        ),
      ],
    );
  }
}

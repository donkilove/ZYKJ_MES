import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/message_models.dart';
import '../services/api_exception.dart';
import '../services/message_service.dart';

class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.onUnreadCountChanged,
    this.onNavigateToPage,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final void Function(int count)? onUnreadCountChanged;
  final void Function(String pageCode, {String? tabCode})? onNavigateToPage;

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage> {
  late final MessageService _service;

  bool _loading = false;
  String _error = '';
  List<MessageItem> _items = [];
  int _total = 0;
  int _page = 1;
  static const int _pageSize = 20;

  // 概览统计
  int _unreadCount = 0;
  int _todoCount = 0;
  int _urgentCount = 0;

  // 筛选条件
  final _keywordCtrl = TextEditingController();
  String _statusFilter = '';
  String _typeFilter = '';
  String _priorityFilter = '';
  String _sourceModuleFilter = '';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _service = MessageService(widget.session);
    _load();
  }

  @override
  void dispose() {
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
        keyword: _keywordCtrl.text.trim().isEmpty ? null : _keywordCtrl.text.trim(),
        status: _statusFilter.isEmpty ? null : _statusFilter,
        messageType: _typeFilter.isEmpty ? null : _typeFilter,
        priority: _priorityFilter.isEmpty ? null : _priorityFilter,
        sourceModule: _sourceModuleFilter.isEmpty ? null : _sourceModuleFilter,
        startTime: _dateRange?.start,
        endTime: _dateRange?.end,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
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
      final count = await _service.getUnreadCount();
      widget.onUnreadCountChanged?.call(count);
      // 统计当前列表中的待处理和紧急数（全量统计需额外接口，此处用当前页近似）
      final allResult = await _service.listMessages(pageSize: 200);
      if (!mounted) return;
      setState(() {
        _unreadCount = count;
        _todoCount = allResult.items.where((m) => m.messageType == 'todo' && !m.isRead).length;
        _urgentCount = allResult.items.where((m) => m.priority == 'urgent' && !m.isRead).length;
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

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      await _load(reset: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) widget.onLogout();
    } catch (_) {}
  }

  void _resetFilters() {
    setState(() {
      _keywordCtrl.clear();
      _statusFilter = '';
      _typeFilter = '';
      _priorityFilter = '';
      _sourceModuleFilter = '';
      _dateRange = null;
    });
    _load();
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
    widget.onNavigateToPage?.call(pageCode, tabCode: item.targetTabCode);
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
          Text('消息中心', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(_error, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
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
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _markAllRead,
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('全部已读'),
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
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
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
          _filterDropdown('状态', _statusFilter, {
            '': '全部',
            'unread': '未读',
            'read': '已读',
          }, (v) => setState(() { _statusFilter = v; _load(); })),
          _filterDropdown('分类', _typeFilter, {
            '': '全部',
            'todo': '待处理',
            'notice': '通知',
            'announcement': '公告',
            'warning': '预警',
          }, (v) => setState(() { _typeFilter = v; _load(); })),
          _filterDropdown('优先级', _priorityFilter, {
            '': '全部',
            'urgent': '紧急',
            'important': '重要',
            'normal': '普通',
          }, (v) => setState(() { _priorityFilter = v; _load(); })),
          _filterDropdown('来源模块', _sourceModuleFilter, {
            '': '全部',
            'user': '用户',
            'production': '生产',
            'quality': '品质',
            'equipment': '设备',
            'product': '产品',
            'craft': '工艺',
          }, (v) => setState(() { _sourceModuleFilter = v; _load(); })),
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
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }

  Widget _dateRangeButton(ThemeData theme) {
    final hasRange = _dateRange != null;
    return OutlinedButton.icon(
      onPressed: _pickDateRange,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(
          color: hasRange ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
      ),
      icon: Icon(Icons.date_range, size: 16,
          color: hasRange ? theme.colorScheme.primary : null),
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

  String _fmtDate(DateTime dt) => '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Widget _buildBody(ThemeData theme) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('暂无消息', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildMessageTile(_items[index], theme),
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
  }

  Widget _buildMessageTile(MessageItem item, ThemeData theme) {
    final isUnread = !item.isRead;
    final priorityColor = item.priority == 'urgent'
        ? theme.colorScheme.error
        : item.priority == 'important'
            ? Colors.orange
            : null;
    final isActive = item.status == 'active';
    final hasTarget = isActive && item.targetPageCode != null && item.targetPageCode!.isNotEmpty;

    return InkWell(
      onTap: () => _markRead(item),
      child: Container(
        color: isUnread ? theme.colorScheme.primaryContainer.withAlpha(38) : null,
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
                  color: isUnread ? theme.colorScheme.primary : Colors.transparent,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withAlpha(38),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.priorityName,
                            style: TextStyle(fontSize: 11, color: priorityColor),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
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
                      if (item.sourceCode != null && item.sourceCode!.isNotEmpty) ...[
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
                if (!isActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '来源已失效',
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('跳转', style: TextStyle(fontSize: 12)),
                  ),
                if (!item.isRead)
                  TextButton(
                    onPressed: () => _markRead(item),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_filter_section.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_header.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_detail_sections.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_list_section.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_message_card.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_overview_section.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_preview_panel.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';

String messageJumpDisabledReasonName(String? code) {
  switch (code) {
    case 'expired':
      return '该消息已过期，无法继续跳转';
    case 'archived':
      return '该消息已归档，无法继续跳转';
    case 'no_permission':
      return '当前账号暂无目标页面访问权限';
    case 'source_unavailable':
      return '来源对象已失效，无法继续跳转';
    case 'missing_target':
      return '该消息未配置业务跳转目标';
    default:
      return '当前消息暂不可跳转';
  }
}

class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.canPublishAnnouncement = false,
    this.canViewDetail = false,
    this.canUseJump = false,
    this.pollingEnabled = true,
    this.onUnreadCountChanged,
    this.onNavigateToPage,
    this.service,
    this.userService,
    this.refreshTick = 0,
    this.onPickDateRange,
    this.routePayloadJson,
    DateTime Function()? nowProvider,
  }) : nowProvider = nowProvider ?? DateTime.now;

  final AppSession session;
  final VoidCallback onLogout;
  final bool canPublishAnnouncement;
  final bool canViewDetail;
  final bool canUseJump;
  final bool pollingEnabled;
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
  final Future<DateTimeRange?> Function(DateTimeRange? initialDateRange)?
  onPickDateRange;
  final String? routePayloadJson;
  final DateTime Function() nowProvider;

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage> {
  late final MessageService _service;
  late final UserService _userService;
  Timer? _pollTimer;
  int _loadRequestToken = 0;

  bool _loading = false;
  String _error = '';
  List<MessageItem> _items = [];
  MessageItem? _selectedItem;
  int _total = 0;
  int _allMessageCount = 0;
  int _page = 1;
  int _pageSize = 20;
  bool _detailLoading = false;
  MessageDetailResult? _selectedDetail;

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
  String? _lastHandledRoutePayloadJson;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MessageService(widget.session);
    _userService = widget.userService ?? UserService(widget.session);
    _consumeRoutePayload(widget.routePayloadJson, triggerLoad: false);
    _load();
    _updatePollingState();
  }

  @override
  void didUpdateWidget(covariant MessageCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pollingBecameEnabled =
        !oldWidget.pollingEnabled && widget.pollingEnabled;
    final pollingBecameDisabled =
        oldWidget.pollingEnabled && !widget.pollingEnabled;
    if (pollingBecameDisabled) {
      _stopPolling();
    }
    if (widget.routePayloadJson != oldWidget.routePayloadJson) {
      _consumeRoutePayload(widget.routePayloadJson);
    }
    if (pollingBecameEnabled) {
      _updatePollingState(triggerImmediateLoad: true);
    } else if (widget.refreshTick != oldWidget.refreshTick &&
        widget.pollingEnabled) {
      _load(reset: false);
    }
  }

  void _consumeRoutePayload(String? rawPayload, {bool triggerLoad = true}) {
    if (rawPayload == null ||
        rawPayload.trim().isEmpty ||
        rawPayload == _lastHandledRoutePayloadJson) {
      return;
    }
    try {
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      final preset = (payload['preset'] as String? ?? '').trim();
      if (preset != 'todo_only') {
        return;
      }
      _lastHandledRoutePayloadJson = rawPayload;
      if (triggerLoad) {
        setState(() {
          _todoOnly = true;
          _page = 1;
          _selectedIds.clear();
        });
        _load();
      } else {
        _todoOnly = true;
        _page = 1;
        _selectedIds.clear();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _keywordCtrl.dispose();
    super.dispose();
  }

  void _applySummary(MessageSummaryResult summary) {
    if (!mounted) {
      return;
    }
    setState(() {
      _allMessageCount = summary.totalCount;
      _unreadCount = summary.unreadCount;
      _todoCount = summary.todoUnreadCount;
      _urgentCount = summary.urgentUnreadCount;
    });
    widget.onUnreadCountChanged?.call(summary.unreadCount);
  }

  Future<void> _load({bool reset = true}) async {
    if (_loading) return;
    final requestToken = ++_loadRequestToken;
    setState(() {
      _loading = true;
      _error = '';
      if (reset) _page = 1;
    });
    var listSucceeded = false;
    var summaryResolved = false;
    MessageSummaryResult? summaryResult;
    _service
        .getSummary()
        .then((summary) {
          summaryResolved = true;
          summaryResult = summary;
          if (!listSucceeded || !mounted || requestToken != _loadRequestToken) {
            return;
          }
          _applySummary(summary);
        })
        .catchError((_) {
          summaryResolved = true;
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
        _page = result.page;
        _pageSize = result.pageSize;
        _selectedItem = result.items.isEmpty
            ? null
            : result.items.firstWhere(
                (item) => item.id == _selectedItem?.id,
                orElse: () => result.items.first,
              );
        if (_selectedItem == null ||
            _selectedItem!.id != _selectedDetail?.item.id) {
          _selectedDetail = null;
        }
        _selectedIds.removeWhere((id) => !_items.any((item) => item.id == id));
      });
      listSucceeded = true;
      if (summaryResolved && summaryResult != null) {
        _applySummary(summaryResult!);
      }
      if (widget.canViewDetail && _selectedItem != null) {
        await _loadSelectedDetail(_selectedItem!.id, silent: true);
      }
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
      if (mounted && requestToken == _loadRequestToken) {
        setState(() => _loading = false);
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (!widget.pollingEnabled) {
      return;
    }
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _load(reset: false);
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _updatePollingState({bool triggerImmediateLoad = false}) {
    if (!widget.pollingEnabled) {
      _stopPolling();
      return;
    }
    if (triggerImmediateLoad) {
      _load(reset: false);
    }
    _startPolling();
  }

  Future<void> _loadSelectedDetail(int messageId, {bool silent = false}) async {
    if (!widget.canViewDetail) {
      return;
    }
    if (!silent && mounted) {
      setState(() => _detailLoading = true);
    }
    try {
      final detail = await _service.getMessageDetail(messageId);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedDetail = detail;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.statusCode == 401) {
        widget.onLogout();
        return;
      }
      if (!silent) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (!mounted || silent) {
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted && !silent) {
        setState(() => _detailLoading = false);
      }
    }
  }

  Future<void> _markRead(MessageItem item) async {
    if (item.isRead) return;
    try {
      await _service.markRead(item.id);
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

  Future<void> _runMaintenance() async {
    try {
      final result = await _service.runMaintenance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '维护完成：补偿${result.pendingCompensated}条，重试${result.failedRetried}条，失效同步${result.sourceUnavailableUpdated}条，归档${result.archivedMessages}条',
          ),
        ),
      );
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
    if (!mounted) {
      return;
    }
    final picker = widget.onPickDateRange;
    final DateTimeRange? picked;
    if (picker != null) {
      picked = await picker(_dateRange);
    } else {
      final now = widget.nowProvider();
      picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2, now.month, now.day),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: _dateRange,
      );
    }
    if (!mounted || picked == null) {
      return;
    }
    setState(() => _dateRange = picked);
    _load();
  }

  Future<void> _selectItem(MessageItem item, {bool silent = true}) async {
    setState(() {
      _selectedItem = item;
      if (_selectedDetail?.item.id != item.id) {
        _selectedDetail = null;
      }
    });
    if (widget.canViewDetail) {
      await _loadSelectedDetail(item.id, silent: silent);
    }
  }

  Future<void> _navigateToPage(MessageItem item) async {
    if (!widget.canUseJump || widget.onNavigateToPage == null) {
      return;
    }
    try {
      final jumpResult = await _service.getMessageJumpTarget(item.id);
      if (!mounted) {
        return;
      }
      if (!jumpResult.canJump ||
          jumpResult.targetPageCode == null ||
          jumpResult.targetPageCode!.isEmpty) {
        final disabledReason = messageJumpDisabledReasonName(
          jumpResult.disabledReason,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(disabledReason)));
        return;
      }
      widget.onNavigateToPage?.call(
        jumpResult.targetPageCode!,
        tabCode: jumpResult.targetTabCode,
        routePayloadJson: jumpResult.targetRoutePayloadJson,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.toString());
    }
  }

  String _formatDateTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  void _showDetailDialog(MessageItem item) {
    final detail = _selectedDetail?.item.id == item.id ? _selectedDetail : null;
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
          if (widget.canViewDetail &&
              detail?.item.content != null &&
              detail!.item.content!.isNotEmpty)
            _detailRow('内容', detail.item.content!, theme),
          if (item.sourceModuleName.isNotEmpty)
            _detailRow('来源模块', item.sourceModuleName, theme),
          if (detail?.sourceId != null && detail!.sourceId!.isNotEmpty)
            _detailRow('来源ID', detail.sourceId!, theme),
          if (item.sourceCode != null && item.sourceCode!.isNotEmpty)
            _detailRow('来源编号', item.sourceCode!, theme),
          if (item.publishedAt != null)
            _detailRow('发布时间', _formatDateTime(item.publishedAt!), theme),
          _detailRow('消息状态', item.statusName, theme),
          _detailRow('阅读状态', item.readStatusName, theme),
          _detailRow('投递状态', item.deliveryStatusName, theme),
          _detailRow('投递次数', '${item.deliveryAttemptCount}', theme),
          if (item.lastPushAt != null)
            _detailRow('最近投递', _formatDateTime(item.lastPushAt!), theme),
          if (item.nextRetryAt != null)
            _detailRow('下次重试', _formatDateTime(item.nextRetryAt!), theme),
          if (item.readAt != null)
            _detailRow('阅读时间', _formatDateTime(item.readAt!), theme),
          if (detail?.failureReasonHint != null &&
              detail!.failureReasonHint!.isNotEmpty)
            _detailRow('排障提示', detail.failureReasonHint!, theme),
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
    final effectiveNow = widget.nowProvider();
    return MesCrudPageScaffold(
      header: MessageCenterHeader(
        nowText: _formatDateTime(effectiveNow),
        errorText: _error,
        loading: _loading,
        canPublishAnnouncement: widget.canPublishAnnouncement,
        onReset: _resetFilters,
        onRefresh: () => _load(),
        onMaintenance: () => _runMaintenance(),
        onPublishAnnouncement: () => _publishAnnouncement(),
        onMarkAllRead: () => _markAllRead(),
        onMarkBatchRead: () => _markBatchRead(),
        batchReadCount: _selectedIds.length,
      ),
      filters: MessageCenterFilterSection(child: _buildFilterBar(theme)),
      banner: MessageCenterOverviewSection(
        unreadCount: _unreadCount,
        todoCount: _todoCount,
        urgentCount: _urgentCount,
        allCount: _allMessageCount,
      ),
      content: _buildBody(theme),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 36,
          child: TextField(
            key: const ValueKey('message-center-keyword-field'),
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
        _filterDropdown(
          '每页条数',
          '$_pageSize',
          const {'10': '10条', '20': '20条', '50': '50条', '100': '100条'},
          (v) {
            setState(() {
              _pageSize = int.tryParse(v) ?? 20;
              _page = 1;
            });
            _load(reset: false);
          },
        ),
      ],
    );
  }

  Widget _filterDropdown(
    String label,
    String current,
    Map<String, String> options,
    void Function(String) onChanged,
  ) {
    return DropdownButton<String>(
      key: ValueKey('message-center-filter-$label'),
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
      key: const ValueKey('message-center-date-range-button'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const stackedLayoutBreakpoint = 1100.0;
        final totalPages = _total == 0 ? 1 : (_total / _pageSize).ceil();
        final useStackedLayout = constraints.maxWidth < stackedLayoutBreakpoint;
        final list = MessageCenterListSection(
          loading: _loading,
          error: _error,
          isEmpty: _items.isEmpty,
          body: _buildMessageList(theme),
          page: _page,
          totalPages: totalPages,
          total: _total,
          onRetry: () => _load(),
          onPrevious: () {
            setState(() => _page -= 1);
            _load(reset: false);
          },
          onNext: () {
            setState(() => _page += 1);
            _load(reset: false);
          },
        );
        if (useStackedLayout) {
          return Column(
            key: const ValueKey('message-center-stacked-layout'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 11, child: list),
              const SizedBox(height: 16),
              Expanded(
                flex: 10,
                child: MessageCenterPreviewPanel(child: _buildPreview(theme)),
              ),
            ],
          );
        }
        return Row(
          key: const ValueKey('message-center-split-layout'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 15, child: list),
            const SizedBox(width: 16),
            Expanded(
              flex: 11,
              child: MessageCenterPreviewPanel(child: _buildPreview(theme)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    return ListView.separated(
      key: const ValueKey('message-center-list-scroll'),
      padding: const EdgeInsets.only(right: 4),
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildMessageTile(_items[index], theme),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final item = _selectedItem;
    final detail = _selectedDetail?.item.id == item?.id
        ? _selectedDetail
        : null;
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
    final fields = <MessageCenterDetailField>[
      MessageCenterDetailField(label: '标题', value: item.title),
      MessageCenterDetailField(label: '分类', value: item.messageTypeName),
      MessageCenterDetailField(label: '优先级', value: item.priorityName),
      if (item.summary != null && item.summary!.isNotEmpty)
        MessageCenterDetailField(label: '摘要', value: item.summary!),
      if (widget.canViewDetail &&
          detail?.item.content != null &&
          detail!.item.content!.isNotEmpty)
        MessageCenterDetailField(label: '正文', value: detail.item.content!),
      if (item.sourceModuleName.isNotEmpty)
        MessageCenterDetailField(label: '来源模块', value: item.sourceModuleName),
      if (detail?.sourceId != null && detail!.sourceId!.isNotEmpty)
        MessageCenterDetailField(label: '来源ID', value: detail.sourceId!),
      if (item.sourceCode != null && item.sourceCode!.isNotEmpty)
        MessageCenterDetailField(label: '来源对象', value: item.sourceCode!),
      if (item.publishedAt != null)
        MessageCenterDetailField(
          label: '推送时间',
          value: _formatDateTime(item.publishedAt!),
        ),
      MessageCenterDetailField(label: '消息状态', value: item.statusName),
      MessageCenterDetailField(label: '阅读状态', value: item.readStatusName),
      MessageCenterDetailField(label: '投递状态', value: item.deliveryStatusName),
      MessageCenterDetailField(
        label: '投递次数',
        value: '${item.deliveryAttemptCount}',
      ),
      if (item.lastPushAt != null)
        MessageCenterDetailField(
          label: '最近投递',
          value: _formatDateTime(item.lastPushAt!),
        ),
      if (item.nextRetryAt != null)
        MessageCenterDetailField(
          label: '下次重试',
          value: _formatDateTime(item.nextRetryAt!),
        ),
      if (item.readAt != null)
        MessageCenterDetailField(
          label: '已读时间',
          value: _formatDateTime(item.readAt!),
        ),
      if (detail?.failureReasonHint != null &&
          detail!.failureReasonHint!.isNotEmpty)
        MessageCenterDetailField(
          label: '排障提示',
          value: detail.failureReasonHint!,
        ),
      if (disabledReason != null)
        MessageCenterDetailField(label: '跳转状态', value: disabledReason),
      if (!widget.canViewDetail)
        const MessageCenterDetailField(label: '详情权限', value: '当前账号未开通消息详情查看权限'),
      if (!widget.canUseJump || widget.onNavigateToPage == null)
        const MessageCenterDetailField(label: '跳转权限', value: '当前账号未开通业务跳转权限'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildInfoChip(
              theme,
              item.priorityName,
              backgroundColor: item.priority == 'urgent'
                  ? theme.colorScheme.errorContainer
                  : item.priority == 'important'
                  ? Colors.orange.withAlpha(32)
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: item.priority == 'urgent'
                  ? theme.colorScheme.onErrorContainer
                  : item.priority == 'important'
                  ? Colors.orange.shade900
                  : theme.colorScheme.onSurfaceVariant,
            ),
            _buildInfoChip(
              theme,
              item.statusName,
              backgroundColor: item.isActive
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: item.isActive
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            _buildInfoChip(
              theme,
              item.readStatusName,
              backgroundColor: item.isRead
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.primaryContainer,
              foregroundColor: item.isRead
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
        const SizedBox(height: 16),
        MessageCenterDetailSections(fields: fields),
        const SizedBox(height: 16),
        if (_detailLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Row(
          children: [
            TextButton(
              key: ValueKey('message-center-preview-detail-${item.id}'),
              onPressed: widget.canViewDetail
                  ? () => _loadSelectedDetail(item.id)
                  : null,
              child: const Text('刷新详情'),
            ),
            const Spacer(),
            if (!item.isRead)
              TextButton(
                key: ValueKey('message-center-preview-read-${item.id}'),
                onPressed: () => _markRead(item),
                child: const Text('标记已读'),
              ),
            const SizedBox(width: 8),
            FilledButton(
              key: ValueKey('message-center-preview-jump-${item.id}'),
              onPressed:
                  item.isActive &&
                      widget.canUseJump &&
                      widget.onNavigateToPage != null
                  ? () async {
                      _markRead(item);
                      await _navigateToPage(item);
                    }
                  : null,
              child: const Text('跳转业务'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageTile(MessageItem item, ThemeData theme) {
    final hasTarget =
        item.isActive &&
        item.targetPageCode != null &&
        item.targetPageCode!.isNotEmpty;
    final readTimeText = item.readAt == null
        ? '未读'
        : '已读于 ${_formatDateTime(item.readAt!)}';
    final sourceText = item.sourceModuleName.isNotEmpty
        ? '来源：${item.sourceModuleName}'
        : item.sourceCode != null && item.sourceCode!.isNotEmpty
        ? '来源对象：${item.sourceCode!}'
        : '来源：系统消息';
    return MessageCenterMessageCard(
      item: item,
      selected: _selectedItem?.id == item.id,
      selectedForBatch: _selectedIds.contains(item.id),
      onTap: () => _selectItem(item),
      onToggleSelected: (selected) => _toggleSelected(item.id, selected),
      onShowDetail: () => _selectItem(item, silent: false),
      onMarkRead: () => _markRead(item),
      sourceText: sourceText,
      pushTimeText: item.publishedAt == null
          ? null
          : _formatDateTime(item.publishedAt!),
      readStatusText: readTimeText,
      canShowDetail: widget.canViewDetail,
      canJump:
          hasTarget && widget.canUseJump && widget.onNavigateToPage != null,
      onJump: () async {
        _markRead(item);
        await _navigateToPage(item);
      },
    );
  }

  Widget _buildInfoChip(
    ThemeData theme,
    String label, {
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
        _loadAllActiveUsers(),
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

  Future<UserListResult> _loadAllActiveUsers() async {
    const pageSize = 200;
    var page = 1;
    var total = 0;
    final items = <UserItem>[];
    while (true) {
      final result = await widget.userService.listUsers(
        page: page,
        pageSize: pageSize,
        isActive: true,
      );
      total = result.total;
      items.addAll(result.items);
      if (result.items.isEmpty) {
        break;
      }
      if (total > 0 && items.length >= total) {
        break;
      }
      page += 1;
    }
    return UserListResult(total: total, items: items);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '可选用户 ${_users.length} 人，已选择 ${_selectedUserIds.length} 人',
            ),
          ),
          Expanded(
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
          ),
        ],
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

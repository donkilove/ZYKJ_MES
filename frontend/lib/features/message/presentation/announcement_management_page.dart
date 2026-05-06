import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_action_dialogs.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';

class AnnouncementManagementPage extends StatefulWidget {
  const AnnouncementManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.service,
    this.userService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final MessageService? service;
  final UserService? userService;

  @override
  State<AnnouncementManagementPage> createState() =>
      _AnnouncementManagementPageState();
}

class _AnnouncementManagementPageState extends State<AnnouncementManagementPage> {
  static const int _pageSize = 20;

  late final MessageService _service;
  late final UserService _userService;

  bool _loading = false;
  String _message = '';
  int _page = 1;
  int _total = 0;
  List<MessageItem> _items = const [];

  int get _totalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _pageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MessageService(widget.session);
    _userService = widget.userService ?? UserService(widget.session);
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.getActiveAnnouncements(
        page: targetPage,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = result.page;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      setState(() => _message = error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _publishAnnouncement() async {
    final published = await showMessageCenterPublishDialog(
      context: context,
      userService: _userService,
      service: _service,
    );
    if (published && mounted) {
      await _loadAnnouncements(page: 1);
    }
  }

  Future<void> _offlineAnnouncement(MessageItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => MesActionDialog(
        title: const Text('确认下线公告'),
        content: Text('确认下线“${item.title}”吗？下线后将不再展示为当前生效公告。'),
        confirmLabel: '确认下线',
        isDestructive: true,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _service.offlineAnnouncement(item.id);
      if (!mounted) {
        return;
      }
      final fallbackPage = _page > 1 && _items.length == 1 ? _page - 1 : _page;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('公告“${item.title}”已下线')));
      await _loadAnnouncements(page: fallbackPage);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.statusCode == 401) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  String _priorityLabel(String value) {
    switch (value) {
      case 'urgent':
        return '紧急';
      case 'important':
        return '重要';
      default:
        return '普通';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MesCrudPageScaffold(
      header: MesPageHeader(
        title: '公告管理',
        subtitle: '管理当前生效公告并执行下线。',
        actions: [
          FilledButton.icon(
            onPressed: _loading ? null : _publishAnnouncement,
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('发布公告'),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _loadAnnouncements(page: _page),
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
          ),
        ],
      ),
      banner: _message.isEmpty
          ? null
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_message),
            ),
      content: _buildContent(context),
      pagination: MesPaginationBar(
        page: _page,
        totalPages: _totalPages,
        total: _total,
        loading: _loading,
        showTotal: false,
        onPrevious: () => _loadAnnouncements(page: _page - 1),
        onNext: () => _loadAnnouncements(page: _page + 1),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('当前没有生效中的公告'));
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      key: ValueKey('announcement-offline-${item.id}'),
                      onPressed: _loading ? null : () => _offlineAnnouncement(item),
                      child: const Text('下线'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.summary ?? item.content ?? '-'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text('优先级：${_priorityLabel(item.priority)}'),
                    Text('发布时间：${_formatDateTime(item.publishedAt)}'),
                    Text('过期时间：${_formatDateTime(item.expiresAt)}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

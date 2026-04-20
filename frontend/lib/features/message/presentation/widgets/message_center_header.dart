import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_toolbar.dart';

class MessageCenterHeader extends StatelessWidget {
  const MessageCenterHeader({
    super.key,
    required this.nowText,
    required this.errorText,
    required this.loading,
    required this.canPublishAnnouncement,
    required this.onReset,
    required this.onRefresh,
    required this.onMaintenance,
    required this.onPublishAnnouncement,
    required this.onMarkAllRead,
    required this.onMarkBatchRead,
    required this.batchReadCount,
  });

  final String nowText;
  final String errorText;
  final bool loading;
  final bool canPublishAnnouncement;
  final VoidCallback onReset;
  final VoidCallback onRefresh;
  final VoidCallback onMaintenance;
  final VoidCallback onPublishAnnouncement;
  final VoidCallback onMarkAllRead;
  final VoidCallback onMarkBatchRead;
  final int batchReadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MesPageHeader(title: '消息中心', subtitle: nowText),
        const SizedBox(height: 8),
        MesToolbar(
          leading: errorText.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  errorText,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
          trailing: [
            OutlinedButton.icon(
              onPressed: loading ? null : onReset,
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('重置'),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('刷新'),
            ),
            if (canPublishAnnouncement)
              OutlinedButton.icon(
                onPressed: loading ? null : onMaintenance,
                icon: const Icon(Icons.build_circle_outlined, size: 16),
                label: const Text('执行维护'),
              ),
            if (canPublishAnnouncement)
              FilledButton.icon(
                onPressed: loading ? null : onPublishAnnouncement,
                icon: const Icon(Icons.campaign_outlined, size: 16),
                label: const Text('发布公告'),
              ),
            FilledButton.icon(
              key: const ValueKey('message-center-mark-all-read-button'),
              onPressed: loading ? null : onMarkAllRead,
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('全部已读'),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('message-center-mark-batch-read-button'),
              onPressed: loading || batchReadCount == 0
                  ? null
                  : onMarkBatchRead,
              icon: const Icon(Icons.playlist_add_check, size: 16),
              label: Text(
                '批量已读${batchReadCount == 0 ? '' : '($batchReadCount)'}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

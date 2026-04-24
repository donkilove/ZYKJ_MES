import 'package:flutter/material.dart';

class MessageCenterActionBar extends StatelessWidget {
  const MessageCenterActionBar({
    super.key,
    required this.loading,
    required this.canPublishAnnouncement,
    required this.onRefresh,
    required this.onMaintenance,
    required this.onPublishAnnouncement,
    required this.onMarkAllRead,
    required this.onMarkBatchRead,
    required this.batchReadCount,
  });

  final bool loading;
  final bool canPublishAnnouncement;
  final VoidCallback onRefresh;
  final VoidCallback onMaintenance;
  final VoidCallback onPublishAnnouncement;
  final VoidCallback onMarkAllRead;
  final VoidCallback onMarkBatchRead;
  final int batchReadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('message-center-primary-actions'),
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _ActionGroup(
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('刷新'),
              ),
            ],
          ),
          if (canPublishAnnouncement)
            _ActionGroup(
              children: [
                OutlinedButton.icon(
                  onPressed: loading ? null : onMaintenance,
                  icon: const Icon(Icons.build_circle_outlined, size: 16),
                  label: const Text('执行维护'),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : onPublishAnnouncement,
                  icon: const Icon(Icons.campaign_outlined, size: 16),
                  label: const Text('发布公告'),
                ),
              ],
            ),
          _ActionGroup(
            children: [
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
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

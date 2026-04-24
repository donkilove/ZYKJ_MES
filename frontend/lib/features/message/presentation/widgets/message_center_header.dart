import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_action_bar.dart';

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
        if (errorText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.errorContainer),
            ),
            child: Text(
              errorText,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        ],
        MessageCenterActionBar(
          loading: loading,
          canPublishAnnouncement: canPublishAnnouncement,
          onReset: onReset,
          onRefresh: onRefresh,
          onMaintenance: onMaintenance,
          onPublishAnnouncement: onPublishAnnouncement,
          onMarkAllRead: onMarkAllRead,
          onMarkBatchRead: onMarkBatchRead,
          batchReadCount: batchReadCount,
        ),
      ],
    );
  }
}

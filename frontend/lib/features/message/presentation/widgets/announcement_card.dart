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

import 'package:flutter/material.dart';
import 'package:mes_client/features/message/models/message_models.dart';

class MessageCenterMessageCard extends StatelessWidget {
  const MessageCenterMessageCard({
    super.key,
    required this.item,
    required this.selected,
    required this.selectedForBatch,
    required this.onTap,
    required this.onToggleSelected,
    required this.onShowDetail,
    required this.onMarkRead,
    required this.sourceText,
    required this.pushTimeText,
    required this.readStatusText,
    required this.canShowDetail,
    required this.canJump,
    required this.onJump,
  });

  final MessageItem item;
  final bool selected;
  final bool selectedForBatch;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleSelected;
  final VoidCallback onShowDetail;
  final VoidCallback onMarkRead;
  final String sourceText;
  final String? pushTimeText;
  final String readStatusText;
  final bool canShowDetail;
  final bool canJump;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !item.isRead;
    final selectedColor = theme.colorScheme.primaryContainer.withAlpha(70);
    final unreadColor = theme.colorScheme.primaryContainer.withAlpha(34);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('message-center-tile-${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? selectedColor
                : isUnread
                ? unreadColor
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      label: item.priorityName,
                      backgroundColor: _priorityBackground(theme),
                      foregroundColor: _priorityForeground(theme),
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      label: item.statusName,
                      backgroundColor: item.isActive
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: item.isActive
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (item.summary == null || item.summary!.trim().isEmpty)
                      ? '暂无摘要'
                      : item.summary!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaText(text: sourceText),
                          if (pushTimeText != null) _MetaText(text: '推送：$pushTimeText'),
                          _MetaText(text: '阅读：$readStatusText'),
                          _MetaText(text: '分类：${item.messageTypeName}'),
                          _MetaText(text: '投递：${item.deliveryStatusName}'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Checkbox(
                          key: ValueKey('message-center-select-${item.id}'),
                          value: selectedForBatch,
                          onChanged: (value) => onToggleSelected(value ?? false),
                          visualDensity: VisualDensity.compact,
                        ),
                        TextButton(
                          key: ValueKey('message-center-detail-${item.id}'),
                          onPressed: canShowDetail ? onShowDetail : null,
                          style: _compactActionStyle(),
                          child: const Text('详情', style: TextStyle(fontSize: 12)),
                        ),
                        if (canJump)
                          TextButton(
                            key: ValueKey('message-center-jump-${item.id}'),
                            onPressed: onJump,
                            style: _compactActionStyle(),
                            child: const Text('跳转', style: TextStyle(fontSize: 12)),
                          ),
                        if (!item.isRead)
                          TextButton(
                            key: ValueKey('message-center-read-${item.id}'),
                            onPressed: onMarkRead,
                            style: _compactActionStyle(),
                            child: const Text('已读', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                ),
                if (!item.isActive) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.inactiveReasonName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _priorityBackground(ThemeData theme) {
    switch (item.priority) {
      case 'urgent':
        return theme.colorScheme.errorContainer;
      case 'important':
        return Colors.orange.withAlpha(32);
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  Color _priorityForeground(ThemeData theme) {
    switch (item.priority) {
      case 'urgent':
        return theme.colorScheme.onErrorContainer;
      case 'important':
        return Colors.orange.shade900;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  ButtonStyle _compactActionStyle() {
    return TextButton.styleFrom(
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

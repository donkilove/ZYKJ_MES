import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

class MessageCenterOverviewSection extends StatelessWidget {
  const MessageCenterOverviewSection({
    super.key,
    required this.unreadCount,
    required this.todoCount,
    required this.urgentCount,
    required this.allCount,
  });

  final int unreadCount;
  final int todoCount;
  final int urgentCount;
  final int allCount;

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final useCompactRow = viewportHeight < 760;
    final cards = [
      _CompactOverviewCard(
        label: '未读消息',
        value: '$unreadCount',
        compact: useCompactRow,
      ),
      _CompactOverviewCard(
        label: '待处理',
        value: '$todoCount',
        compact: useCompactRow,
      ),
      _CompactOverviewCard(
        label: '高优先级',
        value: '$urgentCount',
        compact: useCompactRow,
      ),
      _CompactOverviewCard(
        label: '全部消息',
        value: '$allCount',
        compact: useCompactRow,
      ),
    ];
    return MesSectionCard(
      title: '消息概览',
      child: useCompactRow
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    SizedBox(width: 156, child: cards[index]),
                  ],
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1200
                    ? 4
                    : constraints.maxWidth >= 760
                    ? 2
                    : 1;
                final spacing = 8.0;
                final rawWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final itemWidth = rawWidth.clamp(180.0, 220.0).toDouble();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: cards
                        .map((card) => SizedBox(width: itemWidth, child: card))
                        .toList(),
                  ),
                );
              },
            ),
    );
  }
}

class _CompactOverviewCard extends StatelessWidget {
  const _CompactOverviewCard({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesSurface(
      key: ValueKey('message-center-overview-card-$label'),
      tone: MesSurfaceTone.raised,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style:
                (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.0),
          ),
        ],
      ),
    );
  }
}

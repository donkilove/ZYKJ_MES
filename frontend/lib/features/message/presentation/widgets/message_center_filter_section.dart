import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class MessageCenterFilterSection extends StatelessWidget {
  const MessageCenterFilterSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commonChildren = <Widget>[];
    final secondaryChildren = <Widget>[];
    if (child case final Wrap wrapChild) {
      final children = wrapChild.children;
      final splitIndex = children.length >= 5 ? 5 : children.length;
      commonChildren.addAll(children.take(splitIndex));
      secondaryChildren.addAll(children.skip(splitIndex));
    } else {
      secondaryChildren.add(child);
    }

    return MesFilterBar(
      title: '常用筛选',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: commonChildren,
          ),
          if (secondaryChildren.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              key: const ValueKey('message-center-secondary-filters'),
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '辅助筛选',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                ...secondaryChildren,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

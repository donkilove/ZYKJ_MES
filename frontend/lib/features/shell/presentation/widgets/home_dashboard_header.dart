import 'package:flutter/material.dart';

import 'package:mes_client/core/models/current_user.dart';

class HomeDashboardHeader extends StatelessWidget {
  const HomeDashboardHeader({
    super.key,
    required this.currentUser,
    required this.noticeCount,
    required this.refreshing,
    required this.onRefresh,
    this.refreshStatusText,
  });

  final CurrentUser currentUser;
  final int noticeCount;
  final bool refreshing;
  final Future<void> Function() onRefresh;
  final String? refreshStatusText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <String>[
      if (currentUser.roleName?.trim().isNotEmpty == true)
        currentUser.roleName!,
      if (currentUser.stageName?.trim().isNotEmpty == true)
        currentUser.stageName!,
      '通知 ${noticeCount.toString()}',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '工作台',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '你好，${currentUser.displayName}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.9,
                    ),
                  ),
                ),
                if (refreshStatusText?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    refreshStatusText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          chip,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton.filledTonal(
            icon: refreshing
                ? const Icon(Icons.sync)
                : const Icon(Icons.refresh),
            onPressed: refreshing ? null : () => onRefresh(),
            tooltip: refreshing ? '刷新中' : '刷新业务数据',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class HomeDashboardHeader extends StatelessWidget {
  const HomeDashboardHeader({
    super.key,
    required this.currentUser,
    required this.noticeCount,
    required this.refreshing,
    required this.onRefresh,
  });

  final CurrentUser currentUser;
  final int noticeCount;
  final bool refreshing;
  final Future<void> Function() onRefresh;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MesPageHeader(
          title: '工作台',
          subtitle: '你好，${currentUser.displayName}',
          actions: [
            IconButton.filledTonal(
              icon: refreshing
                  ? const Icon(Icons.sync)
                  : const Icon(Icons.refresh),
              onPressed: refreshing ? null : () => onRefresh(),
              tooltip: refreshing ? '刷新中' : '刷新业务数据',
            ),
          ],
        ),
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
                  color: theme.colorScheme.secondaryContainer.withValues(
                    alpha: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chip,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

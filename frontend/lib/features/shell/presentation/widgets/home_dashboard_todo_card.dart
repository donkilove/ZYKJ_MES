import 'package:flutter/material.dart';

import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

class HomeDashboardTodoCard extends StatelessWidget {
  const HomeDashboardTodoCard({
    super.key,
    required this.todoSummary,
    required this.todoItems,
    required this.onNavigateToPage,
  });

  final HomeDashboardTodoSummary todoSummary;
  final List<HomeDashboardTodoItem> todoItems;
  final void Function(
    String pageCode, {
    String? tabCode,
    String? routePayloadJson,
  })
  onNavigateToPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleItems = todoItems.take(4).toList();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '我的待办队列',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  label: '待审批',
                  value: todoSummary.pendingApprovalCount,
                ),
                _SummaryChip(label: '高优', value: todoSummary.highPriorityCount),
                _SummaryChip(label: '异常', value: todoSummary.exceptionCount),
                _SummaryChip(label: '超时', value: todoSummary.overdueCount),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visibleItems.isEmpty
                  ? Center(
                      child: Text(
                        '当前没有待处理事项',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            '${item.categoryLabel} · ${item.priorityLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: item.targetPageCode == null
                              ? null
                              : () => onNavigateToPage(
                                  item.targetPageCode!,
                                  tabCode: item.targetTabCode,
                                  routePayloadJson: item.targetRoutePayloadJson,
                                ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onNavigateToPage(
                  'message',
                  tabCode: 'message_center',
                  routePayloadJson: '{"preset":"todo_only"}',
                ),
                child: const Text('查看全部待办'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label ${value.toString()}',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

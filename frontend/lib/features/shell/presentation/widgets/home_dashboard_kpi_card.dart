import 'package:flutter/material.dart';

import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

class HomeDashboardKpiCard extends StatelessWidget {
  const HomeDashboardKpiCard({
    super.key,
    required this.kpiItems,
    required this.onNavigateToPage,
  });

  final List<HomeDashboardMetricItem> kpiItems;
  final void Function(
    String pageCode, {
    String? tabCode,
    String? routePayloadJson,
  })
  onNavigateToPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleItems = kpiItems.take(4).toList();
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
              '次级业务指标',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visibleItems.isEmpty
                  ? Center(
                      child: Text(
                        '--',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.label),
                          trailing: Text(
                            item.value,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
          ],
        ),
      ),
    );
  }
}

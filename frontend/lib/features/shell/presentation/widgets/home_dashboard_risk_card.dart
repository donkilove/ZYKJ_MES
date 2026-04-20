import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

class HomeDashboardRiskCard extends StatelessWidget {
  const HomeDashboardRiskCard({
    super.key,
    required this.riskItems,
    required this.onNavigateToPage,
  });

  final List<HomeDashboardMetricItem> riskItems;
  final void Function(
    String pageCode, {
    String? tabCode,
    String? routePayloadJson,
  })
  onNavigateToPage;

  @override
  Widget build(BuildContext context) {
    final visibleItems = riskItems.take(4).toList();
    return MesSectionCard(
      title: '风险提醒',
      subtitle: '优先处理异常与高风险信号。',
      child: visibleItems.isEmpty
          ? const MesEmptyState(title: '当前没有风险提醒')
          : LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in visibleItems)
                      SizedBox(
                        width: itemWidth,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: item.targetPageCode == null
                              ? null
                              : () => onNavigateToPage(
                                  item.targetPageCode!,
                                  tabCode: item.targetTabCode,
                                  routePayloadJson: item.targetRoutePayloadJson,
                                ),
                          child: MesMetricCard(
                            label: item.label,
                            value: item.value,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
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
    final visibleItems = kpiItems.take(4).toList();
    return MesSectionCard(
      title: '关键指标',
      subtitle: '快速查看当前生产与质量表现。',
      child: visibleItems.isEmpty
          ? const MesEmptyState(title: '当前没有指标数据')
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

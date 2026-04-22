import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class QualityScrapStatisticsPageHeader extends StatelessWidget {
  const QualityScrapStatisticsPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('quality-scrap-statistics-page-header'),
      child: MesPageHeader(
        title: '报废统计',
        subtitle: '统一查看报废统计与筛选结果。',
      ),
    );
  }
}

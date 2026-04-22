import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class QualityDefectAnalysisPageHeader extends StatelessWidget {
  const QualityDefectAnalysisPageHeader({
    super.key,
    required this.loading,
    required this.canExport,
    required this.exporting,
    required this.onRefresh,
    required this.onExport,
  });

  final bool loading;
  final bool canExport;
  final bool exporting;
  final VoidCallback onRefresh;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('quality-defect-analysis-page-header'),
      child: MesPageHeader(
        title: '不良分析',
        subtitle: '统一查看缺陷分布与分析结果。',
        actions: [
          FilledButton.tonalIcon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新页面'),
          ),
          if (canExport)
            OutlinedButton.icon(
              onPressed: (loading || exporting) ? null : onExport,
              icon: const Icon(Icons.download),
              label: const Text('导出'),
            ),
        ],
      ),
    );
  }
}

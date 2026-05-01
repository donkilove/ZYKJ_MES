import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

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
      child: MesRefreshPageHeader(
        title: '不良分析',
        subtitle: '统一查看缺陷分布与分析结果。',
        onRefresh: loading ? null : onRefresh,
        actionsBeforeRefresh: [
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

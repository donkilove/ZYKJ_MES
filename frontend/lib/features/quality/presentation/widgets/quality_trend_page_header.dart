import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class QualityTrendPageHeader extends StatelessWidget {
  const QualityTrendPageHeader({
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
      key: const ValueKey('quality-trend-page-header'),
      child: MesRefreshPageHeader(
        title: '质量趋势',
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

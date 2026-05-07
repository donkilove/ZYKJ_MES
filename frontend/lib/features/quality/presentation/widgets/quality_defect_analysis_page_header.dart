import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class QualityDefectAnalysisPageHeader extends StatelessWidget {
  const QualityDefectAnalysisPageHeader({
    super.key,
    required this.loading,
    required this.keywordController,
    required this.canExport,
    required this.exporting,
    required this.startDateText,
    required this.endDateText,
    required this.onKeywordSubmitted,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onSearch,
    required this.onRefresh,
    required this.onExport,
  });

  final bool loading;
  final TextEditingController keywordController;
  final bool canExport;
  final bool exporting;
  final String startDateText;
  final String endDateText;
  final ValueChanged<String> onKeywordSubmitted;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('quality-defect-analysis-page-header'),
      child: MesRefreshPageHeader(
        leading: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: loading ? null : onPickStartDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(startDateText),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : onPickEndDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(endDateText),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                key: const ValueKey('quality-defect-keyword-field'),
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索工序/产品/操作员/不良类型',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: onKeywordSubmitted,
              ),
            ),
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('查询'),
            ),
          ],
        ),
        onRefresh: loading ? null : onRefresh,
        actionsBeforeRefresh: [
          if (canExport)
            PopupMenuButton<String>(
              key: const ValueKey('quality-defect-operation-menu'),
              tooltip: '操作',
              enabled: !loading && !exporting,
              onSelected: (value) {
                if (value == 'export') {
                  onExport();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(value: 'export', child: Text('导出')),
              ],
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class QualityDataPageHeader extends StatelessWidget {
  const QualityDataPageHeader({
    super.key,
    required this.loading,
    required this.startDateText,
    required this.endDateText,
    required this.keywordController,
    required this.resultFilter,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onKeywordSubmitted,
    required this.onResultChanged,
    required this.onSearch,
    required this.onRefresh,
    this.showExportButton = false,
    this.exporting = false,
    this.onExport,
  });

  final bool loading;
  final String startDateText;
  final String endDateText;
  final TextEditingController keywordController;
  final String? resultFilter;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final ValueChanged<String> onKeywordSubmitted;
  final ValueChanged<String?> onResultChanged;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final bool showExportButton;
  final bool exporting;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('quality-data-page-header'),
      child: MesRefreshPageHeader(
        leading: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: loading ? null : onPickStartDate,
              icon: const Icon(Icons.event),
              label: Text('开始：$startDateText'),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : onPickEndDate,
              icon: const Icon(Icons.event_available),
              label: Text('结束：$endDateText'),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                key: const ValueKey('quality-data-keyword-field'),
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索产品/工序/操作员',
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
            DropdownButton<String?>(
              value: resultFilter,
              hint: const Text('全部结果'),
              items: const [
                DropdownMenuItem(value: null, child: Text('全部结果')),
                DropdownMenuItem(value: 'passed', child: Text('合格')),
                DropdownMenuItem(value: 'failed', child: Text('不合格')),
              ],
              onChanged: loading ? null : onResultChanged,
            ),
          ],
        ),
        onRefresh: loading ? null : onRefresh,
        actionsBeforeRefresh: [
          if (showExportButton)
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

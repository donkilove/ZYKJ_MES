import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class QualityTrendPageHeader extends StatelessWidget {
  const QualityTrendPageHeader({
    super.key,
    required this.loading,
    required this.keywordController,
    required this.resultFilter,
    required this.canExport,
    required this.exporting,
    required this.startDateText,
    required this.endDateText,
    required this.onKeywordSubmitted,
    required this.onResultChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onSearch,
    required this.onRefresh,
    required this.onExport,
  });

  final bool loading;
  final TextEditingController keywordController;
  final String? resultFilter;
  final bool canExport;
  final bool exporting;
  final String startDateText;
  final String endDateText;
  final ValueChanged<String> onKeywordSubmitted;
  final ValueChanged<String?> onResultChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('quality-trend-page-header'),
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
                key: const ValueKey('quality-trend-keyword-field'),
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
          if (canExport)
            PopupMenuButton<String>(
              key: const ValueKey('quality-trend-operation-menu'),
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

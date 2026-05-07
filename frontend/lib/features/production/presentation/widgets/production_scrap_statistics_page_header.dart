import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class ProductionScrapStatisticsPageHeader extends StatelessWidget {
  const ProductionScrapStatisticsPageHeader({
    super.key,
    required this.loading,
    required this.keywordController,
    required this.progress,
    required this.startDateText,
    required this.endDateText,
    required this.canExport,
    required this.exporting,
    required this.onKeywordSubmitted,
    required this.onProgressChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onSearch,
    required this.onExport,
    required this.onRefresh,
  });

  final bool loading;
  final TextEditingController keywordController;
  final String progress;
  final String startDateText;
  final String endDateText;
  final bool canExport;
  final bool exporting;
  final ValueChanged<String> onKeywordSubmitted;
  final ValueChanged<String> onProgressChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onSearch;
  final VoidCallback onExport;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('production-scrap-statistics-page-header'),
      child: MesRefreshPageHeader(
        leading: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                key: const ValueKey('production-scrap-keyword-field'),
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索订单编号/报废原因/产品型号',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: onKeywordSubmitted,
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: progress,
                decoration: const InputDecoration(
                  labelText: '进度',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部')),
                  DropdownMenuItem(value: 'pending_apply', child: Text('待处理')),
                  DropdownMenuItem(value: 'applied', child: Text('已处理')),
                ],
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null) {
                          onProgressChanged(value);
                        }
                      },
              ),
            ),
            OutlinedButton(
              onPressed: loading ? null : onPickStartDate,
              child: Text(startDateText),
            ),
            OutlinedButton(
              onPressed: loading ? null : onPickEndDate,
              child: Text(endDateText),
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
              key: const ValueKey('production-scrap-statistics-operation-menu'),
              tooltip: '操作',
              onSelected: (value) {
                if (value == 'export') {
                  onExport();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(value: 'export', child: Text('导出')),
              ],
              enabled: !loading && !exporting,
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      ),
    );
  }
}

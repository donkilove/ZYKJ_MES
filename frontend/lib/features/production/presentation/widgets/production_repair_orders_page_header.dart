import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class ProductionRepairOrdersPageHeader extends StatelessWidget {
  const ProductionRepairOrdersPageHeader({
    super.key,
    required this.loading,
    required this.keywordController,
    required this.status,
    required this.startDateText,
    required this.endDateText,
    required this.canExport,
    required this.exporting,
    required this.onKeywordSubmitted,
    required this.onStatusChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onSearch,
    required this.onExport,
    required this.onRefresh,
  });

  final bool loading;
  final TextEditingController keywordController;
  final String status;
  final String startDateText;
  final String endDateText;
  final bool canExport;
  final bool exporting;
  final ValueChanged<String> onKeywordSubmitted;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onSearch;
  final VoidCallback onExport;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('production-repair-orders-page-header'),
      child: MesRefreshPageHeader(
        leading: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                key: const ValueKey('production-repair-keyword-field'),
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索维修单/订单/产品',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: onKeywordSubmitted,
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: '状态',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部')),
                  DropdownMenuItem(value: 'in_repair', child: Text('维修中')),
                  DropdownMenuItem(value: 'completed', child: Text('已完成')),
                ],
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null) {
                          onStatusChanged(value);
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
              key: const ValueKey('production-repair-orders-operation-menu'),
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

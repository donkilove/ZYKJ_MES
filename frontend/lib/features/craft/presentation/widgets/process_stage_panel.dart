import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

class ProcessStagePanel extends StatelessWidget {
  const ProcessStagePanel({
    super.key,
    required this.searchController,
    required this.items,
    required this.loading,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.canWrite,
    required this.onKeywordChanged,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onActionSelected,
  });

  final TextEditingController searchController;
  final List<CraftStageItem> items;
  final bool loading;
  final int page;
  final int totalPages;
  final int total;
  final bool canWrite;
  final ValueChanged<String> onKeywordChanged;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final void Function(StageAction action, CraftStageItem item) onActionSelected;

  Widget _buildSearchField() {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: searchController,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, size: 16),
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          hintText: '搜索工段',
        ),
        onChanged: onKeywordChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('process-stage-panel'),
      child: MesSectionCard(
        title: '工段列表',
        expandChild: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KeyedSubtree(
              key: const ValueKey('process-stage-filter-bar'),
              child: MesFilterBar(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [_buildSearchField()],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CrudListTableSection(
                loading: loading,
                isEmpty: items.isEmpty,
                emptyText: '当前筛选下暂无工段记录',
                loadingWidget: const MesLoadingState(label: '工段列表加载中...'),
                emptyWidget: const MesEmptyState(title: '当前筛选下暂无工段记录'),
                enableUnifiedHeaderStyle: true,
                child: DataTable(
                  showCheckboxColumn: false,
                  columns: [
                    UnifiedListTableHeaderStyle.column(context, '工段编码'),
                    UnifiedListTableHeaderStyle.column(context, '工段名称'),
                    UnifiedListTableHeaderStyle.column(context, '备注'),
                    UnifiedListTableHeaderStyle.column(context, '排序'),
                    UnifiedListTableHeaderStyle.column(context, '状态'),
                    UnifiedListTableHeaderStyle.column(context, '关联工序数'),
                    UnifiedListTableHeaderStyle.column(context, '创建时间'),
                    UnifiedListTableHeaderStyle.column(
                      context,
                      '操作',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  rows: items.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item.code)),
                        DataCell(Text(item.name)),
                        DataCell(Text(item.remark.isEmpty ? '-' : item.remark)),
                        DataCell(Text('${item.sortOrder}')),
                        DataCell(Text(item.isEnabled ? '启用' : '停用')),
                        DataCell(Text('${item.processCount}')),
                        DataCell(
                          Text(
                            '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                        DataCell(
                          UnifiedListTableHeaderStyle.actionMenuButton<StageAction>(
                            theme: theme,
                            onSelected: (action) => onActionSelected(action, item),
                            itemBuilder: (context) {
                              final items = <PopupMenuEntry<StageAction>>[
                                const PopupMenuItem(
                                  value: StageAction.viewReference,
                                  child: Text('查看引用'),
                                ),
                              ];
                              if (canWrite) {
                                items.addAll(const [
                                  PopupMenuItem(
                                    value: StageAction.edit,
                                    child: Text('编辑'),
                                  ),
                                  PopupMenuItem(
                                    value: StageAction.toggle,
                                    child: Text('启用/停用'),
                                  ),
                                  PopupMenuItem(
                                    value: StageAction.delete,
                                    child: Text('删除'),
                                  ),
                                ]);
                              }
                              return items;
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            MesPaginationBar(
              page: page,
              totalPages: totalPages,
              total: total,
              loading: loading,
              onPrevious: onPreviousPage,
              onNext: onNextPage,
            ),
          ],
        ),
      ),
    );
  }
}

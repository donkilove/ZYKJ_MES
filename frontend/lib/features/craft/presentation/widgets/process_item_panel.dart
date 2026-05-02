import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

class ProcessItemPanel extends StatelessWidget {
  const ProcessItemPanel({
    super.key,
    required this.searchController,
    required this.stageFilter,
    required this.stageOptions,
    required this.items,
    required this.loading,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.focusedProcessId,
    required this.canWrite,
    required this.onKeywordChanged,
    required this.onStageFilterChanged,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onFocusProcess,
    required this.onActionSelected,
  });

  final TextEditingController searchController;
  final int? stageFilter;
  final List<CraftStageItem> stageOptions;
  final List<CraftProcessItem> items;
  final bool loading;
  final int page;
  final int totalPages;
  final int total;
  final int? focusedProcessId;
  final bool canWrite;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<int?> onStageFilterChanged;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onFocusProcess;
  final void Function(ProcessAction action, CraftProcessItem item)
  onActionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('process-item-panel'),
      child: MesSectionCard(
        title: '工序列表',
        expandChild: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MesFilterBar(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 16),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        hintText: '搜索工序',
                      ),
                      onChanged: onKeywordChanged,
                    ),
                  ),
                  DropdownButton<int?>(
                    value: stageFilter,
                    isDense: true,
                    hint: const Text('全部工段'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('全部工段'),
                      ),
                      ...stageOptions.map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: onStageFilterChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CrudListTableSection(
                loading: loading,
                isEmpty: items.isEmpty,
                emptyText: '当前筛选下暂无工序记录',
                loadingWidget: const MesLoadingState(label: '工序列表加载中...'),
                emptyWidget: const MesEmptyState(title: '当前筛选下暂无工序记录'),
                enableUnifiedHeaderStyle: true,
                child: DataTable(
                  showCheckboxColumn: false,
                  columns: [
                    UnifiedListTableHeaderStyle.column(context, '所属工段'),
                    UnifiedListTableHeaderStyle.column(context, '工序编码'),
                    UnifiedListTableHeaderStyle.column(context, '工序名称'),
                    UnifiedListTableHeaderStyle.column(context, '备注'),
                    UnifiedListTableHeaderStyle.column(context, '状态'),
                    UnifiedListTableHeaderStyle.column(context, '创建时间'),
                    UnifiedListTableHeaderStyle.column(
                      context,
                      '操作',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  rows: items.map((item) {
                    final isFocused = item.id == focusedProcessId;
                    return DataRow(
                      color: isFocused
                          ? WidgetStatePropertyAll<Color?>(
                              theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.28,
                              ),
                            )
                          : null,
                      cells: [
                        DataCell(Text(item.stageName ?? '-')),
                        DataCell(Text(item.code)),
                        DataCell(Text(item.name)),
                        DataCell(Text(item.remark.isEmpty ? '-' : item.remark)),
                        DataCell(Text(item.isEnabled ? '启用' : '停用')),
                        DataCell(
                          Text(
                            '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                        DataCell(
                          UnifiedListTableHeaderStyle.actionMenuButton<ProcessAction>(
                            theme: theme,
                            onSelected: (action) => onActionSelected(action, item),
                            itemBuilder: (context) {
                              final items = <PopupMenuEntry<ProcessAction>>[
                                const PopupMenuItem(
                                  value: ProcessAction.viewReference,
                                  child: Text('查看引用'),
                                ),
                              ];
                              if (canWrite) {
                                items.addAll(const [
                                  PopupMenuItem(
                                    value: ProcessAction.edit,
                                    child: Text('编辑'),
                                  ),
                                  PopupMenuItem(
                                    value: ProcessAction.toggle,
                                    child: Text('启用/停用'),
                                  ),
                                  PopupMenuItem(
                                    value: ProcessAction.delete,
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

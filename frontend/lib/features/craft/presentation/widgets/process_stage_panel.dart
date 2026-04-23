import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

class ProcessStagePanel extends StatelessWidget {
  const ProcessStagePanel({
    super.key,
    required this.searchController,
    required this.items,
    required this.canWrite,
    required this.onKeywordChanged,
    required this.onActionSelected,
  });

  final TextEditingController searchController;
  final List<CraftStageItem> items;
  final bool canWrite;
  final ValueChanged<String> onKeywordChanged;
  final void Function(StageAction action, CraftStageItem item) onActionSelected;

  Widget _buildHeaderLabel(
    ThemeData theme,
    String text, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildCellText(
    String text, {
    TextAlign textAlign = TextAlign.start,
    TextStyle? style,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }

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

  Widget _buildHeaderRow(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '工段编码')),
          Expanded(flex: 2, child: _buildHeaderLabel(theme, '工段名称')),
          Expanded(flex: 2, child: _buildHeaderLabel(theme, '备注')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '排序')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '状态')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '关联工序数')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '创建时间')),
          SizedBox(
            width: 64,
            child: _buildHeaderLabel(theme, '操作', textAlign: TextAlign.center),
          ),
        ],
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('工段列表', style: theme.textTheme.titleMedium),
                _buildSearchField(),
              ],
            ),
            const SizedBox(height: 8),
            _buildHeaderRow(theme),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('暂无工段'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 1, child: _buildCellText(item.code)),
                              Expanded(flex: 2, child: _buildCellText(item.name)),
                              Expanded(
                                flex: 2,
                                child: _buildCellText(
                                  item.remark.isEmpty ? '-' : item.remark,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: _buildCellText('${item.sortOrder}'),
                              ),
                              Expanded(
                                flex: 1,
                                child: _buildCellText(item.isEnabled ? '启用' : '停用'),
                              ),
                              Expanded(
                                flex: 1,
                                child: _buildCellText('${item.processCount}'),
                              ),
                              Expanded(
                                flex: 1,
                                child: _buildCellText(
                                  '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              SizedBox(
                                width: 64,
                                child:
                                    UnifiedListTableHeaderStyle.actionMenuButton<StageAction>(
                                      theme: theme,
                                      onSelected: (action) =>
                                          onActionSelected(action, item),
                                      itemBuilder: (context) {
                                        final items =
                                            <PopupMenuEntry<StageAction>>[
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

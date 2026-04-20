import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/adaptive_table_container.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/product/models/product_models.dart';

enum ProductParameterManagementListAction { view, edit, history, export }

class ProductParameterVersionTableSection extends StatelessWidget {
  const ProductParameterVersionTableSection({
    super.key,
    required this.rows,
    required this.loading,
    required this.emptyText,
    required this.formatTime,
    required this.buildActionItems,
    required this.onSelected,
  });

  final List<ProductParameterVersionListItem> rows;
  final bool loading;
  final String emptyText;
  final String Function(DateTime value) formatTime;
  final List<PopupMenuEntry<ProductParameterManagementListAction>> Function(
    ProductParameterVersionListItem row,
  )
  buildActionItems;
  final void Function(
    ProductParameterManagementListAction action,
    ProductParameterVersionListItem row,
  )
  onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('product-parameter-version-table-section'),
      child: CrudListTableSection(
        loading: loading,
        isEmpty: rows.isEmpty,
        emptyText: emptyText,
        enableUnifiedHeaderStyle: true,
        child: AdaptiveTableContainer(
          child: UnifiedListTableHeaderStyle.wrap(
            theme: theme,
            child: DataTable(
              columns: [
                UnifiedListTableHeaderStyle.column(context, '产品名称'),
                UnifiedListTableHeaderStyle.column(context, '产品分类'),
                UnifiedListTableHeaderStyle.column(context, '版本标签/版本号'),
                UnifiedListTableHeaderStyle.column(context, '创建时间'),
                UnifiedListTableHeaderStyle.column(context, '版本状态'),
                UnifiedListTableHeaderStyle.column(
                  context,
                  '操作',
                  textAlign: TextAlign.center,
                ),
              ],
              rows: rows.map((row) {
                return DataRow(
                  cells: [
                    DataCell(Text(row.productName)),
                    DataCell(
                      Text(row.productCategory.isEmpty ? '-' : row.productCategory),
                    ),
                    DataCell(Text('${row.versionLabel} / #${row.version}')),
                    DataCell(Text(formatTime(row.createdAt))),
                    DataCell(
                      Text(
                        [
                          _lifecycleLabel(row.lifecycleStatus),
                          if (row.isCurrentVersion) '当前版本',
                          if (row.isEffectiveVersion) '生效版本',
                        ].join(' / '),
                      ),
                    ),
                    DataCell(
                      UnifiedListTableHeaderStyle.actionMenuButton<
                          ProductParameterManagementListAction>(
                        theme: theme,
                        onSelected: (action) => onSelected(action, row),
                        itemBuilder: (context) => buildActionItems(row),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

String _lifecycleLabel(String value) {
  switch (value) {
    case 'draft':
      return '草稿';
    case 'effective':
      return '已生效';
    case 'obsolete':
      return '已失效';
    case 'disabled':
      return '已停用';
    default:
      return value.isEmpty ? '-' : value;
  }
}

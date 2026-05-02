import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductParameterQueryTableSection extends StatelessWidget {
  const ProductParameterQueryTableSection({
    super.key,
    required this.products,
    required this.loading,
    required this.emptyText,
    required this.formatTime,
    required this.onViewParameters,
  });

  final List<ProductItem> products;
  final bool loading;
  final String emptyText;
  final String Function(DateTime value) formatTime;
  final ValueChanged<ProductItem> onViewParameters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('product-parameter-query-table-section'),
      child: CrudListTableSection(
        loading: loading,
        isEmpty: products.isEmpty,
        emptyText: emptyText,
        enableUnifiedHeaderStyle: true,
        child: DataTable(
          columns: [
            UnifiedListTableHeaderStyle.column(context, '产品名称'),
            UnifiedListTableHeaderStyle.column(context, '产品分类'),
            UnifiedListTableHeaderStyle.column(context, '生效版本'),
            UnifiedListTableHeaderStyle.column(context, '当前状态'),
            UnifiedListTableHeaderStyle.column(context, '创建时间'),
            UnifiedListTableHeaderStyle.column(
              context,
              '操作',
              textAlign: TextAlign.center,
            ),
          ],
          rows: products.map((product) {
            return DataRow(
              cells: [
                DataCell(Text(product.name)),
                DataCell(Text(product.category.isEmpty ? '-' : product.category)),
                DataCell(
                  Text(
                    product.effectiveVersionLabel ??
                        (product.effectiveVersion > 0
                            ? 'V1.${product.effectiveVersion - 1}'
                            : '-'),
                  ),
                ),
                DataCell(Text(_lifecycleLabel(product.lifecycleStatus))),
                DataCell(Text(formatTime(product.createdAt))),
                DataCell(
                  UnifiedListTableHeaderStyle.cellContent(
                    TextButton(
                      onPressed: () => onViewParameters(product),
                      child: const Text('查看参数'),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

String _lifecycleLabel(String value) {
  switch (value) {
    case 'active':
    case 'effective':
      return '启用';
    case 'inactive':
      return '停用';
    default:
      return value.isEmpty ? '-' : value;
  }
}

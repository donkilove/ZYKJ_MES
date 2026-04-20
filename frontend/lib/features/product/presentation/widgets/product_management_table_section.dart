import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_status_chip.dart';

enum ProductManagementTableAction {
  viewDetail,
  edit,
  deactivate,
  reactivate,
  version,
  viewParams,
  editParams,
  delete,
}

class ProductManagementTableSection extends StatelessWidget {
  const ProductManagementTableSection({
    super.key,
    required this.products,
    required this.loading,
    required this.emptyText,
    required this.formatTime,
    required this.buildActionItems,
    required this.onSelected,
  });

  final List<ProductItem> products;
  final bool loading;
  final String emptyText;
  final String Function(DateTime value) formatTime;
  final List<PopupMenuEntry<ProductManagementTableAction>> Function(
    ProductItem product,
  )
  buildActionItems;
  final void Function(ProductManagementTableAction action, ProductItem product)
  onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('product-management-table-section'),
      child: CrudListTableSection(
        loading: loading,
        isEmpty: products.isEmpty,
        emptyText: emptyText,
        enableUnifiedHeaderStyle: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              UnifiedListTableHeaderStyle.column(context, '产品名称'),
              UnifiedListTableHeaderStyle.column(context, '产品分类'),
              UnifiedListTableHeaderStyle.column(context, '状态'),
              UnifiedListTableHeaderStyle.column(context, '当前版本'),
              UnifiedListTableHeaderStyle.column(context, '生效版本'),
              UnifiedListTableHeaderStyle.column(context, '创建时间'),
              UnifiedListTableHeaderStyle.column(context, '更新时间'),
              UnifiedListTableHeaderStyle.column(
                context,
                '操作',
                textAlign: TextAlign.center,
              ),
            ],
            rows: products.map((product) {
              final actions = buildActionItems(product);
              return DataRow(
                cells: [
                  DataCell(Text(product.name)),
                  DataCell(Text(product.category)),
                  DataCell(
                    ProductManagementStatusChip(
                      lifecycleStatus: product.lifecycleStatus,
                    ),
                  ),
                  DataCell(Text('V1.${product.currentVersion - 1}')),
                  DataCell(
                    Text(
                      product.effectiveVersion > 0
                          ? 'V1.${product.effectiveVersion - 1}'
                          : '-',
                    ),
                  ),
                  DataCell(Text(formatTime(product.createdAt))),
                  DataCell(Text(formatTime(product.updatedAt))),
                  DataCell(
                    actions.isEmpty
                        ? const Text('-')
                        : UnifiedListTableHeaderStyle.actionMenuButton<
                            ProductManagementTableAction
                          >(
                            theme: theme,
                            onSelected: (action) => onSelected(action, product),
                            itemBuilder: (context) => actions,
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

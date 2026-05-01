import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_summary_header.dart';

class ProductParameterQueryDialog extends StatelessWidget {
  const ProductParameterQueryDialog({
    super.key,
    required this.result,
    required this.buildParameterValueCell,
    required this.onClose,
  });

  final ProductParameterListResult result;
  final Widget Function(ProductParameterItem item) buildParameterValueCell;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-query-dialog'),
      child: MesDialog(
        title: Text('产品参数 - ${result.productName}'),
        width: 1000,
        content: SizedBox(
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductParameterSummaryHeader(
                productName: result.productName,
                versionLabel: result.versionLabel,
                parameterCount: result.total,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: CrudListTableSection(
                  loading: false,
                  isEmpty: result.items.isEmpty,
                  emptyText: '该产品暂无参数',
                  enableUnifiedHeaderStyle: true,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('参数名称')),
                      DataColumn(label: Text('参数分类')),
                      DataColumn(label: Text('参数类型')),
                      DataColumn(label: Text('参数值')),
                      DataColumn(label: Text('参数说明')),
                    ],
                    rows: result.items.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text(item.name)),
                          DataCell(Text(item.category)),
                          DataCell(Text(item.type)),
                          DataCell(buildParameterValueCell(item)),
                          DataCell(
                            Text(
                              item.description.isEmpty ? '-' : item.description,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [FilledButton(onPressed: onClose, child: const Text('关闭'))],
      ),
    );
  }
}

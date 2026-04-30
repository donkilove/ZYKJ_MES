import 'package:flutter/material.dart';

import 'package:mes_client/core/widgets/adaptive_table_container.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

Future<void> showProductionFirstArticleParametersDialog({
  required BuildContext context,
  required FirstArticleParameterListResult result,
}) {
  return showMesLockedFormDialog<void>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionFirstArticleParametersDialog(result: result);
    },
  );
}

class ProductionFirstArticleParametersDialog extends StatelessWidget {
  const ProductionFirstArticleParametersDialog({
    super.key,
    required this.result,
  });

  final FirstArticleParameterListResult result;

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: const Text('首件参数查看'),
      width: 760,
      content: SizedBox(
        key: const ValueKey('production-first-article-parameters-dialog'),
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('产品：${result.productName}'),
            Text('参数范围：${result.parameterScope}'),
            Text('版本：${result.versionLabel}'),
            Text('生命周期：${result.lifecycleStatus}'),
            const SizedBox(height: 12),
            Flexible(
              child: result.items.isEmpty
                  ? const Center(child: Text('暂无参数'))
                  : AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('名称')),
                          DataColumn(label: Text('分类')),
                          DataColumn(label: Text('类型')),
                          DataColumn(label: Text('值')),
                          DataColumn(label: Text('说明')),
                        ],
                        rows: result.items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.name)),
                              DataCell(Text(item.category)),
                              DataCell(Text(item.type)),
                              DataCell(Text(item.value)),
                              DataCell(Text(item.description)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

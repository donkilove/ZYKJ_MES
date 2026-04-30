import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_dialog.dart';

Future<void> showProductParameterUnavailableDialog({
  required BuildContext context,
  required String productName,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return MesDialog(
        title: Text('产品参数 - $productName'),
        width: 420,
        content: const Text('该产品暂无生效版本，无法查看参数。\n请先在产品管理中激活一个版本。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}

Future<void> showProductParameterResultDialog({
  required BuildContext context,
  required ProductParameterListResult result,
  required Widget Function(ProductParameterItem item) buildParameterValueCell,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return ProductParameterQueryDialog(
        result: result,
        buildParameterValueCell: buildParameterValueCell,
        onClose: () => Navigator.of(context).pop(),
      );
    },
  );
}

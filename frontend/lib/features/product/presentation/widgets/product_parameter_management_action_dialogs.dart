import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_history_dialog.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_history_snapshot_dialog.dart';

Future<void> showProductParameterHistoryFlowDialog({
  required BuildContext context,
  required ProductParameterVersionListItem row,
  required ProductParameterHistoryListResult history,
  required String Function(DateTime value) formatTime,
  required String Function(String value) historyTypeLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return ProductParameterHistoryDialog(
        row: row,
        history: history,
        formatTime: formatTime,
        historyTypeLabel: historyTypeLabel,
        onClose: () => Navigator.of(context).pop(),
        onViewSnapshot: (item) {
          showDialog<void>(
            context: context,
            builder: (snapshotContext) {
              return ProductParameterHistorySnapshotDialog(
                item: item,
                onClose: () => Navigator.of(snapshotContext).pop(),
              );
            },
          );
        },
      );
    },
  );
}

Future<bool> showProductParameterDiscardDialog({
  required BuildContext context,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return MesActionDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('当前编辑内容尚未保存，离开后将丢失本次修改。'),
        cancelLabel: '继续编辑',
        confirmLabel: '放弃修改',
        isDestructive: true,
        onConfirm: () => Navigator.of(context).pop(true),
      );
    },
  );
  return confirmed ?? false;
}

Future<bool> showProductParameterImpactDialog({
  required BuildContext context,
  required ProductImpactAnalysisResult impact,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return MesActionDialog(
        title: const Text('变更影响确认'),
        width: 520,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '存在 ${impact.totalOrders} 条未完工订单（待开工 ${impact.pendingOrders}，生产中 ${impact.inProgressOrders}）。',
            ),
            const SizedBox(height: 8),
            const Text('确认后将按强制模式继续保存。'),
          ],
        ),
        confirmLabel: '确认继续',
        onConfirm: () => Navigator.of(context).pop(true),
      );
    },
  );
  return confirmed ?? false;
}

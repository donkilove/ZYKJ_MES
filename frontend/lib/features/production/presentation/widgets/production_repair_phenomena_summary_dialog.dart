import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionRepairPhenomenaSummaryDialog extends StatelessWidget {
  const ProductionRepairPhenomenaSummaryDialog({
    super.key,
    required this.repairOrderCode,
    required this.items,
  });

  final String repairOrderCode;
  final List<RepairOrderPhenomenonSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: Text('现象汇总 - $repairOrderCode'),
      width: 460,
      content: SizedBox(
        key: const ValueKey('production-repair-phenomena-summary-dialog'),
        width: 460,
        child: items.isEmpty
            ? const Text('暂无现象明细')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: items
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.phenomenon)),
                            Text('数量：${entry.quantity}'),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

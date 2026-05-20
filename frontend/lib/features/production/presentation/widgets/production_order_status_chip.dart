import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionOrderStatusChip extends StatelessWidget {
  const ProductionOrderStatusChip({
    super.key,
    required this.status,
    this.label,
  });

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel =
        label != null && label!.trim().isNotEmpty
            ? label!.trim()
            : productionOrderStatusLabel(status);
    switch (status) {
      case 'pending':
        return MesStatusChip.warning(label: resolvedLabel);
      case 'in_progress':
        return MesStatusChip.success(label: resolvedLabel);
      case 'completed':
      case 'done':
        return MesStatusChip.success(label: resolvedLabel);
      default:
        return MesStatusChip.warning(label: resolvedLabel);
    }
  }
}

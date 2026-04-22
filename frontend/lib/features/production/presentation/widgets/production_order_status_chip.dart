import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionOrderStatusChip extends StatelessWidget {
  const ProductionOrderStatusChip({
    super.key,
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = productionOrderStatusLabel(status);
    switch (status) {
      case 'pending':
        return MesStatusChip.warning(label: label);
      case 'in_progress':
        return MesStatusChip.success(label: label);
      case 'completed':
        return MesStatusChip.success(label: label);
      default:
        return MesStatusChip.warning(label: label);
    }
  }
}

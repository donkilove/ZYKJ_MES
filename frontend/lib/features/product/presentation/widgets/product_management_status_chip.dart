import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';

class ProductManagementStatusChip extends StatelessWidget {
  const ProductManagementStatusChip({
    super.key,
    required this.lifecycleStatus,
  });

  final String lifecycleStatus;

  @override
  Widget build(BuildContext context) {
    switch (lifecycleStatus) {
      case 'active':
      case 'effective':
        return MesStatusChip.success(label: '启用');
      case 'inactive':
        return MesStatusChip.warning(label: '停用');
      case 'draft':
        return MesStatusChip.warning(label: '草稿');
      case 'pending_review':
        return MesStatusChip.warning(label: '待审核');
      case 'obsolete':
        return MesStatusChip.warning(label: '已废弃');
      default:
        return MesStatusChip.warning(label: lifecycleStatus);
    }
  }
}

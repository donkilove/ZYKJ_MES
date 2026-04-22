import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class QualitySupplierManagementPageHeader extends StatelessWidget {
  const QualitySupplierManagementPageHeader({
    super.key,
    required this.total,
    required this.loading,
    required this.onRefresh,
    required this.onCreate,
  });

  final int total;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('quality-supplier-management-page-header'),
      child: MesPageHeader(
        title: '供应商管理',
        subtitle: '统一管理质量供应商与状态。当前共 $total 条。',
        actions: [
          FilledButton.tonalIcon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新页面'),
          ),
          FilledButton.icon(
            onPressed: loading ? null : onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新增供应商'),
          ),
        ],
      ),
    );
  }
}

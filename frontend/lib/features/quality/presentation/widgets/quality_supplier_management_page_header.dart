import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class QualitySupplierManagementPageHeader extends StatelessWidget {
  const QualitySupplierManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
    required this.onCreate,
  });

  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('quality-supplier-management-page-header'),
      child: MesRefreshPageHeader(
        title: '供应商管理',
        onRefresh: loading ? null : onRefresh,
        actionsBeforeRefresh: [
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

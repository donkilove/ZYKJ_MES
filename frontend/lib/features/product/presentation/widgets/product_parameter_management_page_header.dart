import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductParameterManagementPageHeader extends StatelessWidget {
  const ProductParameterManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '版本参数管理',
      subtitle: '按版本查看、编辑和导出产品参数。',
      actions: [
        FilledButton.tonalIcon(
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新页面'),
        ),
      ],
    );
  }
}

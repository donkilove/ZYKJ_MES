import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductVersionPageHeader extends StatelessWidget {
  const ProductVersionPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '版本管理',
      subtitle: '左侧选择产品，右侧查看版本工作区与参数动作。',
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

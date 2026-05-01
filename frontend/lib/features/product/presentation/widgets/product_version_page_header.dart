import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

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
    return KeyedSubtree(
      key: const ValueKey('product-version-page-header'),
      child: MesRefreshPageHeader(
        title: '版本管理',
        subtitle: '左侧选择产品，右侧查看版本工作区与参数动作。',
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}

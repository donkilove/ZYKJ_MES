import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class ProductManagementPageHeader extends StatelessWidget {
  const ProductManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-management-page-header'),
      child: MesRefreshPageHeader(
        title: '产品管理',
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}

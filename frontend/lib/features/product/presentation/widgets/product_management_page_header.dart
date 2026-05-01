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
        subtitle: '统一管理产品筛选、列表、详情和版本工作区入口。',
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class ProductParameterQueryPageHeader extends StatelessWidget {
  const ProductParameterQueryPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-query-page-header'),
      child: MesRefreshPageHeader(
        title: '产品参数查询',
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}

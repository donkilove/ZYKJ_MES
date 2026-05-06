import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class ProductionDataPageHeader extends StatelessWidget {
  const ProductionDataPageHeader({
    super.key,
    required this.title,
    required this.loading,
    required this.onRefresh,
  });

  final String title;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('production-data-page-header'),
      child: MesRefreshPageHeader(
        title: title,
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}

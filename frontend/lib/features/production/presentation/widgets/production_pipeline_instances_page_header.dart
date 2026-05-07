import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class ProductionPipelineInstancesPageHeader extends StatelessWidget {
  const ProductionPipelineInstancesPageHeader({
    super.key,
    required this.loading,
    required this.leading,
    required this.onRefresh,
  });

  final bool loading;
  final Widget leading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('production-pipeline-instances-page-header'),
      child: MesRefreshPageHeader(
        leading: leading,
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}

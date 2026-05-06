import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class MaintenanceRecordPageHeader extends StatelessWidget {
  const MaintenanceRecordPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('maintenance-record-page-header'),
      child: MesRefreshPageHeader(onRefresh: loading ? null : onRefresh),
    );
  }
}

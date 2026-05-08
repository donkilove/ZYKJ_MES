import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class MaintenancePlanPageHeader extends StatelessWidget {
  const MaintenancePlanPageHeader({
    super.key,
    required this.loading,
    required this.leading,
    required this.onRefresh,
    this.actionsBeforeRefresh = const <Widget>[],
  });

  final bool loading;
  final Widget leading;
  final VoidCallback onRefresh;
  final List<Widget> actionsBeforeRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('maintenance-plan-page-header'),
      child: MesRefreshPageHeader(
        leading: leading,
        onRefresh: loading ? null : onRefresh,
        actionsBeforeRefresh: actionsBeforeRefresh,
      ),
    );
  }
}

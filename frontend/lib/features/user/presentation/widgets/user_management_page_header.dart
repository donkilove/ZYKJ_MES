import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class UserManagementPageHeader extends StatelessWidget {
  const UserManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
    this.actionsBeforeRefresh = const <Widget>[],
  });

  final bool loading;
  final VoidCallback onRefresh;
  final List<Widget> actionsBeforeRefresh;

  @override
  Widget build(BuildContext context) {
    return MesRefreshPageHeader(
      title: '用户管理',
      onRefresh: loading ? null : onRefresh,
      actionsBeforeRefresh: actionsBeforeRefresh,
    );
  }
}

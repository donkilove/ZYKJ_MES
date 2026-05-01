import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class RoleManagementPageHeader extends StatelessWidget {
  const RoleManagementPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
  });

  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('role-management-page-header'),
      child: MesRefreshPageHeader(
        title: '角色管理',
        subtitle: '统一管理角色、启停与删除动作。',
        onRefresh: loading ? null : onRefresh,
      ),
    );
  }
}

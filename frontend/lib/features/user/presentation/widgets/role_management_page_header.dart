import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class RoleManagementPageHeader extends StatelessWidget {
  const RoleManagementPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
    this.canCreateRole = false,
    this.onCreateRole,
  });

  final VoidCallback onRefresh;
  final bool loading;
  final bool canCreateRole;
  final VoidCallback? onCreateRole;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('role-management-page-header'),
      child: MesRefreshPageHeader(
        title: '角色管理',
        onRefresh: loading ? null : onRefresh,
        actionsBeforeRefresh: [
          if (canCreateRole && onCreateRole != null)
            FilledButton(
              onPressed: onCreateRole,
              child: const Text('新增角色'),
            ),
        ],
      ),
    );
  }
}

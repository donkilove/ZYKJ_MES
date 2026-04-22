import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

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
      child: MesPageHeader(
        title: '角色管理',
        subtitle: '统一管理角色、启停与删除动作。',
        actions: [
          FilledButton.tonalIcon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新页面'),
          ),
        ],
      ),
    );
  }
}

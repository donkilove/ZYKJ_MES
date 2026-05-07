import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class RoleManagementPageHeader extends StatelessWidget {
  const RoleManagementPageHeader({
    super.key,
    required this.onRefresh,
    required this.loading,
    required this.keywordController,
    required this.onSearch,
    this.canCreateRole = false,
    this.onCreateRole,
  });

  final VoidCallback onRefresh;
  final bool loading;
  final TextEditingController keywordController;
  final VoidCallback onSearch;
  final bool canCreateRole;
  final VoidCallback? onCreateRole;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('role-management-page-header'),
      child: MesRefreshPageHeader(
        onRefresh: loading ? null : onRefresh,
        actionsBeforeRefresh: [
          if (canCreateRole && onCreateRole != null)
            PopupMenuButton<String>(
              key: const ValueKey('role-management-operation-menu'),
              tooltip: '操作',
              onSelected: loading
                  ? null
                  : (value) {
                      if (value == 'create_role') {
                        onCreateRole?.call();
                      }
                    },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'create_role',
                  child: Text('新增角色'),
                ),
              ],
              icon: const Icon(Icons.more_horiz),
            ),
        ],
        leading: Row(
          children: [
            Expanded(
              child: TextField(
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '关键词',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: loading ? null : onSearch,
              child: const Text('查询'),
            ),
          ],
        ),
      ),
    );
  }
}

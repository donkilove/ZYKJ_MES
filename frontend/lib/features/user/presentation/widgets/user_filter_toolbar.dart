import 'package:flutter/material.dart';
import 'package:mes_client/features/user/models/user_models.dart';

class UserFilterToolbar extends StatelessWidget {
  final TextEditingController keywordController;
  final String? filterRoleCode;
  final bool? filterIsActive;
  final String deletedScope;
  final List<RoleItem> roles;

  final ValueChanged<String?> onFilterRoleCodeChanged;
  final ValueChanged<bool?> onFilterIsActiveChanged;
  final ValueChanged<String> onFilterDeletedScopeChanged;
  final VoidCallback onSearch;

  final List<Widget> actions;

  const UserFilterToolbar({
    super.key,
    required this.keywordController,
    required this.filterRoleCode,
    required this.filterIsActive,
    required this.deletedScope,
    required this.roles,
    required this.onFilterRoleCodeChanged,
    required this.onFilterIsActiveChanged,
    required this.onFilterDeletedScopeChanged,
    required this.onSearch,
    required this.actions,
  });

  Widget _buildKeywordField() {
    return TextField(
      key: const ValueKey('userToolbarKeywordField'),
      controller: keywordController,
      decoration: const InputDecoration(
        labelText: '按账号搜索',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => onSearch(),
    );
  }

  Widget _buildRoleFilter() {
    return DropdownButtonFormField<String?>(
      key: const ValueKey('userToolbarRoleFilter'),
      initialValue: filterRoleCode,
      decoration: const InputDecoration(
        labelText: '用户角色',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      items: [
        const DropdownMenuItem(value: null, child: Text('全部')),
        ...roles.map(
          (role) => DropdownMenuItem(
            value: role.code,
            child: Text(role.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onFilterRoleCodeChanged,
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<bool?>(
      key: const ValueKey('userToolbarStatusFilter'),
      initialValue: filterIsActive,
      decoration: const InputDecoration(
        labelText: '账号状态',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: true, child: Text('启用')),
        DropdownMenuItem(value: false, child: Text('停用')),
      ],
      onChanged: onFilterIsActiveChanged,
    );
  }

  Widget _buildDeletedScopeFilter() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('userToolbarDeletedScopeFilter'),
      initialValue: deletedScope,
      decoration: const InputDecoration(
        labelText: '数据范围',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      items: const [
        DropdownMenuItem(value: 'active', child: Text('常规用户')),
        DropdownMenuItem(value: 'deleted', child: Text('仅已删除')),
        DropdownMenuItem(value: 'all', child: Text('全部用户')),
      ],
      onChanged: (value) {
        if (value != null) onFilterDeletedScopeChanged(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;
    const roleWidth = 150.0;
    const statusWidth = 130.0;
    const deletedScopeWidth = 150.0;
    const desktopSearchMinWidth = 320.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final roleFilter = SizedBox(
          width: roleWidth,
          child: _buildRoleFilter(),
        );
        final statusFilter = SizedBox(
          width: statusWidth,
          child: _buildStatusFilter(),
        );
        final deletedScopeFilter = SizedBox(
          width: deletedScopeWidth,
          child: _buildDeletedScopeFilter(),
        );
        final desktopToolbarMinWidth =
            roleWidth +
            statusWidth +
            deletedScopeWidth +
            desktopSearchMinWidth +
            (actions.length * 120) +
            ((actions.length + 4) * spacing);

        if (constraints.maxWidth >= desktopToolbarMinWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildKeywordField()),
              const SizedBox(width: spacing),
              statusFilter,
              const SizedBox(width: spacing),
              roleFilter,
              const SizedBox(width: spacing),
              deletedScopeFilter,
              const SizedBox(width: spacing),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: spacing,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
              ),
            ],
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 280, child: _buildKeywordField()),
            statusFilter,
            roleFilter,
            deletedScopeFilter,
            ...actions,
          ],
        );
      },
    );
  }
}

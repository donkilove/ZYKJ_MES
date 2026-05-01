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
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    const searchWidth = 240.0;
    const statusWidth = 136.0;
    const roleWidth = 150.0;
    const deletedScopeWidth = 136.0;
    const twoRowLayoutMinWidth = 1100.0;

    final searchField = SizedBox(
      width: searchWidth,
      child: _buildKeywordField(),
    );
    final statusFilter = SizedBox(
      width: statusWidth,
      child: _buildStatusFilter(),
    );
    final roleFilter = SizedBox(width: roleWidth, child: _buildRoleFilter());
    final deletedScopeFilter = SizedBox(
      width: deletedScopeWidth,
      child: _buildDeletedScopeFilter(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < twoRowLayoutMinWidth) {
          return Wrap(
            spacing: spacing,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              searchField,
              statusFilter,
              roleFilter,
              deletedScopeFilter,
              ...actions,
            ],
          );
        }

        final topRowButtons = Wrap(
          spacing: spacing,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );
        final topRow = Wrap(
          spacing: spacing,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [statusFilter, roleFilter, deletedScopeFilter],
        );
        final bottomRow = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            searchField,
            const SizedBox(width: spacing),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: topRowButtons,
              ),
            ),
          ],
        );

        return ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topRow,
              const SizedBox(height: spacing),
              bottomRow,
            ],
          ),
        );
      },
    );
  }
}

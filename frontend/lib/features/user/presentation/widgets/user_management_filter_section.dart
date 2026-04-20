import 'package:flutter/material.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_filter_panel.dart';
import 'package:mes_client/features/user/presentation/widgets/user_filter_toolbar.dart';

class UserManagementFilterSection extends StatelessWidget {
  const UserManagementFilterSection({
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

  @override
  Widget build(BuildContext context) {
    return UserModuleFilterPanel(
      sectionKey: const ValueKey('user-management-filter-section'),
      child: UserFilterToolbar(
        keywordController: keywordController,
        filterRoleCode: filterRoleCode,
        filterIsActive: filterIsActive,
        deletedScope: deletedScope,
        roles: roles,
        onFilterRoleCodeChanged: onFilterRoleCodeChanged,
        onFilterIsActiveChanged: onFilterIsActiveChanged,
        onFilterDeletedScopeChanged: onFilterDeletedScopeChanged,
        onSearch: onSearch,
        actions: actions,
      ),
    );
  }
}

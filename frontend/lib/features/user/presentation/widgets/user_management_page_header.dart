import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/widgets/user_filter_toolbar.dart';

class UserManagementPageHeader extends StatelessWidget {
  const UserManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
    required this.keywordController,
    required this.filterRoleCode,
    required this.filterIsActive,
    required this.deletedScope,
    required this.roles,
    required this.onFilterRoleCodeChanged,
    required this.onFilterIsActiveChanged,
    required this.onFilterDeletedScopeChanged,
    required this.onSearch,
    this.actionsBeforeRefresh = const <Widget>[],
    this.topActions = const <Widget>[],
  });

  final bool loading;
  final VoidCallback onRefresh;
  final TextEditingController keywordController;
  final String? filterRoleCode;
  final bool? filterIsActive;
  final String deletedScope;
  final List<RoleItem> roles;
  final ValueChanged<String?> onFilterRoleCodeChanged;
  final ValueChanged<bool?> onFilterIsActiveChanged;
  final ValueChanged<String> onFilterDeletedScopeChanged;
  final VoidCallback onSearch;
  final List<Widget> actionsBeforeRefresh;
  final List<Widget> topActions;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('user-management-page-header'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return MesRefreshPageHeader(
            onRefresh: loading ? null : onRefresh,
            leading: KeyedSubtree(
              key: const ValueKey('user-management-filter-section'),
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
                actions: const <Widget>[],
                topActions: topActions,
                forceSingleRow: constraints.maxWidth >= 1200,
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
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

  Widget _buildRefreshButton() {
    return Tooltip(
      message: '刷新',
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('user-management-page-header'),
      child: SizedBox(
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final toolbar = KeyedSubtree(
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
                topActions: [...topActions, _buildRefreshButton()],
                forceSingleRow: constraints.maxWidth >= 1200,
              ),
            );

            if (constraints.maxWidth >= 1200) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (actionsBeforeRefresh.isNotEmpty) ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actionsBeforeRefresh,
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(child: toolbar),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (actionsBeforeRefresh.isNotEmpty)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actionsBeforeRefresh,
                  ),
                if (actionsBeforeRefresh.isNotEmpty) const SizedBox(height: 16),
                toolbar,
              ],
            );
          },
        ),
      ),
    );
  }
}

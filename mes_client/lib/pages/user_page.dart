import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import 'function_permission_config_page.dart';
import 'registration_approval_page.dart';
import 'user_management_page.dart';

const List<String> _defaultTabOrder = [
  'user_management',
  'registration_approval',
  'function_permission_config',
];

class UserPage extends StatefulWidget {
  const UserPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
    required this.capabilityCodes,
    this.onVisibilityConfigSaved,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;
  final Set<String> capabilityCodes;
  final VoidCallback? onVisibilityConfigSaved;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  bool _hasPermission(String code) => widget.capabilityCodes.contains(code);

  bool get _canManageUsers =>
      _hasPermission(UserFeaturePermissionCodes.userManagementManage);

  bool get _canReviewAction =>
      _hasPermission(UserFeaturePermissionCodes.registrationApprovalReview);

  List<String> _sortedVisibleTabCodes() {
    final visibleSet = widget.visibleTabCodes.toSet()
      ..remove('page_visibility_config');
    final ordered = <String>[];

    for (final code in _defaultTabOrder) {
      if (visibleSet.remove(code)) {
        ordered.add(code);
      }
    }

    final remaining = visibleSet.toList()..sort();
    ordered.addAll(remaining);
    return ordered;
  }

  List<_UserTabItem> _buildTabs() {
    final tabs = <_UserTabItem>[];
    for (final code in _sortedVisibleTabCodes()) {
      switch (code) {
        case 'user_management':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '用户管理',
              child: UserManagementPage(
                session: widget.session,
                onLogout: widget.onLogout,
                canWrite: _canManageUsers,
              ),
            ),
          );
          break;
        case 'registration_approval':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '注册审批',
              child: RegistrationApprovalPage(
                session: widget.session,
                onLogout: widget.onLogout,
                canReviewAction: _canReviewAction,
              ),
            ),
          );
          break;
        case 'function_permission_config':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '功能权限配置',
              child: FunctionPermissionConfigPage(
                session: widget.session,
                onLogout: widget.onLogout,
                onPermissionsChanged: widget.onVisibilityConfigSaved == null
                    ? null
                    : () async {
                        widget.onVisibilityConfigSaved!();
                      },
              ),
            ),
          );
          break;
      }
    }
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _buildTabs();
    if (tabs.isEmpty) {
      return const Center(child: Text('当前账号没有可访问的用户模块页面。'));
    }

    return Column(
      children: [
        Expanded(
          child: DefaultTabController(
            key: ValueKey(tabs.map((item) => item.code).join('|')),
            length: tabs.length,
            child: Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: TabBar(
                    tabs: tabs.map((item) => Tab(text: item.title)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: tabs.map((item) => item.child).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UserTabItem {
  const _UserTabItem({
    required this.code,
    required this.title,
    required this.child,
  });

  final String code;
  final String title;
  final Widget child;
}

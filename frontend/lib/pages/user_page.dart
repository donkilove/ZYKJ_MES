import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import 'account_settings_page.dart';
import 'audit_log_page.dart';
import 'function_permission_config_page.dart';
import 'login_session_page.dart';
import 'registration_approval_page.dart';
import 'role_management_page.dart';
import 'user_management_page.dart';

const List<String> _defaultTabOrder = [
  'user_management',
  'registration_approval',
  'role_management',
  'audit_log',
  'account_settings',
  'login_session',
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
  int _currentTabIndex = 0;

  bool _hasPermission(String code) => widget.capabilityCodes.contains(code);

  bool get _canManageUsers =>
      _hasPermission(UserFeaturePermissionCodes.userManagementManage);

  bool get _canReviewAction =>
      _hasPermission(UserFeaturePermissionCodes.registrationApprovalReview);

  bool get _canManageRoles =>
      _hasPermission(UserFeaturePermissionCodes.roleManagementManage);

  bool get _canChangeMyPassword =>
      _hasPermission(UserFeaturePermissionCodes.accountSettingsManage);

  bool get _canViewMySession =>
      _hasPermission(UserFeaturePermissionCodes.accountSettingsView);

  bool get _canManageSessions =>
      _hasPermission(UserFeaturePermissionCodes.loginSessionManage);

  List<String> _sortedVisibleTabCodes() {
    final visibleSet = widget.visibleTabCodes.toSet();
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
    final sortedCodes = _sortedVisibleTabCodes();
    for (final code in sortedCodes) {
      switch (code) {
        case 'user_management':
          final roleManagementIndex = sortedCodes.indexOf('role_management');
          tabs.add(
            _UserTabItem(
              code: code,
              title: '用户管理',
              child: UserManagementPage(
                session: widget.session,
                onLogout: widget.onLogout,
                canWrite: _canManageUsers,
                onNavigateToRoleManagement: roleManagementIndex >= 0
                    ? () {
                        setState(() => _currentTabIndex = roleManagementIndex);
                      }
                    : null,
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
        case 'role_management':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '角色管理',
              child: RoleManagementPage(
                session: widget.session,
                onLogout: widget.onLogout,
                canManage: _canManageRoles,
              ),
            ),
          );
          break;
        case 'audit_log':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '审计日志',
              child: AuditLogPage(
                session: widget.session,
                onLogout: widget.onLogout,
              ),
            ),
          );
          break;
        case 'account_settings':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '个人中心',
              child: AccountSettingsPage(
                session: widget.session,
                onLogout: widget.onLogout,
                canChangePassword: _canChangeMyPassword,
                canViewSession: _canViewMySession,
              ),
            ),
          );
          break;
        case 'login_session':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '登录会话',
              child: LoginSessionPage(
                session: widget.session,
                onLogout: widget.onLogout,
                canManage: _canManageSessions,
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
      return const Center(child: Text('当前账号没有可访问的用户模块页面'));
    }

    return Column(
      children: [
        Expanded(
          child: DefaultTabController(
            key: ValueKey(tabs.map((item) => item.code).join('|')),
            length: tabs.length,
            initialIndex: _currentTabIndex.clamp(0, tabs.length - 1),
            child: Builder(
              builder: (context) {
                final tabController = DefaultTabController.of(context);
                tabController.addListener(() {
                  if (!tabController.indexIsChanging) {
                    _currentTabIndex = tabController.index;
                  }
                });
                if (_currentTabIndex != tabController.index &&
                    _currentTabIndex >= 0 &&
                    _currentTabIndex < tabs.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (tabController.index != _currentTabIndex) {
                      tabController.animateTo(_currentTabIndex);
                    }
                  });
                }
                return Column(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: TabBar(
                        isScrollable: false,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelPadding: EdgeInsets.zero,
                        tabs: tabs
                            .map(
                              (item) => Tab(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: tabs.map((item) => item.child).toList(),
                      ),
                    ),
                  ],
                );
              },
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

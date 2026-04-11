import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/features/user/presentation/account_settings_page.dart';
import 'package:mes_client/features/user/presentation/audit_log_page.dart';
import 'package:mes_client/features/user/presentation/function_permission_config_page.dart';
import 'package:mes_client/features/user/presentation/login_session_page.dart';
import 'package:mes_client/features/user/presentation/registration_approval_page.dart';
import 'package:mes_client/features/user/presentation/role_management_page.dart';
import 'package:mes_client/features/user/presentation/user_management_page.dart';

const List<String> _defaultTabOrder = [
  'user_management',
  'registration_approval',
  'role_management',
  'audit_log',
  'account_settings',
  'login_session',
  'function_permission_config',
];

const String _accountSettingsTabCode = 'account_settings';

class UserPage extends StatefulWidget {
  const UserPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
    required this.capabilityCodes,
    this.preferredTabCode,
    this.routePayloadJson,
    this.onVisibilityConfigSaved,
    this.tabChildBuilder,
    this.tabPageBuilder,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;
  final Set<String> capabilityCodes;
  final String? preferredTabCode;
  final String? routePayloadJson;
  final VoidCallback? onVisibilityConfigSaved;
  final Widget Function(String tabCode)? tabChildBuilder;
  final Widget Function(String tabCode, Widget child)? tabPageBuilder;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  int _currentTabIndex = 0;
  TabController? _tabController;

  String _tabSemanticsLabel(_UserTabItem item) => '${item.title}页签';

  @override
  void didUpdateWidget(covariant UserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preferredTabCode != oldWidget.preferredTabCode) {
      final tabs = _buildTabs();
      final preferredIndex = tabs.indexWhere(
        (item) => item.code == widget.preferredTabCode,
      );
      if (preferredIndex >= 0) {
        setState(() => _currentTabIndex = preferredIndex);
      }
    }
  }

  bool _hasPermission(String code) => widget.capabilityCodes.contains(code);

  bool get _canCreateUser =>
      _hasPermission(UserFeaturePermissionCodes.userManagementCreate);

  bool get _canEditUser =>
      _hasPermission(UserFeaturePermissionCodes.userManagementUpdate);

  bool get _canToggleUser =>
      _hasPermission(UserFeaturePermissionCodes.userManagementLifecycle);

  bool get _canResetUserPassword =>
      _hasPermission(UserFeaturePermissionCodes.userManagementPasswordReset);

  bool get _canDeleteUser =>
      _hasPermission(UserFeaturePermissionCodes.userManagementDelete);

  bool get _canRestoreUser =>
      _hasPermission(UserFeaturePermissionCodes.userManagementRestore);

  bool get _canExportUsers =>
      _hasPermission(UserFeaturePermissionCodes.userManagementExport);

  bool get _canApproveRegistration =>
      _hasPermission(UserFeaturePermissionCodes.registrationApprovalApprove);

  bool get _canRejectRegistration =>
      _hasPermission(UserFeaturePermissionCodes.registrationApprovalReject);

  bool get _canCreateRole =>
      _hasPermission(UserFeaturePermissionCodes.roleManagementCreate);

  bool get _canEditRole =>
      _hasPermission(UserFeaturePermissionCodes.roleManagementUpdate);

  bool get _canToggleRole =>
      _hasPermission(UserFeaturePermissionCodes.roleManagementLifecycle);

  bool get _canDeleteRole =>
      _hasPermission(UserFeaturePermissionCodes.roleManagementDelete);

  bool get _canChangeMyPassword => true;

  bool get _canViewMySession => true;

  bool get _canViewOnlineSessions =>
      _hasPermission(UserFeaturePermissionCodes.loginSessionOnlineView);

  bool get _canManageSessions =>
      _canViewOnlineSessions &&
      _hasPermission(UserFeaturePermissionCodes.loginSessionForceOffline);

  Widget _buildTabChild(String code, Widget child) {
    final overridden = widget.tabPageBuilder?.call(code, child);
    if (overridden != null) {
      return overridden;
    }
    return widget.tabChildBuilder?.call(code) ?? child;
  }

  List<String> _sortedVisibleTabCodes() {
    final visibleSet = widget.visibleTabCodes.toSet();
    visibleSet.add(_accountSettingsTabCode);
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
      final currentIndex = tabs.length;
      switch (code) {
        case 'user_management':
          final roleManagementIndex = sortedCodes.indexOf('role_management');
          final isVisible = _currentTabIndex == currentIndex;
          tabs.add(
            _UserTabItem(
              code: code,
              title: '用户管理',
              child: _buildTabChild(
                code,
                LegacyLegacyUserManagementPage(
                  session: widget.session,
                  onLogout: widget.onLogout,
                  canCreateUser: _canCreateUser,
                  canEditUser: _canEditUser,
                  canToggleUser: _canToggleUser,
                  canResetPassword: _canResetUserPassword,
                  canDeleteUser: _canDeleteUser,
                  canRestoreUser: _canRestoreUser,
                  canExport: _canExportUsers,
                  onNavigateToRoleManagement: roleManagementIndex >= 0
                      ? () {
                          _tabController?.animateTo(roleManagementIndex);
                          setState(
                            () => _currentTabIndex = roleManagementIndex,
                          );
                        }
                      : null,
                  isCurrentTabVisible: isVisible,
                ),
              ),
            ),
          );
          break;
        case 'registration_approval':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '注册审批',
              child: _buildTabChild(
                code,
                RegistrationApprovalPage(
                  session: widget.session,
                  onLogout: widget.onLogout,
                  canApprove: _canApproveRegistration,
                  canReject: _canRejectRegistration,
                  routePayloadJson:
                      widget.preferredTabCode == 'registration_approval'
                      ? widget.routePayloadJson
                      : null,
                ),
              ),
            ),
          );
          break;
        case 'role_management':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '角色管理',
              child: _buildTabChild(
                code,
                RoleManagementPage(
                  session: widget.session,
                  onLogout: widget.onLogout,
                  canCreateRole: _canCreateRole,
                  canEditRole: _canEditRole,
                  canToggleRole: _canToggleRole,
                  canDeleteRole: _canDeleteRole,
                ),
              ),
            ),
          );
          break;
        case 'audit_log':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '审计日志',
              child: _buildTabChild(
                code,
                AuditLogPage(
                  session: widget.session,
                  onLogout: widget.onLogout,
                ),
              ),
            ),
          );
          break;
        case 'account_settings':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '个人中心',
              child: _buildTabChild(
                code,
                AccountSettingsPage(
                  session: widget.session,
                  onLogout: widget.onLogout,
                  canChangePassword: _canChangeMyPassword,
                  canViewSession: _canViewMySession,
                  routePayloadJson:
                      widget.preferredTabCode == _accountSettingsTabCode
                      ? widget.routePayloadJson
                      : null,
                ),
              ),
            ),
          );
          break;
        case 'login_session':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '登录会话',
              child: _buildTabChild(
                code,
                LoginSessionPage(
                  session: widget.session,
                  onLogout: widget.onLogout,
                  canViewOnlineSessions: _canViewOnlineSessions,
                  canForceOffline: _canManageSessions,
                ),
              ),
            ),
          );
          break;
        case 'function_permission_config':
          tabs.add(
            _UserTabItem(
              code: code,
              title: '功能权限配置',
              child: _buildTabChild(
                code,
                FunctionPermissionConfigPage(
                  session: widget.session,
                  onLogout: widget.onLogout,
                  onPermissionsChanged: widget.onVisibilityConfigSaved == null
                      ? null
                      : () async {
                          widget.onVisibilityConfigSaved!();
                        },
                ),
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
    final preferredIndex = tabs.indexWhere(
      (item) => item.code == widget.preferredTabCode,
    );
    if (preferredIndex >= 0 && preferredIndex != _currentTabIndex) {
      _currentTabIndex = preferredIndex;
    }

    return Column(
      children: [
        Expanded(
          child: DefaultTabController(
            key: ValueKey(
              '${tabs.map((item) => item.code).join('|')}|$_currentTabIndex',
            ),
            length: tabs.length,
            initialIndex: _currentTabIndex.clamp(0, tabs.length - 1),
            child: Builder(
              builder: (context) {
                final tabController = DefaultTabController.of(context);
                _tabController = tabController;
                tabController.addListener(() {
                  if (!tabController.indexIsChanging &&
                      _currentTabIndex != tabController.index) {
                    setState(() => _currentTabIndex = tabController.index);
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
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Semantics(
                        container: true,
                        label: '用户模块页签栏',
                        child: TabBar(
                          isScrollable: false,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelPadding: EdgeInsets.zero,
                          tabs: tabs
                              .map(
                                (item) => Tab(
                                  child: Semantics(
                                    container: true,
                                    label: _tabSemanticsLabel(item),
                                    button: true,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelMedium,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
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

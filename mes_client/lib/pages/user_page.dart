import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/authz_models.dart';
import '../services/authz_service.dart';
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
    this.onVisibilityConfigSaved,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;
  final VoidCallback? onVisibilityConfigSaved;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late final AuthzService _authzService;
  Set<String> _permissionCodes = const <String>{};
  bool _loadingPermissions = true;
  String _permissionMessage = '';

  @override
  void initState() {
    super.initState();
    _authzService = AuthzService(widget.session);
    _loadPermissions();
  }

  @override
  void didUpdateWidget(covariant UserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.accessToken != widget.session.accessToken) {
      _loadPermissions();
    }
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _loadingPermissions = true;
      _permissionMessage = '';
    });
    try {
      final codes = await _authzService.getMyPermissionCodes(
        moduleCode: 'user',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _permissionCodes = codes.toSet();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _permissionCodes = const <String>{};
        _permissionMessage = '加载用户模块权限失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPermissions = false;
        });
      }
    }
  }

  bool _hasPermission(String code) => _permissionCodes.contains(code);

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
    if (_loadingPermissions) {
      return const Center(child: CircularProgressIndicator());
    }
    final tabs = _buildTabs();
    if (tabs.isEmpty) {
      return const Center(child: Text('当前账号没有可访问的用户模块页面。'));
    }

    return Column(
      children: [
        if (_permissionMessage.isNotEmpty)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(_permissionMessage),
          ),
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

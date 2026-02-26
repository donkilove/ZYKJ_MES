import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/current_user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'user_management_page.dart';

enum _ShellPageKey {
  home,
  userManagement,
}

class _ShellMenuItem {
  const _ShellMenuItem({
    required this.key,
    required this.title,
    required this.icon,
  });

  final _ShellPageKey key;
  final String title;
  final IconData icon;
}

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  final AuthService _authService = AuthService();

  bool _loading = true;
  String _message = '';
  CurrentUser? _currentUser;
  List<_ShellMenuItem> _menus = const [];
  _ShellPageKey _selectedPage = _ShellPageKey.home;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  List<_ShellMenuItem> _buildMenus(CurrentUser user) {
    final permissionSet = user.permissionCodes.toSet();
    final items = <_ShellMenuItem>[
      const _ShellMenuItem(
        key: _ShellPageKey.home,
        title: '首页',
        icon: Icons.home_rounded,
      ),
    ];
    if (permissionSet.contains('user:read')) {
      items.add(
        const _ShellMenuItem(
          key: _ShellPageKey.userManagement,
          title: '用户管理',
          icon: Icons.group_rounded,
        ),
      );
    }
    return items;
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final currentUser = await _authService.getCurrentUser(
        baseUrl: widget.session.baseUrl,
        accessToken: widget.session.accessToken,
      );
      final menus = _buildMenus(currentUser);

      if (!mounted) {
        return;
      }
      setState(() {
        _currentUser = currentUser;
        _menus = menus;
        _selectedPage = menus.isEmpty ? _ShellPageKey.home : menus.first.key;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载当前用户信息失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildContent(_ShellPageKey key) {
    switch (key) {
      case _ShellPageKey.home:
        return HomePage(currentUser: _currentUser!);
      case _ShellPageKey.userManagement:
        return UserManagementPage(
          session: widget.session,
          onLogout: widget.onLogout,
        );
    }
  }

  Widget _buildNoAccessPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 40),
                const SizedBox(height: 12),
                const Text('当前账号没有可访问页面'),
                const SizedBox(height: 8),
                const Text('请联系系统管理员分配角色或权限。'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loadCurrentUser,
                        child: const Text('刷新权限'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.onLogout,
                        child: const Text('退出登录'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                Text(_message),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onLogout,
                        child: const Text('退出登录'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _loadCurrentUser,
                        child: const Text('重试'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Scaffold(body: _buildErrorPage());
    }

    if (_menus.isEmpty) {
      return Scaffold(body: _buildNoAccessPage());
    }

    final selectedIndex = _menus.indexWhere((menu) => menu.key == _selectedPage);
    final safeSelectedIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final selectedMenuKey = _menus[safeSelectedIndex].key;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
            color: theme.colorScheme.surfaceContainerHighest,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZYKJ MES',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser!.displayName,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _menus.length,
                      itemBuilder: (context, index) {
                        final menu = _menus[index];
                        final selected = menu.key == selectedMenuKey;
                        return ListTile(
                          selected: selected,
                          leading: Icon(menu.icon),
                          title: Text(menu.title),
                          onTap: () {
                            if (_selectedPage == menu.key) {
                              return;
                            }
                            setState(() {
                              _selectedPage = menu.key;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('退出登录'),
                    onTap: widget.onLogout,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SafeArea(
              child: IndexedStack(
                index: safeSelectedIndex,
                children: _menus.map((menu) => _buildContent(menu.key)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

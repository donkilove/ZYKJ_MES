import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/current_user.dart';
import '../models/page_visibility_models.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/page_visibility_service.dart';
import 'equipment_page.dart';
import 'home_page.dart';
import 'product_page.dart';
import 'user_page.dart';

const String _homePageCode = 'home';
const String _userPageCode = 'user';
const String _productPageCode = 'product';
const String _equipmentPageCode = 'equipment';
const Duration _visibilityRefreshInterval = Duration(seconds: 15);

class _ShellMenuItem {
  const _ShellMenuItem({
    required this.code,
    required this.title,
    required this.icon,
  });

  final String code;
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

class _MainShellPageState extends State<MainShellPage>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  late final PageVisibilityService _pageVisibilityService;

  Timer? _visibilityTimer;
  bool _refreshingVisibility = false;

  bool _loading = true;
  String _message = '';
  CurrentUser? _currentUser;
  List<PageCatalogItem> _catalog = fallbackPageCatalog;
  Map<String, List<String>> _tabCodesByParent = const {};
  List<_ShellMenuItem> _menus = const [];
  String _selectedPageCode = _homePageCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageVisibilityService = PageVisibilityService(widget.session);
    _loadCurrentUserAndVisibility();
    _startVisibilityPolling();
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshVisibility(silent: true);
    }
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

  IconData _iconForPage(String pageCode) {
    switch (pageCode) {
      case _homePageCode:
        return Icons.home_rounded;
      case _userPageCode:
        return Icons.group_rounded;
      case _productPageCode:
        return Icons.inventory_2_rounded;
      case _equipmentPageCode:
        return Icons.precision_manufacturing_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  List<_ShellMenuItem> _buildMenus({
    required List<PageCatalogItem> catalog,
    required List<String> visibleSidebarCodes,
  }) {
    final visibleCodeSet = visibleSidebarCodes.toSet();
    final sidebarPages =
        catalog.where((item) => item.pageType == 'sidebar').toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final items = <_ShellMenuItem>[];
    for (final page in sidebarPages) {
      if (!page.alwaysVisible && !visibleCodeSet.contains(page.code)) {
        continue;
      }
      items.add(
        _ShellMenuItem(
          code: page.code,
          title: page.name,
          icon: _iconForPage(page.code),
        ),
      );
    }

    if (!items.any((item) => item.code == _homePageCode)) {
      items.insert(
        0,
        _ShellMenuItem(
          code: _homePageCode,
          title: '首页',
          icon: _iconForPage(_homePageCode),
        ),
      );
    }

    return items;
  }

  Map<String, List<String>> _sortTabsByCatalog(
    Map<String, List<String>> tabCodesByParent,
    List<PageCatalogItem> catalog,
  ) {
    final sortOrderByCode = <String, int>{
      for (final item in catalog) item.code: item.sortOrder,
    };

    final result = <String, List<String>>{};
    tabCodesByParent.forEach((parentCode, tabCodes) {
      final sorted = [...tabCodes]
        ..sort((a, b) {
          final orderA = sortOrderByCode[a] ?? 9999;
          final orderB = sortOrderByCode[b] ?? 9999;
          if (orderA != orderB) {
            return orderA.compareTo(orderB);
          }
          return a.compareTo(b);
        });
      result[parentCode] = sorted;
    });

    return result;
  }

  void _startVisibilityPolling() {
    _visibilityTimer?.cancel();
    _visibilityTimer = Timer.periodic(_visibilityRefreshInterval, (_) {
      _refreshVisibility(silent: true);
    });
  }

  Future<void> _loadCurrentUserAndVisibility() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final currentUser = await _authService.getCurrentUser(
        baseUrl: widget.session.baseUrl,
        accessToken: widget.session.accessToken,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = currentUser;
      });
      await _refreshVisibility(loadCatalog: true);
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

  Future<void> _refreshVisibility({
    bool loadCatalog = false,
    bool silent = false,
  }) async {
    if (_refreshingVisibility) {
      return;
    }
    _refreshingVisibility = true;

    try {
      var catalog = _catalog;
      var usedFallbackCatalog = false;

      if (loadCatalog || catalog.isEmpty) {
        try {
          catalog = await _pageVisibilityService.listPageCatalog();
        } catch (_) {
          catalog = fallbackPageCatalog;
          usedFallbackCatalog = true;
        }
      }

      final visibility = await _pageVisibilityService.getMyVisibility();
      final sortedCatalog = [...catalog]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final sortedTabCodes = _sortTabsByCatalog(
        visibility.tabCodesByParent,
        sortedCatalog,
      );
      final menus = _buildMenus(
        catalog: sortedCatalog,
        visibleSidebarCodes: visibility.sidebarCodes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _catalog = sortedCatalog;
        _tabCodesByParent = sortedTabCodes;
        _menus = menus;
        if (_menus.isEmpty) {
          _selectedPageCode = _homePageCode;
        } else if (!_menus.any((item) => item.code == _selectedPageCode)) {
          _selectedPageCode = _menus.first.code;
        }

        if (usedFallbackCatalog) {
          _message = '后端页面目录不可达，已使用本地目录兜底。';
        } else if (!silent) {
          _message = '';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (!silent) {
        setState(() {
          _message = '加载页面可见性失败：${_errorMessage(error)}';
        });
      }
    } finally {
      _refreshingVisibility = false;
    }
  }

  Future<void> _handleVisibilityConfigSaved() async {
    await _refreshVisibility(loadCatalog: true);
  }

  List<String> _visibleUserTabCodes() {
    final tabCodes = _tabCodesByParent[_userPageCode] ?? const <String>[];
    final catalogCodes = _catalog.map((item) => item.code).toSet();
    return tabCodes.where(catalogCodes.contains).toList();
  }

  List<String> _visibleProductTabCodes() {
    final tabCodes = _tabCodesByParent[_productPageCode] ?? const <String>[];
    final catalogCodes = _catalog.map((item) => item.code).toSet();
    return tabCodes.where(catalogCodes.contains).toList();
  }

  List<String> _visibleEquipmentTabCodes() {
    final tabCodes = _tabCodesByParent[_equipmentPageCode] ?? const <String>[];
    final catalogCodes = _catalog.map((item) => item.code).toSet();
    return tabCodes.where(catalogCodes.contains).toList();
  }

  Widget _buildContent(String pageCode) {
    switch (pageCode) {
      case _homePageCode:
        return HomePage(currentUser: _currentUser!);
      case _userPageCode:
        return UserPage(
          session: widget.session,
          onLogout: widget.onLogout,
          visibleTabCodes: _visibleUserTabCodes(),
          onVisibilityConfigSaved: _handleVisibilityConfigSaved,
        );
      case _productPageCode:
        return ProductPage(
          session: widget.session,
          onLogout: widget.onLogout,
          visibleTabCodes: _visibleProductTabCodes(),
          currentRoleCodes: _currentUser!.roleCodes,
        );
      case _equipmentPageCode:
        return EquipmentPage(
          session: widget.session,
          onLogout: widget.onLogout,
          visibleTabCodes: _visibleEquipmentTabCodes(),
          currentRoleCodes: _currentUser!.roleCodes,
        );
      default:
        return Center(child: Text('页面暂未实现：$pageCode'));
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
                const Text('当前账号没有可访问页面。'),
                const SizedBox(height: 8),
                const Text('请联系系统管理员调整页面可见性配置。'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _refreshVisibility(),
                        child: const Text('刷新'),
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
                Text(_message.isEmpty ? '加载失败' : _message),
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
                        onPressed: _loadCurrentUserAndVisibility,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
      return Scaffold(body: _buildErrorPage());
    }

    if (_menus.isEmpty) {
      return Scaffold(body: _buildNoAccessPage());
    }

    final selectedIndex = _menus.indexWhere(
      (menu) => menu.code == _selectedPageCode,
    );
    final safeSelectedIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final selectedMenuCode = _menus[safeSelectedIndex].code;

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
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                        final selected = menu.code == selectedMenuCode;
                        return ListTile(
                          selected: selected,
                          leading: Icon(menu.icon),
                          title: Text(menu.title),
                          onTap: () {
                            if (_selectedPageCode == menu.code) {
                              return;
                            }
                            setState(() {
                              _selectedPageCode = menu.code;
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
              child: Column(
                children: [
                  if (_message.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: theme.colorScheme.surfaceContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(_message, style: theme.textTheme.bodyMedium),
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: safeSelectedIndex,
                      children: _menus
                          .map((menu) => _buildContent(menu.code))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

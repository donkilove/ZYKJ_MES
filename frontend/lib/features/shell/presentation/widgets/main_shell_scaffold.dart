import 'package:flutter/material.dart';

import 'package:mes_client/features/shell/presentation/main_shell_state.dart';

class MainShellScaffold extends StatelessWidget {
  const MainShellScaffold({
    super.key,
    required this.state,
    required this.currentUserDisplayName,
    required this.content,
    required this.onSelectMenu,
    required this.onOpenPluginHost,
    required this.onOpenSoftwareSettings,
    required this.sidebarCollapsed,
    required this.onLogout,
    required this.onRetry,
    required this.showNoAccessPage,
    required this.showErrorPage,
  });

  final MainShellViewState state;
  final String currentUserDisplayName;
  final Widget content;
  final ValueChanged<String> onSelectMenu;
  final VoidCallback onOpenPluginHost;
  final VoidCallback onOpenSoftwareSettings;
  final bool sidebarCollapsed;
  final VoidCallback onLogout;
  final VoidCallback onRetry;
  final bool showNoAccessPage;
  final bool showErrorPage;

  @override
  Widget build(BuildContext context) {
    if (showErrorPage) {
      return Scaffold(body: _buildErrorPage(context));
    }
    if (showNoAccessPage) {
      return Scaffold(body: _buildNoAccessPage(context));
    }

    final theme = Theme.of(context);
    final selectedMenuCode =
        state.menus
            .where((item) => item.code == state.selectedPageCode)
            .map((item) => item.code)
            .firstOrNull ??
        state.menus.first.code;
    final contentPageCode = state.activeUtilityCode ?? selectedMenuCode;
    final isSoftwareSettingsActive =
        state.activeUtilityCode == softwareSettingsUtilityCode;
    final hasActiveUtility = state.activeUtilityCode != null;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: sidebarCollapsed ? 76 : 240,
            color: theme.colorScheme.surfaceContainerHighest,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: sidebarCollapsed
                        ? Icon(
                            Icons.dashboard_customize_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : Column(
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
                                currentUserDisplayName,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.menus.length,
                      itemBuilder: (context, index) {
                        final menu = state.menus[index];
                        final selected =
                            !hasActiveUtility && menu.code == selectedMenuCode;
                        final isMessage = menu.code == 'message';
                        return ListTile(
                          key: ValueKey('main-shell-menu-${menu.code}'),
                          selected: selected,
                          leading: isMessage && state.unreadCount > 0
                              ? Badge(
                                  label: Text(
                                    state.unreadCount > 99
                                        ? '99+'
                                        : '${state.unreadCount}',
                                  ),
                                  child: Icon(menu.icon),
                                )
                              : Icon(menu.icon),
                          title: sidebarCollapsed ? null : Text(menu.title),
                          onTap: () => onSelectMenu(menu.code),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('main-shell-entry-plugin-host'),
                    selected: state.activeUtilityCode == pluginHostUtilityCode,
                    leading: const Icon(Icons.extension_rounded),
                    title: sidebarCollapsed ? null : const Text('插件中心'),
                    onTap: onOpenPluginHost,
                  ),
                  ListTile(
                    key: const ValueKey('main-shell-entry-software-settings'),
                    selected: isSoftwareSettingsActive,
                    leading: const Icon(Icons.tune_rounded),
                    title: sidebarCollapsed ? null : const Text('软件设置'),
                    onTap: onOpenSoftwareSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: sidebarCollapsed ? null : const Text('退出登录'),
                    onTap: onLogout,
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
                  if (state.message.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: theme.colorScheme.surfaceContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        state.message,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  Expanded(
                    child: Container(
                      key: ValueKey('main-shell-content-$contentPageCode'),
                      child: content,
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

  Widget _buildNoAccessPage(BuildContext context) {
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
                const Text('当前账号暂无可访问页面'),
                const SizedBox(height: 8),
                const Text('请联系系统管理员分配页面可见权限'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.manualRefreshing ? null : onRetry,
                        child: const Text('刷新'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onLogout,
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

  Widget _buildErrorPage(BuildContext context) {
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
                Text(state.message.isEmpty ? '加载失败' : state.message),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onLogout,
                        child: const Text('退出登录'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onRetry,
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
}

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/current_user.dart';

class HomeQuickJumpEntry {
  const HomeQuickJumpEntry({
    required this.pageCode,
    required this.title,
    required this.icon,
    this.tabCode,
    this.routePayloadJson,
  });

  final String pageCode;
  final String title;
  final IconData icon;
  final String? tabCode;
  final String? routePayloadJson;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.currentUser,
    required this.shortcuts,
    required this.onNavigateToPage,
    required this.onRefresh,
    required this.refreshing,
    this.refreshStatusText,
  });

  final CurrentUser currentUser;
  final List<HomeQuickJumpEntry> shortcuts;
  final void Function(
    String pageCode, {
    String? tabCode,
    String? routePayloadJson,
  })
  onNavigateToPage;
  final Future<void> Function() onRefresh;
  final bool refreshing;
  final String? refreshStatusText;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CurrentUser get currentUser => widget.currentUser;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return '凌晨好';
    }
    if (hour < 12) {
      return '早上好';
    }
    if (hour < 18) {
      return '下午好';
    }
    return '晚上好';
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final weekday = [
      '星期一',
      '星期二',
      '星期三',
      '星期四',
      '星期五',
      '星期六',
      '星期日',
    ][now.weekday - 1];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()}，${currentUser.displayName}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '欢迎使用 ZYKJ MES 系统',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dateStr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weekday,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '角色身份',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.8,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (currentUser.roleName?.trim().isNotEmpty != true)
                  Text(
                    '暂无角色',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentUser.roleName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _quickActionColor(ThemeData theme, int index) {
    switch (index % 3) {
      case 0:
        return theme.colorScheme.primary;
      case 1:
        return theme.colorScheme.secondary;
      default:
        return theme.colorScheme.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortcuts = widget.shortcuts;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '工作台',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.refreshStatusText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.refreshStatusText!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: widget.refreshing
                      ? const Icon(Icons.sync)
                      : const Icon(Icons.refresh),
                  onPressed: widget.refreshing
                      ? null
                      : () => widget.onRefresh(),
                  tooltip: widget.refreshing ? '刷新中' : '刷新业务数据',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildWelcomeCard(context),
            const SizedBox(height: 24),
            Text(
              '快速跳转',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1200
                    ? 7
                    : constraints.maxWidth > 900
                    ? 5
                    : constraints.maxWidth > 600
                    ? 4
                    : 3;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: shortcuts.isEmpty
                      ? [
                          _buildQuickActionCard(
                            context,
                            icon: Icons.info_outline_rounded,
                            title: '暂无可快捷跳转的模块',
                            color: theme.colorScheme.outline,
                            subtitle: '请联系管理员分配页面可见权限',
                          ),
                        ]
                      : [
                          for (var index = 0; index < shortcuts.length; index++)
                            _buildQuickActionCard(
                              context,
                              icon: shortcuts[index].icon,
                              title: shortcuts[index].title,
                              color: _quickActionColor(theme, index),
                              subtitle: shortcuts[index].tabCode == null
                                  ? null
                                  : '默认页签：${shortcuts[index].tabCode}',
                              onTap: () => widget.onNavigateToPage(
                                shortcuts[index].pageCode,
                                tabCode: shortcuts[index].tabCode,
                                routePayloadJson:
                                    shortcuts[index].routePayloadJson,
                              ),
                            ),
                        ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

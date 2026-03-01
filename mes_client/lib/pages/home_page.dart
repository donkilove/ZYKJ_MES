import 'package:flutter/material.dart';

import '../models/current_user.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.currentUser});

  final CurrentUser currentUser;

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

  String _workbenchSummary() {
    final roleCount = currentUser.roleNames.length;
    final processCount = currentUser.processNames.length;
    if (roleCount == 0 && processCount == 0) {
      return '当前账号暂无角色与工序分配，请联系系统管理员确认权限配置。';
    }
    if (processCount == 0) {
      return '当前账号已分配 $roleCount 个角色，暂未分配工序。';
    }
    return '当前账号已分配 $roleCount 个角色，覆盖 $processCount 个工序。';
  }

  Widget _buildTagList({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<String> values,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (values.isEmpty)
          Text(
            '暂无',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (entry) => Chip(
                    label: Text(entry),
                    backgroundColor: backgroundColor,
                    labelStyle: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color tint,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: tint.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tint.withValues(alpha: 0.18),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleCount = currentUser.roleNames.length;
    final processCount = currentUser.processNames.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '工作台首页',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()}，${currentUser.displayName}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_workbenchSummary(), style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _buildMetricCard(
                          context: context,
                          label: '账号',
                          value: currentUser.username,
                          icon: Icons.person_outline,
                          tint: theme.colorScheme.primary,
                        ),
                        _buildMetricCard(
                          context: context,
                          label: '角色数量',
                          value: '$roleCount 个',
                          icon: Icons.badge_outlined,
                          tint: theme.colorScheme.secondary,
                        ),
                        _buildMetricCard(
                          context: context,
                          label: '工序数量',
                          value: '$processCount 个',
                          icon: Icons.factory_outlined,
                          tint: theme.colorScheme.tertiary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 900;
                final children = [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildTagList(
                        context: context,
                        icon: Icons.groups_outlined,
                        title: '角色权限',
                        values: currentUser.roleNames,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildTagList(
                        context: context,
                        icon: Icons.precision_manufacturing_outlined,
                        title: '工序权限',
                        values: currentUser.processNames,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ];

                if (isCompact) {
                  return Column(
                    children: [
                      ...children.map(
                        (child) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: child,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 12),
                    Expanded(child: children[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '快速说明',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _HomeTipItem(index: 1, text: '左侧导航栏用于切换模块页面。'),
                    const SizedBox(height: 8),
                    const _HomeTipItem(index: 2, text: '菜单与页签会根据角色权限自动变化。'),
                    const SizedBox(height: 8),
                    const _HomeTipItem(index: 3, text: '产品参数支持拖拽排序、历史备注与快速查询。'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTipItem extends StatelessWidget {
  const _HomeTipItem({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
          ),
          child: Text(
            '$index',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

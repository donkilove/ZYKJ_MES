import 'package:flutter/material.dart';

import '../models/current_user.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.currentUser,
  });

  final CurrentUser currentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleText = currentUser.roleNames.isEmpty ? '-' : currentUser.roleNames.join('、');
    final processText = currentUser.processNames.isEmpty ? '-' : currentUser.processNames.join('、');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '首页',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '欢迎，${currentUser.displayName}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text('账号：${currentUser.username}'),
                    const SizedBox(height: 8),
                    Text('角色：$roleText'),
                    const SizedBox(height: 8),
                    Text('工序：$processText'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('快捷说明', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 10),
                    Text('1. 左侧侧边栏可切换页面。'),
                    SizedBox(height: 6),
                    Text('2. 菜单会按账号权限自动显示。'),
                    SizedBox(height: 6),
                    Text('3. 当前版本已开放“用户”和“产品”模块能力。'),
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';
import 'package:mes_client/features/shell/presentation/widgets/main_shell_scaffold.dart';

void main() {
  testWidgets('MainShellScaffold 渲染菜单、消息条和内容区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainShellScaffold(
          state: const MainShellViewState(
            menus: [
              MainShellMenuItem(code: 'home', title: '首页', icon: Icons.home),
              MainShellMenuItem(code: 'user', title: '用户', icon: Icons.group),
              MainShellMenuItem(
                code: 'message',
                title: '消息',
                icon: Icons.notifications,
              ),
            ],
            selectedPageCode: 'user',
            unreadCount: 7,
            message: '页面目录加载失败，已使用本地兜底配置。',
          ),
          currentUserDisplayName: '测试用户',
          content: const Text('content'),
          onSelectMenu: (_) {},
          onLogout: () {},
          onRetry: () {},
          showNoAccessPage: false,
          showErrorPage: false,
        ),
      ),
    );

    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('页面目录加载失败，已使用本地兜底配置。'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}

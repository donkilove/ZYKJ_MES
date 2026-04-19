import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/shell/presentation/main_shell_navigation.dart';
import 'package:mes_client/features/shell/presentation/main_shell_state.dart';

import 'main_shell_test_support.dart';

void main() {
  test('buildMainShellMenus 按目录顺序生成首页与可见模块菜单', () {
    final menus = buildMainShellMenus(
      catalog: buildCatalog(),
      visibleSidebarCodes: const ['user', 'message'],
      homePageCode: 'home',
      iconForPage: iconForPageForTest,
    );

    expect(menus.map((item) => item.code).toList(), ['home', 'user', 'message']);
    expect(menus.first.title, '首页');
  });

  test('resolveMainShellTarget 会把 tab 解析成父模块并继承页签代码', () {
    final result = resolveMainShellTarget(
      requestedPageCode: 'account_settings',
      requestedTabCode: null,
      requestedRoutePayloadJson: '{"target_tab_code":"account_settings"}',
      catalog: buildCatalog(),
      menus: const [
        MainShellMenuItem(code: 'home', title: '首页', icon: Icons.home),
        MainShellMenuItem(code: 'user', title: '用户', icon: Icons.group),
      ],
    );

    expect(result.hasAccess, isTrue);
    expect(result.pageCode, 'user');
    expect(result.tabCode, 'account_settings');
  });
}

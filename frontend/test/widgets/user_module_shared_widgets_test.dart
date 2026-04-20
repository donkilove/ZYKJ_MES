import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_feedback_banner.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_filter_panel.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_status_chip.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_table_shell.dart';

void main() {
  testWidgets('用户模块共享件提供稳定反馈、筛选和表格壳层', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: const Scaffold(
          body: Column(
            children: [
              UserModuleFeedbackBanner.error(message: '权限不足'),
              UserModuleFilterPanel(
                sectionKey: ValueKey('filter-shell'),
                child: Text('筛选内容'),
              ),
              Expanded(
                child: UserModuleTableShell(
                  sectionKey: ValueKey('table-shell'),
                  title: '用户列表',
                  child: Center(
                    child: UserModuleStatusChip(
                      tone: UserModuleStatusTone.online,
                      label: '在线',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('权限不足'), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('table-shell')), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
  });
}

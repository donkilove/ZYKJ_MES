import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/software_settings_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    SoftwareSettingsController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SoftwareSettingsPage(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SoftwareSettingsPage 渲染外观与布局偏好两个分区', (tester) async {
    final controller = SoftwareSettingsController.memory();

    await pumpPage(tester, controller);

    expect(find.text('外观'), findsWidgets);
    expect(find.text('布局偏好'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, '恢复默认'), findsOneWidget);
  });

  testWidgets('切换深色与紧凑密度后会更新预览卡片', (tester) async {
    final controller = SoftwareSettingsController.memory();

    await pumpPage(tester, controller);
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('紧凑'));
    await tester.pumpAndSettle();

    expect(controller.settings.themePreference, AppThemePreference.dark);
    expect(controller.settings.densityPreference, AppDensityPreference.compact);
    expect(find.text('当前主题：深色'), findsOneWidget);
    expect(find.text('当前密度：紧凑'), findsOneWidget);
  });

  testWidgets('恢复默认会清回默认值并展示自动保存提示', (tester) async {
    final controller = SoftwareSettingsController.memory(
      initialSettings: const SoftwareSettings(
        themePreference: AppThemePreference.dark,
        densityPreference: AppDensityPreference.compact,
        launchTargetPreference: AppLaunchTargetPreference.lastVisitedModule,
        sidebarPreference: AppSidebarPreference.collapsed,
      ),
    );

    await pumpPage(tester, controller);
    await tester.tap(find.widgetWithText(OutlinedButton, '恢复默认'));
    await tester.pumpAndSettle();

    expect(controller.settings, const SoftwareSettings.defaults());
    expect(find.text('已自动保存'), findsOneWidget);
  });
}

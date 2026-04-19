import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/main.dart';

void main() {
  testWidgets('应用入口已启用中文本地化配置', (WidgetTester tester) async {
    final controller = SoftwareSettingsController.memory(
      initialSettings: const SoftwareSettings(
        themePreference: AppThemePreference.dark,
        densityPreference: AppDensityPreference.compact,
        launchTargetPreference: AppLaunchTargetPreference.home,
        sidebarPreference: AppSidebarPreference.expanded,
      ),
    );

    await tester.pumpWidget(
      MesClientApp(softwareSettingsController: controller),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.locale, const Locale('zh', 'CN'));
    expect(app.supportedLocales, contains(const Locale('zh', 'CN')));
    expect(
      app.localizationsDelegates,
      contains(GlobalMaterialLocalizations.delegate),
    );
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme?.visualDensity, VisualDensity.compact);
  });
}

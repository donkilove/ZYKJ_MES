import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';
import 'package:mes_client/main.dart';

void main() {
  testWidgets('应用入口已启用中文本地化配置', (WidgetTester tester) async {
    final controller = SoftwareSettingsController.memory(
      initialSettings: const SoftwareSettings(
        themePreference: AppThemePreference.dark,
        densityPreference: AppDensityPreference.compact,
        launchTargetPreference: AppLaunchTargetPreference.home,
        sidebarPreference: AppSidebarPreference.expanded,
        timeSyncEnabled: true,
      ),
    );
    final timeSyncController = TimeSyncController(
      softwareSettingsController: controller,
      serverTimeService: _ThrowingServerTimeService(),
      systemTimeSyncService: _FakeWindowsTimeSyncService(),
      effectiveClock: EffectiveClock(),
    );

    await tester.pumpWidget(
      MesClientApp(
        softwareSettingsController: controller,
        timeSyncController: timeSyncController,
      ),
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

  testWidgets('默认 memory controller 也能驱动应用启动', (WidgetTester tester) async {
    final settingsController = SoftwareSettingsController.memory();
    final timeSyncController = TimeSyncController(
      softwareSettingsController: settingsController,
      serverTimeService: _ThrowingServerTimeService(),
      systemTimeSyncService: _FakeWindowsTimeSyncService(),
      effectiveClock: EffectiveClock(),
    );

    await tester.pumpWidget(
      MesClientApp(
        softwareSettingsController: settingsController,
        timeSyncController: timeSyncController,
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeMode, ThemeMode.system);
    expect(app.theme?.visualDensity, VisualDensity.standard);
  });

  test('软件设置初始化失败时会回退到默认 memory controller', () async {
    final controller = await bootstrapSoftwareSettingsController(
      createService: () async => throw Exception('create failed'),
    );

    expect(controller.loaded, isTrue);
    expect(controller.settings, const SoftwareSettings.defaults());
    expect(controller.themeMode, ThemeMode.system);
  });

  test('软件设置加载失败时会回退到默认 memory controller', () async {
    final controller = await bootstrapSoftwareSettingsController(
      createService: () async => _ThrowingLoadSoftwareSettingsService(),
    );

    expect(controller.loaded, isTrue);
    expect(controller.settings, const SoftwareSettings.defaults());
    expect(controller.themeMode, ThemeMode.system);
  });
}

class _ThrowingServerTimeService extends ServerTimeService {
  @override
  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) {
    throw Exception('not used');
  }
}

class _FakeWindowsTimeSyncService extends WindowsTimeSyncService {}

class _ThrowingLoadSoftwareSettingsService
    implements SoftwareSettingsService {
  @override
  Future<SoftwareSettings> load() async {
    throw Exception('load failed');
  }

  @override
  Future<void> restoreDefaults() async {}

  @override
  Future<void> save(SoftwareSettings settings) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

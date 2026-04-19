import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';

void main() {
  test('load() 会把 service 返回值写入 controller', () async {
    const loadedSettings = SoftwareSettings(
      themePreference: AppThemePreference.dark,
      densityPreference: AppDensityPreference.compact,
      launchTargetPreference: AppLaunchTargetPreference.lastVisitedModule,
      sidebarPreference: AppSidebarPreference.collapsed,
      lastVisitedPageCode: 'QUALITY_DASHBOARD',
    );
    final controller = SoftwareSettingsController(
      service: _FakeSoftwareSettingsService(settingsToLoad: loadedSettings),
    );

    await controller.load();

    expect(controller.loaded, isTrue);
    expect(controller.settings, loadedSettings);
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.visualDensity, VisualDensity.compact);
  });
}

class _FakeSoftwareSettingsService implements SoftwareSettingsService {
  _FakeSoftwareSettingsService({required this.settingsToLoad});

  final SoftwareSettings settingsToLoad;

  @override
  Future<SoftwareSettings> load() async => settingsToLoad;

  @override
  Future<void> restoreDefaults() async {}

  @override
  Future<void> save(SoftwareSettings settings) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

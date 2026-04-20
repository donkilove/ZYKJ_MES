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
      timeSyncEnabled: true,
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

  test('updateThemePreference() 会更新内存态并调用 save()', () async {
    final service = _FakeSoftwareSettingsService(
      settingsToLoad: const SoftwareSettings.defaults(),
    );
    final controller = SoftwareSettingsController(service: service);

    await controller.updateThemePreference(AppThemePreference.dark);

    expect(controller.settings.themePreference, AppThemePreference.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(service.saveCallCount, 1);
    expect(
      service.savedSettings.single.themePreference,
      AppThemePreference.dark,
    );
    expect(controller.saveFailed, isFalse);
    expect(controller.saveMessage, '主题偏好已保存');
  });

  test('restoreDefaults() 会回到默认值', () async {
    final service = _FakeSoftwareSettingsService(
      settingsToLoad: const SoftwareSettings.defaults(),
    );
    final controller = SoftwareSettingsController(service: service);

    await controller.updateThemePreference(AppThemePreference.dark);
    await controller.updateDensityPreference(AppDensityPreference.compact);
    await controller.rememberLastVisitedPageCode('QUALITY_DASHBOARD');
    await controller.restoreDefaults();

    expect(controller.settings, const SoftwareSettings.defaults());
    expect(service.savedSettings.last, const SoftwareSettings.defaults());
  });

  test('updateTimeSyncEnabled() 会更新内存态并调用 save()', () async {
    final service = _FakeSoftwareSettingsService(
      settingsToLoad: const SoftwareSettings.defaults(),
    );
    final controller = SoftwareSettingsController(service: service);

    await controller.updateTimeSyncEnabled(false);

    expect(controller.settings.timeSyncEnabled, isFalse);
    expect(service.savedSettings.single.timeSyncEnabled, isFalse);
    expect(controller.saveFailed, isFalse);
    expect(controller.saveMessage, '时间同步已关闭');
  });

  test('保存失败时会写入失败状态和失败提示', () async {
    final controller = SoftwareSettingsController(
      service: _FakeSoftwareSettingsService(
        settingsToLoad: const SoftwareSettings.defaults(),
        saveError: Exception('save failed'),
      ),
    );

    await controller.updateDensityPreference(AppDensityPreference.compact);

    expect(controller.settings.densityPreference, AppDensityPreference.compact);
    expect(controller.saveFailed, isTrue);
    expect(controller.saveMessage, '界面密度偏好保存失败');
  });

  test('状态变化后会通知监听器', () async {
    final controller = SoftwareSettingsController(
      service: _FakeSoftwareSettingsService(
        settingsToLoad: const SoftwareSettings.defaults(),
      ),
    );
    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    await controller.updateSidebarPreference(AppSidebarPreference.collapsed);

    expect(notifications, 1);
  });
}

class _FakeSoftwareSettingsService implements SoftwareSettingsService {
  _FakeSoftwareSettingsService({
    required this.settingsToLoad,
    this.saveError,
  });

  final SoftwareSettings settingsToLoad;
  final Object? saveError;
  final List<SoftwareSettings> savedSettings = <SoftwareSettings>[];

  int get saveCallCount => savedSettings.length;

  @override
  Future<SoftwareSettings> load() async => settingsToLoad;

  @override
  Future<void> restoreDefaults() async {}

  @override
  Future<void> save(SoftwareSettings settings) async {
    savedSettings.add(settings);
    if (saveError != null) {
      throw saveError!;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

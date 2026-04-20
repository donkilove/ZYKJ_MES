import 'package:flutter/material.dart';

import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';

class SoftwareSettingsController extends ChangeNotifier {
  SoftwareSettingsController({required SoftwareSettingsService service})
    : _service = service,
      _settings = const SoftwareSettings.defaults(),
      _loaded = false;

  SoftwareSettingsController.memory({
    SoftwareSettings initialSettings = const SoftwareSettings.defaults(),
  }) : _service = _MemorySoftwareSettingsService(initialSettings),
       _settings = initialSettings,
       _loaded = true;

  final SoftwareSettingsService _service;

  SoftwareSettings _settings;
  bool _loaded;
  String? _saveMessage;
  bool _saveFailed = false;

  SoftwareSettings get settings => _settings;
  bool get loaded => _loaded;
  String? get saveMessage => _saveMessage;
  bool get saveFailed => _saveFailed;

  ThemeMode get themeMode {
    switch (_settings.themePreference) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  VisualDensity get visualDensity {
    switch (_settings.densityPreference) {
      case AppDensityPreference.comfortable:
        return VisualDensity.standard;
      case AppDensityPreference.compact:
        return VisualDensity.compact;
    }
  }

  Future<void> load() async {
    _settings = await _service.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateThemePreference(AppThemePreference preference) {
    return _persist(
      _settings.copyWith(themePreference: preference),
      successMessage: '主题偏好已保存',
      failureMessage: '主题偏好保存失败',
    );
  }

  Future<void> updateDensityPreference(AppDensityPreference preference) {
    return _persist(
      _settings.copyWith(densityPreference: preference),
      successMessage: '界面密度偏好已保存',
      failureMessage: '界面密度偏好保存失败',
    );
  }

  Future<void> updateLaunchTargetPreference(
    AppLaunchTargetPreference preference,
  ) {
    return _persist(
      _settings.copyWith(launchTargetPreference: preference),
      successMessage: '启动入口偏好已保存',
      failureMessage: '启动入口偏好保存失败',
    );
  }

  Future<void> updateSidebarPreference(AppSidebarPreference preference) {
    return _persist(
      _settings.copyWith(sidebarPreference: preference),
      successMessage: '侧边栏偏好已保存',
      failureMessage: '侧边栏偏好保存失败',
    );
  }

  Future<void> updateTimeSyncEnabled(bool enabled) {
    return _persist(
      _settings.copyWith(timeSyncEnabled: enabled),
      successMessage: enabled ? '时间同步已启用' : '时间同步已关闭',
      failureMessage: enabled ? '时间同步启用失败' : '时间同步关闭失败',
    );
  }

  Future<void> rememberLastVisitedPageCode(String? pageCode) {
    return _persist(
      _settings.copyWith(lastVisitedPageCode: pageCode),
      successMessage: '最近访问页面已记录',
      failureMessage: '最近访问页面记录失败',
    );
  }

  Future<void> restoreDefaults() {
    return _persist(
      const SoftwareSettings.defaults(),
      successMessage: '软件设置已恢复默认值',
      failureMessage: '软件设置恢复默认值失败',
    );
  }

  Future<void> _persist(
    SoftwareSettings nextSettings, {
    required String successMessage,
    required String failureMessage,
  }) async {
    _settings = nextSettings;
    _loaded = true;
    try {
      await _service.save(nextSettings);
      _saveMessage = successMessage;
      _saveFailed = false;
    } catch (_) {
      _saveMessage = failureMessage;
      _saveFailed = true;
    }
    notifyListeners();
  }
}

class _MemorySoftwareSettingsService implements SoftwareSettingsService {
  _MemorySoftwareSettingsService(this._settings);

  SoftwareSettings _settings;

  @override
  Future<SoftwareSettings> load() async => _settings;

  @override
  Future<void> restoreDefaults() async {
    _settings = const SoftwareSettings.defaults();
  }

  @override
  Future<void> save(SoftwareSettings settings) async {
    _settings = settings;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

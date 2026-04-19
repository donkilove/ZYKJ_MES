import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoftwareSettingsService {
  SoftwareSettingsService(this._preferences);

  static const _keyPrefix = 'software_settings.';
  static const _themeKey = '${_keyPrefix}theme_preference';
  static const _densityKey = '${_keyPrefix}density_preference';
  static const _launchTargetKey = '${_keyPrefix}launch_target_preference';
  static const _sidebarKey = '${_keyPrefix}sidebar_preference';
  static const _lastVisitedPageKey = '${_keyPrefix}last_visited_page_code';

  final SharedPreferences _preferences;

  static Future<SoftwareSettingsService> create() async {
    return SoftwareSettingsService(await SharedPreferences.getInstance());
  }

  Future<SoftwareSettings> load() async {
    return SoftwareSettings(
      themePreference: _parseTheme(_preferences.getString(_themeKey)),
      densityPreference: _parseDensity(_preferences.getString(_densityKey)),
      launchTargetPreference: _parseLaunchTarget(
        _preferences.getString(_launchTargetKey),
      ),
      sidebarPreference: _parseSidebar(_preferences.getString(_sidebarKey)),
      lastVisitedPageCode: _normalizePageCode(
        _preferences.getString(_lastVisitedPageKey),
      ),
    );
  }

  Future<void> save(SoftwareSettings settings) async {
    await _preferences.setString(
      _themeKey,
      _themeToStorage(settings.themePreference),
    );
    await _preferences.setString(
      _densityKey,
      _densityToStorage(settings.densityPreference),
    );
    await _preferences.setString(
      _launchTargetKey,
      _launchTargetToStorage(settings.launchTargetPreference),
    );
    await _preferences.setString(
      _sidebarKey,
      _sidebarToStorage(settings.sidebarPreference),
    );

    final normalizedPageCode = _normalizePageCode(settings.lastVisitedPageCode);
    if (normalizedPageCode == null) {
      await _preferences.remove(_lastVisitedPageKey);
      return;
    }

    await _preferences.setString(_lastVisitedPageKey, normalizedPageCode);
  }

  Future<void> restoreDefaults() async {
    await save(const SoftwareSettings.defaults());
  }

  AppThemePreference _parseTheme(String? value) {
    switch (value) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  AppDensityPreference _parseDensity(String? value) {
    switch (value) {
      case 'compact':
        return AppDensityPreference.compact;
      default:
        return AppDensityPreference.comfortable;
    }
  }

  AppLaunchTargetPreference _parseLaunchTarget(String? value) {
    switch (value) {
      case 'last_visited_module':
        return AppLaunchTargetPreference.lastVisitedModule;
      default:
        return AppLaunchTargetPreference.home;
    }
  }

  AppSidebarPreference _parseSidebar(String? value) {
    switch (value) {
      case 'collapsed':
        return AppSidebarPreference.collapsed;
      default:
        return AppSidebarPreference.expanded;
    }
  }

  String? _normalizePageCode(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _themeToStorage(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.system:
        return 'system';
      case AppThemePreference.light:
        return 'light';
      case AppThemePreference.dark:
        return 'dark';
    }
  }

  String _densityToStorage(AppDensityPreference value) {
    switch (value) {
      case AppDensityPreference.comfortable:
        return 'comfortable';
      case AppDensityPreference.compact:
        return 'compact';
    }
  }

  String _launchTargetToStorage(AppLaunchTargetPreference value) {
    switch (value) {
      case AppLaunchTargetPreference.home:
        return 'home';
      case AppLaunchTargetPreference.lastVisitedModule:
        return 'last_visited_module';
    }
  }

  String _sidebarToStorage(AppSidebarPreference value) {
    switch (value) {
      case AppSidebarPreference.expanded:
        return 'expanded';
      case AppSidebarPreference.collapsed:
        return 'collapsed';
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('copyWith 可显式把 lastVisitedPageCode 清空为 null', () {
    const settings = SoftwareSettings(
      themePreference: AppThemePreference.system,
      densityPreference: AppDensityPreference.comfortable,
      launchTargetPreference: AppLaunchTargetPreference.home,
      sidebarPreference: AppSidebarPreference.expanded,
      timeSyncEnabled: true,
      lastVisitedPageCode: 'quality',
    );

    final copied = settings.copyWith(lastVisitedPageCode: null);

    expect(copied.lastVisitedPageCode, isNull);
  });

  test('load 在本地无配置时返回默认值', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SoftwareSettingsService(
      await SharedPreferences.getInstance(),
    );

    final settings = await service.load();

    expect(settings.themePreference, AppThemePreference.system);
    expect(settings.densityPreference, AppDensityPreference.comfortable);
    expect(settings.launchTargetPreference, AppLaunchTargetPreference.home);
    expect(settings.sidebarPreference, AppSidebarPreference.expanded);
    expect(settings.timeSyncEnabled, isTrue);
    expect(settings.lastVisitedPageCode, isNull);
  });

  test('load 会恢复已保存的软件偏好', () async {
    SharedPreferences.setMockInitialValues({
      'software_settings.theme_preference': 'dark',
      'software_settings.density_preference': 'compact',
      'software_settings.launch_target_preference': 'last_visited_module',
      'software_settings.sidebar_preference': 'collapsed',
      'software_settings.time_sync_enabled': false,
      'software_settings.last_visited_page_code': 'quality',
    });
    final service = SoftwareSettingsService(
      await SharedPreferences.getInstance(),
    );

    final settings = await service.load();

    expect(settings.themePreference, AppThemePreference.dark);
    expect(settings.densityPreference, AppDensityPreference.compact);
    expect(
      settings.launchTargetPreference,
      AppLaunchTargetPreference.lastVisitedModule,
    );
    expect(settings.sidebarPreference, AppSidebarPreference.collapsed);
    expect(settings.timeSyncEnabled, isFalse);
    expect(settings.lastVisitedPageCode, 'quality');
  });

  test('load 遇到非法值时回退默认值', () async {
    SharedPreferences.setMockInitialValues({
      'software_settings.theme_preference': 'purple',
      'software_settings.density_preference': 'huge',
      'software_settings.launch_target_preference': 'dashboard',
      'software_settings.sidebar_preference': 'half',
      'software_settings.last_visited_page_code': '',
    });
    final service = SoftwareSettingsService(
      await SharedPreferences.getInstance(),
    );

    final settings = await service.load();

    expect(settings.themePreference, AppThemePreference.system);
    expect(settings.densityPreference, AppDensityPreference.comfortable);
    expect(settings.launchTargetPreference, AppLaunchTargetPreference.home);
    expect(settings.sidebarPreference, AppSidebarPreference.expanded);
    expect(settings.timeSyncEnabled, isTrue);
    expect(settings.lastVisitedPageCode, isNull);
  });

  test('save 会把枚举值序列化后重新读回', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SoftwareSettingsService(
      await SharedPreferences.getInstance(),
    );

    await service.save(
      const SoftwareSettings(
        themePreference: AppThemePreference.dark,
        densityPreference: AppDensityPreference.compact,
        launchTargetPreference: AppLaunchTargetPreference.lastVisitedModule,
        sidebarPreference: AppSidebarPreference.collapsed,
        timeSyncEnabled: false,
        lastVisitedPageCode: ' quality ',
      ),
    );

    final settings = await service.load();

    expect(settings.themePreference, AppThemePreference.dark);
    expect(settings.densityPreference, AppDensityPreference.compact);
    expect(
      settings.launchTargetPreference,
      AppLaunchTargetPreference.lastVisitedModule,
    );
    expect(settings.sidebarPreference, AppSidebarPreference.collapsed);
    expect(settings.timeSyncEnabled, isFalse);
    expect(settings.lastVisitedPageCode, 'quality');
  });

  test('save 遇到空白或被清空的页面码时会移除本地 key', () async {
    SharedPreferences.setMockInitialValues({
      'software_settings.last_visited_page_code': 'quality',
    });
    final preferences = await SharedPreferences.getInstance();
    final service = SoftwareSettingsService(preferences);

    await service.save(
      const SoftwareSettings(
        themePreference: AppThemePreference.system,
        densityPreference: AppDensityPreference.comfortable,
        launchTargetPreference: AppLaunchTargetPreference.home,
        sidebarPreference: AppSidebarPreference.expanded,
        timeSyncEnabled: true,
        lastVisitedPageCode: '   ',
      ),
    );

    expect(
      preferences.containsKey('software_settings.last_visited_page_code'),
      isFalse,
    );

    await service.save(
      (await service.load()).copyWith(lastVisitedPageCode: null),
    );

    expect(
      preferences.containsKey('software_settings.last_visited_page_code'),
      isFalse,
    );
  });

  test('restoreDefaults 后重新读取会回到默认值并清理页面码', () async {
    SharedPreferences.setMockInitialValues({
      'software_settings.theme_preference': 'dark',
      'software_settings.density_preference': 'compact',
      'software_settings.launch_target_preference': 'last_visited_module',
      'software_settings.sidebar_preference': 'collapsed',
      'software_settings.last_visited_page_code': 'quality',
    });
    final preferences = await SharedPreferences.getInstance();
    final service = SoftwareSettingsService(preferences);

    await service.restoreDefaults();
    final settings = await service.load();

    expect(settings, const SoftwareSettings.defaults());
    expect(
      preferences.containsKey('software_settings.last_visited_page_code'),
      isFalse,
    );
  });
}

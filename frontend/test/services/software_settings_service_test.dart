import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
    expect(settings.lastVisitedPageCode, isNull);
  });

  test('load 会恢复已保存的软件偏好', () async {
    SharedPreferences.setMockInitialValues({
      'software_settings.theme_preference': 'dark',
      'software_settings.density_preference': 'compact',
      'software_settings.launch_target_preference': 'last_visited_module',
      'software_settings.sidebar_preference': 'collapsed',
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
    expect(settings.lastVisitedPageCode, isNull);
  });
}

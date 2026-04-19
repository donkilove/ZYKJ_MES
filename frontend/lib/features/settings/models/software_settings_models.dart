enum AppThemePreference { system, light, dark }

enum AppDensityPreference { comfortable, compact }

enum AppLaunchTargetPreference { home, lastVisitedModule }

enum AppSidebarPreference { expanded, collapsed }

class SoftwareSettings {
  const SoftwareSettings({
    required this.themePreference,
    required this.densityPreference,
    required this.launchTargetPreference,
    required this.sidebarPreference,
    this.lastVisitedPageCode,
  });

  const SoftwareSettings.defaults()
    : themePreference = AppThemePreference.system,
      densityPreference = AppDensityPreference.comfortable,
      launchTargetPreference = AppLaunchTargetPreference.home,
      sidebarPreference = AppSidebarPreference.expanded,
      lastVisitedPageCode = null;

  final AppThemePreference themePreference;
  final AppDensityPreference densityPreference;
  final AppLaunchTargetPreference launchTargetPreference;
  final AppSidebarPreference sidebarPreference;
  final String? lastVisitedPageCode;

  SoftwareSettings copyWith({
    AppThemePreference? themePreference,
    AppDensityPreference? densityPreference,
    AppLaunchTargetPreference? launchTargetPreference,
    AppSidebarPreference? sidebarPreference,
    String? lastVisitedPageCode,
    bool clearLastVisitedPageCode = false,
  }) {
    return SoftwareSettings(
      themePreference: themePreference ?? this.themePreference,
      densityPreference: densityPreference ?? this.densityPreference,
      launchTargetPreference:
          launchTargetPreference ?? this.launchTargetPreference,
      sidebarPreference: sidebarPreference ?? this.sidebarPreference,
      lastVisitedPageCode: clearLastVisitedPageCode
          ? null
          : lastVisitedPageCode ?? this.lastVisitedPageCode,
    );
  }

  static const defaultsValue = SoftwareSettings.defaults();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SoftwareSettings &&
            other.themePreference == themePreference &&
            other.densityPreference == densityPreference &&
            other.launchTargetPreference == launchTargetPreference &&
            other.sidebarPreference == sidebarPreference &&
            other.lastVisitedPageCode == lastVisitedPageCode;
  }

  @override
  int get hashCode => Object.hash(
    themePreference,
    densityPreference,
    launchTargetPreference,
    sidebarPreference,
    lastVisitedPageCode,
  );
}

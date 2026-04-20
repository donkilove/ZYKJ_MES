# 软件设置页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为前端新增“软件设置”全局独立入口，首版支持应用级明暗主题、界面密度、默认进入页和侧边栏默认状态，并保证软件偏好重启后保留但不会恢复登录态。

**Architecture:** 软件设置状态提升到应用层，由 `SoftwareSettingsController + SoftwareSettingsService` 驱动 `MaterialApp` 的 `theme` / `darkTheme` / `themeMode` 与壳层布局偏好。主壳层通过全局工具入口打开 `SoftwareSettingsPage`，并在业务菜单切换时回写“上次停留模块”，所有软件偏好统一落本地 `shared_preferences`，完全独立于登录态。

**Tech Stack:** Flutter、Dart、`shared_preferences`、`flutter_test`、`integration_test`、现有 `MainShellPage` / `MainShellController` / `MainShellScaffold` / `MesClientApp`

---

> 所有 Flutter 命令默认在 `frontend/` 目录执行。

## 文件结构

### 新增文件

- `frontend/lib/features/settings/models/software_settings_models.dart`
  - 定义软件设置枚举、默认值与持久化模型
- `frontend/lib/features/settings/services/software_settings_service.dart`
  - 负责读取、保存、恢复默认软件偏好
- `frontend/lib/features/settings/presentation/software_settings_controller.dart`
  - 管理软件设置内存态、自动保存、保存状态提示
- `frontend/lib/features/settings/presentation/software_settings_page.dart`
  - 渲染软件设置双栏页面与设置控件
- `frontend/lib/features/settings/presentation/widgets/software_settings_preview_card.dart`
  - 渲染外观分区的主题/密度预览卡片
- `frontend/test/services/software_settings_service_test.dart`
  - 覆盖设置持久化、默认值、非法值回退
- `frontend/test/widgets/software_settings_controller_test.dart`
  - 覆盖 controller 的加载、更新、恢复默认、错误提示
- `frontend/test/widgets/software_settings_page_test.dart`
  - 覆盖设置页分区导航、控件交互、恢复默认、状态提示
- `frontend/integration_test/software_settings_flow_test.dart`
  - 覆盖“修改设置 -> 重建应用 -> 主题保留但仍显示登录页”的真实链路

### 修改文件

- `frontend/pubspec.yaml`
  - 新增 `shared_preferences`
- `frontend/lib/main.dart`
  - 应用启动预加载软件设置；`MaterialApp` 监听设置 controller
- `frontend/lib/features/shell/presentation/main_shell_state.dart`
  - 新增壳层工具页状态，如 `activeUtilityCode`
- `frontend/lib/features/shell/presentation/main_shell_controller.dart`
  - 接入软件设置 controller；支持记忆上次停留模块；支持打开/关闭软件设置
- `frontend/lib/features/shell/presentation/main_shell_page.dart`
  - 监听 `MainShellController + SoftwareSettingsController`；将软件设置页纳入内容区
- `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
  - 注册 `software_settings` 页面
- `frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart`
  - 增加“软件设置”全局入口；根据设置控制侧边栏默认展开/折叠
- `frontend/test/widget_test.dart`
  - 断言 `MesClientApp` 会读取并应用软件设置主题
- `frontend/test/widgets/app_bootstrap_page_test.dart`
  - 保持“启动直接进登录页”的断言，同时适配新 app 构造方式
- `frontend/test/widgets/main_shell_controller_test.dart`
  - 覆盖“记忆模块”和“打开工具页”行为
- `frontend/test/widgets/main_shell_scaffold_test.dart`
  - 覆盖“软件设置”入口与折叠侧边栏状态
- `frontend/test/widgets/main_shell_page_test.dart`
  - 维持主壳层回归场景，补一条“打开软件设置页”闭环

## 任务 1：接入 `shared_preferences`，实现软件设置模型与持久化服务

**Files:**
- Modify: `frontend/pubspec.yaml`
- Create: `frontend/lib/features/settings/models/software_settings_models.dart`
- Create: `frontend/lib/features/settings/services/software_settings_service.dart`
- Test: `frontend/test/services/software_settings_service_test.dart`

- [ ] **Step 1: 先写失败测试，固定默认值、恢复值与非法值回退行为**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';

void main() {
  test('load 在本地无配置时返回默认值', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SoftwareSettingsService(
      await SharedPreferences.getInstance(),
    );

    final settings = await service.load();

    expect(settings.themePreference, AppThemePreference.system);
    expect(settings.densityPreference, AppDensityPreference.comfortable);
    expect(
      settings.launchTargetPreference,
      AppLaunchTargetPreference.home,
    );
    expect(
      settings.sidebarPreference,
      AppSidebarPreference.expanded,
    );
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
    expect(
      settings.launchTargetPreference,
      AppLaunchTargetPreference.home,
    );
    expect(settings.sidebarPreference, AppSidebarPreference.expanded);
    expect(settings.lastVisitedPageCode, isNull);
  });
}
```

- [ ] **Step 2: 运行测试，确认因为依赖和文件都不存在而失败**

Run: `flutter test test/services/software_settings_service_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Package shared_preferences not found`

- [ ] **Step 3: 新增依赖并拉取包**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  http: ^1.5.0
  file_selector: ^1.0.3
  url_launcher: ^6.3.2
  path: ^1.9.1
  fl_chart: ^0.68.0
  web_socket_channel: ^3.0.1
  shared_preferences: ^2.5.3
```

Run: `flutter pub get`

Expected: 输出包含 `Got dependencies!`

- [ ] **Step 4: 实现设置模型与本地存储服务**

```dart
// frontend/lib/features/settings/models/software_settings_models.dart
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
```

```dart
// frontend/lib/features/settings/services/software_settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';

class SoftwareSettingsService {
  SoftwareSettingsService(this._preferences);

  static const _themeKey = 'software_settings.theme_preference';
  static const _densityKey = 'software_settings.density_preference';
  static const _launchTargetKey =
      'software_settings.launch_target_preference';
  static const _sidebarKey = 'software_settings.sidebar_preference';
  static const _lastVisitedPageKey =
      'software_settings.last_visited_page_code';

  final SharedPreferences _preferences;

  static Future<SoftwareSettingsService> create() async {
    return SoftwareSettingsService(await SharedPreferences.getInstance());
  }

  Future<SoftwareSettings> load() async {
    return SoftwareSettings(
      themePreference: _themeFromStorage(_preferences.getString(_themeKey)),
      densityPreference: _densityFromStorage(
        _preferences.getString(_densityKey),
      ),
      launchTargetPreference: _launchTargetFromStorage(
        _preferences.getString(_launchTargetKey),
      ),
      sidebarPreference: _sidebarFromStorage(
        _preferences.getString(_sidebarKey),
      ),
      lastVisitedPageCode: _normalizePageCode(
        _preferences.getString(_lastVisitedPageKey),
      ),
    );
  }

  Future<void> save(SoftwareSettings settings) async {
    await _preferences.setString(_themeKey, _themeToStorage(settings.themePreference));
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
    final pageCode = _normalizePageCode(settings.lastVisitedPageCode);
    if (pageCode == null) {
      await _preferences.remove(_lastVisitedPageKey);
    } else {
      await _preferences.setString(_lastVisitedPageKey, pageCode);
    }
  }

  Future<void> restoreDefaults() async {
    await save(const SoftwareSettings.defaults());
  }

  String? _normalizePageCode(String? value) {
    final normalized = value?.trim();
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  AppThemePreference _themeFromStorage(String? value) {
    switch (value) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  AppDensityPreference _densityFromStorage(String? value) {
    switch (value) {
      case 'compact':
        return AppDensityPreference.compact;
      default:
        return AppDensityPreference.comfortable;
    }
  }

  AppLaunchTargetPreference _launchTargetFromStorage(String? value) {
    switch (value) {
      case 'last_visited_module':
        return AppLaunchTargetPreference.lastVisitedModule;
      default:
        return AppLaunchTargetPreference.home;
    }
  }

  AppSidebarPreference _sidebarFromStorage(String? value) {
    switch (value) {
      case 'collapsed':
        return AppSidebarPreference.collapsed;
      default:
        return AppSidebarPreference.expanded;
    }
  }

  String _themeToStorage(AppThemePreference value) => switch (value) {
        AppThemePreference.system => 'system',
        AppThemePreference.light => 'light',
        AppThemePreference.dark => 'dark',
      };

  String _densityToStorage(AppDensityPreference value) => switch (value) {
        AppDensityPreference.comfortable => 'comfortable',
        AppDensityPreference.compact => 'compact',
      };

  String _launchTargetToStorage(AppLaunchTargetPreference value) =>
      switch (value) {
        AppLaunchTargetPreference.home => 'home',
        AppLaunchTargetPreference.lastVisitedModule =>
          'last_visited_module',
      };

  String _sidebarToStorage(AppSidebarPreference value) => switch (value) {
        AppSidebarPreference.expanded => 'expanded',
        AppSidebarPreference.collapsed => 'collapsed',
      };
}
```

- [ ] **Step 5: 运行服务测试，确认持久化逻辑通过**

Run: `flutter test test/services/software_settings_service_test.dart`

Expected: PASS，3 条测试全部通过

- [ ] **Step 6: 提交**

```bash
git add pubspec.yaml pubspec.lock lib/features/settings/models/software_settings_models.dart lib/features/settings/services/software_settings_service.dart test/services/software_settings_service_test.dart
git commit -m "新增软件设置模型与持久化服务"
```

## 任务 2：实现应用级设置控制器，并让 `MaterialApp` 跟随软件偏好

**Files:**
- Create: `frontend/lib/features/settings/presentation/software_settings_controller.dart`
- Modify: `frontend/lib/main.dart`
- Test: `frontend/test/widgets/software_settings_controller_test.dart`
- Modify: `frontend/test/widget_test.dart`
- Modify: `frontend/test/widgets/app_bootstrap_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定 controller 加载与 `MaterialApp.themeMode` 响应**

```dart
// frontend/test/widgets/software_settings_controller_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';

class _FakeSoftwareSettingsService extends SoftwareSettingsService {
  _FakeSoftwareSettingsService._(
    this._loaded,
    SharedPreferences preferences,
  ) : super(preferences);

  static Future<_FakeSoftwareSettingsService> create(
    SoftwareSettings loaded,
  ) async {
    SharedPreferences.setMockInitialValues({});
    return _FakeSoftwareSettingsService._(
      loaded,
      await SharedPreferences.getInstance(),
    );
  }

  final SoftwareSettings _loaded;
  SoftwareSettings? saved;

  @override
  Future<SoftwareSettings> load() async => _loaded;

  @override
  Future<void> save(SoftwareSettings settings) async {
    saved = settings;
  }
}

void main() {
  test('load 会把 service 返回值写入 controller', () async {
    final service = await _FakeSoftwareSettingsService.create(
      const SoftwareSettings(
        themePreference: AppThemePreference.dark,
        densityPreference: AppDensityPreference.compact,
        launchTargetPreference: AppLaunchTargetPreference.home,
        sidebarPreference: AppSidebarPreference.expanded,
      ),
    );
    final controller = SoftwareSettingsController(service: service);

    await controller.load();

    expect(controller.settings.themePreference, AppThemePreference.dark);
    expect(controller.settings.densityPreference, AppDensityPreference.compact);
    expect(controller.themeMode, ThemeMode.dark);
  });
}
```

```dart
// frontend/test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/main.dart';

void main() {
  testWidgets('MesClientApp 会按 controller 的主题模式渲染 MaterialApp', (
    tester,
  ) async {
    final controller = SoftwareSettingsController.memory(
      initialSettings: const SoftwareSettings(
        themePreference: AppThemePreference.dark,
        densityPreference: AppDensityPreference.comfortable,
        launchTargetPreference: AppLaunchTargetPreference.home,
        sidebarPreference: AppSidebarPreference.expanded,
      ),
    );

    await tester.pumpWidget(
      MesClientApp(softwareSettingsController: controller),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.locale, const Locale('zh', 'CN'));
    expect(
      app.localizationsDelegates,
      contains(GlobalMaterialLocalizations.delegate),
    );
  });
}
```

```dart
// frontend/test/widgets/app_bootstrap_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/main.dart';

void main() {
  testWidgets('应用启动后直接进入登录页而不是显示启动清理态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppBootstrapPage(
          softwareSettingsController: SoftwareSettingsController.memory(),
        ),
      ),
    );

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byKey(const Key('login-account-field')), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认因为 controller 文件和构造参数不存在而失败**

Run: `flutter test test/widgets/software_settings_controller_test.dart test/widget_test.dart test/widgets/app_bootstrap_page_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist`、`Undefined class 'SoftwareSettingsController'` 或 `No named parameter with the name 'softwareSettingsController'`

- [ ] **Step 3: 实现 controller，并将 `main.dart` 改为“启动时加载设置 -> runApp”**

```dart
// frontend/lib/features/settings/presentation/software_settings_controller.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';

class SoftwareSettingsController extends ChangeNotifier {
  SoftwareSettingsController({required SoftwareSettingsService service})
    : _service = service;

  SoftwareSettingsController.memory({
    SoftwareSettings initialSettings = const SoftwareSettings.defaults(),
  }) : _service = null,
       _settings = initialSettings,
       _loaded = true;

  final SoftwareSettingsService? _service;
  SoftwareSettings _settings = const SoftwareSettings.defaults();
  bool _loaded = false;
  String? _saveMessage;
  bool _saveFailed = false;

  SoftwareSettings get settings => _settings;
  bool get loaded => _loaded;
  String? get saveMessage => _saveMessage;
  bool get saveFailed => _saveFailed;

  ThemeMode get themeMode => switch (_settings.themePreference) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };

  VisualDensity get visualDensity => switch (_settings.densityPreference) {
        AppDensityPreference.comfortable => VisualDensity.standard,
        AppDensityPreference.compact => VisualDensity.compact,
      };

  Future<void> load() async {
    if (_service == null) {
      return;
    }
    _settings = await _service!.load();
    _loaded = true;
    _saveMessage = null;
    _saveFailed = false;
    notifyListeners();
  }

  Future<void> updateThemePreference(AppThemePreference value) async {
    await _persist(_settings.copyWith(themePreference: value));
  }

  Future<void> updateDensityPreference(AppDensityPreference value) async {
    await _persist(_settings.copyWith(densityPreference: value));
  }

  Future<void> updateLaunchTargetPreference(
    AppLaunchTargetPreference value,
  ) async {
    await _persist(_settings.copyWith(launchTargetPreference: value));
  }

  Future<void> updateSidebarPreference(AppSidebarPreference value) async {
    await _persist(_settings.copyWith(sidebarPreference: value));
  }

  Future<void> rememberLastVisitedPageCode(String? pageCode) async {
    await _persist(
      _settings.copyWith(
        lastVisitedPageCode: pageCode,
        clearLastVisitedPageCode: pageCode == null,
      ),
      showSuccessMessage: false,
    );
  }

  Future<void> restoreDefaults() async {
    await _persist(const SoftwareSettings.defaults());
  }

  Future<void> _persist(
    SoftwareSettings next, {
    bool showSuccessMessage = true,
  }) async {
    _settings = next;
    if (_service == null) {
      _saveFailed = false;
      _saveMessage = showSuccessMessage ? '已自动保存' : null;
      notifyListeners();
      return;
    }
    notifyListeners();
    try {
      await _service!.save(next);
      _saveFailed = false;
      _saveMessage = showSuccessMessage ? '已自动保存' : null;
    } catch (_) {
      _saveFailed = true;
      _saveMessage = '设置保存失败，本次重启后可能不会保留';
    }
    notifyListeners();
  }
}
```

```dart
// frontend/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/misc/presentation/force_change_password_page.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page.dart';
import 'package:mes_client/core/models/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsService = await SoftwareSettingsService.create();
  final settingsController = SoftwareSettingsController(
    service: settingsService,
  );
  await settingsController.load();
  runApp(MesClientApp(softwareSettingsController: settingsController));
}

class MesClientApp extends StatelessWidget {
  MesClientApp({super.key, required this.softwareSettingsController});

  final SoftwareSettingsController softwareSettingsController;

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A67),
        brightness: brightness,
      ),
      brightness: brightness,
      useMaterial3: true,
      visualDensity: softwareSettingsController.visualDensity,
      fontFamily: 'Microsoft YaHei',
      fontFamilyFallback: const [
        '微软雅黑',
        'Microsoft YaHei',
        'PingFang SC',
        'Noto Sans CJK SC',
        'sans-serif',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: softwareSettingsController,
      builder: (context, _) {
        return MaterialApp(
          title: 'ZYKJ MES 系统',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN')],
          locale: const Locale('zh', 'CN'),
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: softwareSettingsController.themeMode,
          home: AppBootstrapPage(
            softwareSettingsController: softwareSettingsController,
          ),
        );
      },
    );
  }
}

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key, required this.softwareSettingsController});

  final SoftwareSettingsController softwareSettingsController;

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

// frontend/lib/main.dart 中 _AppBootstrapPageState.build
@override
Widget build(BuildContext context) {
  if (_session == null) {
    return LoginPage(
      onLoginSuccess: _handleLoginSuccess,
      initialMessage: _loginNotice,
    );
  }

  if (_session!.mustChangePassword) {
    return ForceChangePasswordPage(
      session: _session!,
      onRequireRelogin: _handleForcePasswordChanged,
    );
  }

  return MainShellPage(
    session: _session!,
    onLogout: _handleLogout,
    softwareSettingsController: widget.softwareSettingsController,
  );
}
```

- [ ] **Step 4: 运行入口与 controller 测试，确认主题接入成功**

Run: `flutter test test/widgets/software_settings_controller_test.dart test/widget_test.dart test/widgets/app_bootstrap_page_test.dart`

Expected: PASS，`MaterialApp.themeMode` 可由 controller 控制，且应用启动后仍直接显示登录页

- [ ] **Step 5: 提交**

```bash
git add lib/main.dart lib/features/settings/presentation/software_settings_controller.dart test/widgets/software_settings_controller_test.dart test/widget_test.dart test/widgets/app_bootstrap_page_test.dart
git commit -m "接入应用级软件设置控制器"
```

## 任务 3：把软件设置接入主壳层，全局入口生效并记忆上次停留模块

**Files:**
- Modify: `frontend/lib/features/shell/presentation/main_shell_state.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_controller.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
- Modify: `frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart`
- Create: `frontend/lib/features/settings/presentation/software_settings_page.dart`
- Modify: `frontend/test/widgets/main_shell_controller_test.dart`
- Modify: `frontend/test/widgets/main_shell_scaffold_test.dart`
- Modify: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定工具入口、记忆模块和工具页切换行为**

```dart
// test/widgets/main_shell_controller_test.dart
test('initialize 在默认进入策略为上次停留模块时落到记忆菜单', () async {
  final settingsController = SoftwareSettingsController.memory(
    initialSettings: const SoftwareSettings(
      themePreference: AppThemePreference.system,
      densityPreference: AppDensityPreference.comfortable,
      launchTargetPreference: AppLaunchTargetPreference.lastVisitedModule,
      sidebarPreference: AppSidebarPreference.expanded,
      lastVisitedPageCode: 'quality',
    ),
  );
  final controller = _buildController(
    softwareSettingsController: settingsController,
  );

  await controller.initialize();

  expect(controller.state.selectedPageCode, 'quality');
});

test('openSoftwareSettings 会打开工具页，选择业务菜单会关闭工具页', () async {
  final controller = _buildController();
  await controller.initialize();

  controller.openSoftwareSettings();
  expect(controller.state.activeUtilityCode, 'software_settings');

  controller.selectMenu('user');
  expect(controller.state.activeUtilityCode, isNull);
  expect(controller.state.selectedPageCode, 'user');
});
```

```dart
// test/widgets/main_shell_scaffold_test.dart
expect(find.text('软件设置'), findsOneWidget);
```

```dart
// test/widgets/main_shell_page_test.dart
testWidgets('点击软件设置入口后会显示软件设置页', (tester) async {
  await _pumpMainShellPage(
    tester,
    softwareSettingsController: SoftwareSettingsController.memory(),
  );

  await tester.tap(find.text('软件设置'));
  await tester.pumpAndSettle();

  expect(find.text('控制本机软件的外观和布局偏好。'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试，确认因为壳层尚未接入设置入口与状态而失败**

Run: `flutter test test/widgets/main_shell_controller_test.dart test/widgets/main_shell_scaffold_test.dart test/widgets/main_shell_page_test.dart`

Expected: FAIL，报错包含 `activeUtilityCode` 不存在、`openSoftwareSettings` 不存在，或页面中找不到 `软件设置`

- [ ] **Step 3: 实现壳层入口、工具页切换和“上次停留模块”回写**

```dart
// frontend/lib/features/shell/presentation/main_shell_state.dart
const Object _mainShellUnset = Object();

class MainShellViewState {
  const MainShellViewState({
    this.loading = true,
    this.message = '',
    this.messageRefreshTick = 0,
    this.currentUser,
    this.authzSnapshot,
    this.catalog = fallbackPageCatalog,
    this.tabCodesByParent = const {},
    this.menus = const [],
    this.selectedPageCode = 'home',
    this.activeUtilityCode,
    this.unreadCount = 0,
    this.preferredTabCode,
    this.preferredRoutePayloadJson,
    this.manualRefreshing = false,
    this.homeDashboardLoading = false,
    this.homeDashboardRefreshPending = false,
    this.lastManualRefreshAt,
    this.homeDashboardData,
  });

  final bool loading;
  final String message;
  final int messageRefreshTick;
  final CurrentUser? currentUser;
  final AuthzSnapshotResult? authzSnapshot;
  final List<PageCatalogItem> catalog;
  final Map<String, List<String>> tabCodesByParent;
  final List<MainShellMenuItem> menus;
  final String selectedPageCode;
  final String? activeUtilityCode;
  final int unreadCount;
  final String? preferredTabCode;
  final String? preferredRoutePayloadJson;
  final bool manualRefreshing;
  final bool homeDashboardLoading;
  final bool homeDashboardRefreshPending;
  final DateTime? lastManualRefreshAt;
  final HomeDashboardData? homeDashboardData;

  MainShellViewState copyWith({
    bool? loading,
    String? message,
    int? messageRefreshTick,
    Object? currentUser = _mainShellUnset,
    Object? authzSnapshot = _mainShellUnset,
    List<PageCatalogItem>? catalog,
    Map<String, List<String>>? tabCodesByParent,
    List<MainShellMenuItem>? menus,
    String? selectedPageCode,
    Object? activeUtilityCode = _mainShellUnset,
    int? unreadCount,
    Object? preferredTabCode = _mainShellUnset,
    Object? preferredRoutePayloadJson = _mainShellUnset,
    bool? manualRefreshing,
    bool? homeDashboardLoading,
    bool? homeDashboardRefreshPending,
    Object? lastManualRefreshAt = _mainShellUnset,
    Object? homeDashboardData = _mainShellUnset,
  }) {
    return MainShellViewState(
      loading: loading ?? this.loading,
      message: message ?? this.message,
      messageRefreshTick: messageRefreshTick ?? this.messageRefreshTick,
      currentUser: currentUser == _mainShellUnset
          ? this.currentUser
          : currentUser as CurrentUser?,
      authzSnapshot: authzSnapshot == _mainShellUnset
          ? this.authzSnapshot
          : authzSnapshot as AuthzSnapshotResult?,
      catalog: catalog ?? this.catalog,
      tabCodesByParent: tabCodesByParent ?? this.tabCodesByParent,
      menus: menus ?? this.menus,
      selectedPageCode: selectedPageCode ?? this.selectedPageCode,
      activeUtilityCode: activeUtilityCode == _mainShellUnset
          ? this.activeUtilityCode
          : activeUtilityCode as String?,
      unreadCount: unreadCount ?? this.unreadCount,
      preferredTabCode: preferredTabCode == _mainShellUnset
          ? this.preferredTabCode
          : preferredTabCode as String?,
      preferredRoutePayloadJson:
          preferredRoutePayloadJson == _mainShellUnset
          ? this.preferredRoutePayloadJson
          : preferredRoutePayloadJson as String?,
      manualRefreshing: manualRefreshing ?? this.manualRefreshing,
      homeDashboardLoading:
          homeDashboardLoading ?? this.homeDashboardLoading,
      homeDashboardRefreshPending:
          homeDashboardRefreshPending ?? this.homeDashboardRefreshPending,
      lastManualRefreshAt: lastManualRefreshAt == _mainShellUnset
          ? this.lastManualRefreshAt
          : lastManualRefreshAt as DateTime?,
      homeDashboardData: homeDashboardData == _mainShellUnset
          ? this.homeDashboardData
          : homeDashboardData as HomeDashboardData?,
    );
  }
}
```

```dart
// frontend/lib/features/shell/presentation/main_shell_controller.dart
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';

class MainShellController extends ChangeNotifier {
  MainShellController({
    required this.session,
    required this.onLogout,
    required AuthService authService,
    required AuthzService authzService,
    required PageCatalogService pageCatalogService,
    required MessageService messageService,
    required HomeDashboardService homeDashboardService,
    required MessageWsService Function({
      required String baseUrl,
      required String accessToken,
      required WsEventCallback onEvent,
      required void Function() onDisconnected,
    })
    messageWsServiceFactory,
    SoftwareSettingsController? softwareSettingsController,
  }) : _softwareSettingsController =
           softwareSettingsController ??
           SoftwareSettingsController.memory(),
       _authService = authService,
       _authzService = authzService,
       _pageCatalogService = pageCatalogService,
       _messageService = messageService,
       _homeDashboardService = homeDashboardService,
       _messageWsServiceFactory = messageWsServiceFactory;

  final SoftwareSettingsController _softwareSettingsController;

  // 在 refreshVisibility 中，把页面选择逻辑替换为下面这段：
  var selectedPageCode = _state.selectedPageCode;
  final rememberedPage =
      _softwareSettingsController.settings.lastVisitedPageCode;
  final launchTarget =
      _softwareSettingsController.settings.launchTargetPreference;
  final canRestoreRememberedPage =
      launchTarget == AppLaunchTargetPreference.lastVisitedModule &&
      rememberedPage != null &&
      menus.any((item) => item.code == rememberedPage);

  if (menus.isEmpty) {
    selectedPageCode = 'home';
    preferredTabCode = null;
    preferredRoutePayloadJson = null;
  } else if (_state.selectedPageCode == 'home' && canRestoreRememberedPage) {
    selectedPageCode = rememberedPage;
    preferredTabCode = null;
    preferredRoutePayloadJson = null;
  } else if (!menus.any((item) => item.code == selectedPageCode)) {
    selectedPageCode =
        canRestoreRememberedPage ? rememberedPage : menus.first.code;
    preferredTabCode = null;
    preferredRoutePayloadJson = null;
    if (!canRestoreRememberedPage) {
      message = '当前页面权限已变更，已切换到${menus.first.title}';
    }
  }

  void openSoftwareSettings() {
    _setState(_state.copyWith(activeUtilityCode: 'software_settings'));
  }

  void selectMenu(String pageCode) {
    if (_state.selectedPageCode == pageCode &&
        _state.activeUtilityCode == null) {
      return;
    }
    navigateToPageTarget(pageCode: pageCode);
  }

  bool navigateToPageTarget({
    required String pageCode,
    String? tabCode,
    String? routePayloadJson,
  }) {
    final result = resolveMainShellTarget(
      requestedPageCode: pageCode,
      requestedTabCode: tabCode,
      requestedRoutePayloadJson: routePayloadJson,
      catalog: _state.catalog,
      menus: _state.menus,
    );
    if (!result.hasAccess) {
      return false;
    }
    _setState(
      _state.copyWith(
        selectedPageCode: result.pageCode,
        activeUtilityCode: null,
        preferredTabCode: result.tabCode,
        preferredRoutePayloadJson: result.routePayloadJson,
      ),
    );
    if (result.pageCode != 'home') {
      _softwareSettingsController.rememberLastVisitedPageCode(result.pageCode);
    }
    return true;
  }
}
```

```dart
// frontend/lib/features/shell/presentation/main_shell_page_registry.dart
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/software_settings_page.dart';

required SoftwareSettingsController softwareSettingsController,

case 'software_settings':
  return SoftwareSettingsPage(controller: softwareSettingsController);
```

```dart
// frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart
class MainShellScaffold extends StatelessWidget {
  const MainShellScaffold({
    super.key,
    required this.state,
    required this.currentUserDisplayName,
    required this.content,
    required this.onSelectMenu,
    required this.onOpenSoftwareSettings,
    required this.onLogout,
    required this.onRetry,
    required this.showNoAccessPage,
    required this.showErrorPage,
    required this.sidebarCollapsed,
  });

  final VoidCallback onOpenSoftwareSettings;
  final bool sidebarCollapsed;

  @override
  Widget build(BuildContext context) {
    if (showErrorPage) {
      return Scaffold(body: _buildErrorPage(context));
    }
    if (showNoAccessPage) {
      return Scaffold(body: _buildNoAccessPage(context));
    }

    final theme = Theme.of(context);
    final selectedMenuCode = state.menus
        .where((item) => item.code == state.selectedPageCode)
        .map((item) => item.code)
        .firstOrNull ??
        state.menus.first.code;
    final contentKey = state.activeUtilityCode ?? selectedMenuCode;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: sidebarCollapsed ? 88 : 240,
            color: theme.colorScheme.surfaceContainerHighest,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZYKJ MES',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUserDisplayName,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.menus.length,
                      itemBuilder: (context, index) {
                        final menu = state.menus[index];
                        final selected = menu.code == selectedMenuCode;
                        final isMessage = menu.code == 'message';
                        return ListTile(
                          key: ValueKey('main-shell-menu-${menu.code}'),
                          selected: selected,
                          leading: isMessage && state.unreadCount > 0
                              ? Badge(
                                  label: Text(
                                    state.unreadCount > 99
                                        ? '99+'
                                        : '${state.unreadCount}',
                                  ),
                                  child: Icon(menu.icon),
                                )
                              : Icon(menu.icon),
                          title: sidebarCollapsed ? null : Text(menu.title),
                          onTap: () => onSelectMenu(menu.code),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: sidebarCollapsed ? null : const Text('软件设置'),
                    selected: state.activeUtilityCode == 'software_settings',
                    onTap: onOpenSoftwareSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: sidebarCollapsed ? null : const Text('退出登录'),
                    onTap: onLogout,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  if (state.message.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: theme.colorScheme.surfaceContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        state.message,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  Expanded(
                    child: Container(
                      key: ValueKey('main-shell-content-$contentKey'),
                      child: content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/settings/presentation/software_settings_page.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';

class SoftwareSettingsPage extends StatefulWidget {
  const SoftwareSettingsPage({
    super.key,
    required this.controller,
  });

  final SoftwareSettingsController controller;

  @override
  State<SoftwareSettingsPage> createState() => _SoftwareSettingsPageState();
}

class _SoftwareSettingsPageState extends State<SoftwareSettingsPage> {
  String _sectionCode = 'appearance';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final settings = widget.controller.settings;
        return Row(
          children: [
            Container(
              width: 220,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    selected: _sectionCode == 'appearance',
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('外观'),
                    onTap: () => setState(() => _sectionCode = 'appearance'),
                  ),
                  ListTile(
                    selected: _sectionCode == 'layout',
                    leading: const Icon(Icons.view_sidebar_outlined),
                    title: const Text('布局偏好'),
                    onTap: () => setState(() => _sectionCode = 'layout'),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('软件设置', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  if (_sectionCode == 'appearance') ...[
                    RadioListTile<AppThemePreference>(
                      value: AppThemePreference.system,
                      groupValue: settings.themePreference,
                      title: const Text('跟随系统'),
                      onChanged: (value) {
                        if (value != null) {
                          widget.controller.updateThemePreference(value);
                        }
                      },
                    ),
                    RadioListTile<AppThemePreference>(
                      value: AppThemePreference.light,
                      groupValue: settings.themePreference,
                      title: const Text('浅色'),
                      onChanged: (value) {
                        if (value != null) {
                          widget.controller.updateThemePreference(value);
                        }
                      },
                    ),
                    RadioListTile<AppThemePreference>(
                      value: AppThemePreference.dark,
                      groupValue: settings.themePreference,
                      title: const Text('深色'),
                      onChanged: (value) {
                        if (value != null) {
                          widget.controller.updateThemePreference(value);
                        }
                      },
                    ),
                  ] else ...[
                    RadioListTile<AppLaunchTargetPreference>(
                      value: AppLaunchTargetPreference.home,
                      groupValue: settings.launchTargetPreference,
                      title: const Text('启动后默认进入首页'),
                      onChanged: (value) {
                        if (value != null) {
                          widget.controller.updateLaunchTargetPreference(value);
                        }
                      },
                    ),
                    RadioListTile<AppLaunchTargetPreference>(
                      value: AppLaunchTargetPreference.lastVisitedModule,
                      groupValue: settings.launchTargetPreference,
                      title: const Text('启动后默认进入上次停留模块'),
                      onChanged: (value) {
                        if (value != null) {
                          widget.controller.updateLaunchTargetPreference(value);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
```

```dart
// frontend/lib/features/shell/presentation/main_shell_page.dart
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';

final SoftwareSettingsController? softwareSettingsController;

late final SoftwareSettingsController _softwareSettingsController;

_softwareSettingsController =
    widget.softwareSettingsController ?? SoftwareSettingsController.memory();

_controller = MainShellController(
  session: widget.session,
  onLogout: widget.onLogout,
  authService: authService,
  authzService: authzService,
  pageCatalogService: pageCatalogService,
  messageService: messageService,
  homeDashboardService: homeDashboardService,
  messageWsServiceFactory:
      widget.messageWsServiceFactory ??
      ({
        required String baseUrl,
        required String accessToken,
        required WsEventCallback onEvent,
        required void Function() onDisconnected,
      }) {
        return MessageWsService(
          baseUrl: baseUrl,
          accessToken: accessToken,
          onEvent: onEvent,
          onDisconnected: onDisconnected,
        );
      },
  softwareSettingsController: _softwareSettingsController,
);

return _pageRegistry.build(
  pageCode: pageCode,
  session: widget.session,
  state: _controller.state,
  onLogout: widget.onLogout,
  onRefreshShellData: _controller.refreshShellDataFromUi,
  onNavigateToPageTarget: ({
    required String pageCode,
    String? tabCode,
    String? routePayloadJson,
  }) {
    _navigateToPageTarget(
      pageCode: pageCode,
      tabCode: tabCode,
      routePayloadJson: routePayloadJson,
    );
  },
  onVisibilityConfigSaved: () {
    unawaited(_controller.refreshVisibility(loadCatalog: false));
  },
  onUnreadCountChanged: _controller.updateUnreadCount,
  messageService: _controller.messageService,
  softwareSettingsController: _softwareSettingsController,
  homeRefreshStatusText: _controller.homeRefreshStatusText(),
  userPageBuilder: widget.userPageBuilder,
  productPageBuilder: widget.productPageBuilder,
  equipmentPageBuilder: widget.equipmentPageBuilder,
  productionPageBuilder: widget.productionPageBuilder,
  qualityPageBuilder: widget.qualityPageBuilder,
  craftPageBuilder: widget.craftPageBuilder,
);

return AnimatedBuilder(
  animation: Listenable.merge([
    _controller,
    _softwareSettingsController,
  ]),
  builder: (context, _) {
    final state = _controller.state;
    final selectedMenuCode = state.menus
        .where((item) => item.code == state.selectedPageCode)
        .map((item) => item.code)
        .firstOrNull ??
        (state.menus.isEmpty ? 'home' : state.menus.first.code);
    final contentPageCode = state.activeUtilityCode ?? selectedMenuCode;

    return MainShellScaffold(
      state: state,
      currentUserDisplayName: state.currentUser?.displayName ?? '',
      content: showErrorPage || showNoAccessPage
          ? const SizedBox.shrink()
          : _buildContent(contentPageCode),
      onSelectMenu: _controller.selectMenu,
      onOpenSoftwareSettings: _controller.openSoftwareSettings,
      onLogout: widget.onLogout,
      onRetry: () {
        unawaited(_handleRetry());
      },
      showNoAccessPage: showNoAccessPage,
      showErrorPage: showErrorPage,
      sidebarCollapsed:
          _softwareSettingsController.settings.sidebarPreference ==
          AppSidebarPreference.collapsed,
    );
  },
);
```

- [ ] **Step 4: 运行壳层相关测试，确认入口、记忆模块和工具页切换全部通过**

Run: `flutter test test/widgets/main_shell_controller_test.dart test/widgets/main_shell_scaffold_test.dart test/widgets/main_shell_page_test.dart`

Expected: PASS，能够看到“软件设置”入口，且在“上次停留模块”策略下会落到记忆菜单

- [ ] **Step 5: 提交**

```bash
git add lib/features/shell/presentation/main_shell_state.dart lib/features/shell/presentation/main_shell_controller.dart lib/features/shell/presentation/main_shell_page.dart lib/features/shell/presentation/main_shell_page_registry.dart lib/features/shell/presentation/widgets/main_shell_scaffold.dart lib/features/settings/presentation/software_settings_page.dart test/widgets/main_shell_controller_test.dart test/widgets/main_shell_scaffold_test.dart test/widgets/main_shell_page_test.dart
git commit -m "接入软件设置全局入口与壳层联动"
```

## 任务 4：完善软件设置页 UI、预览卡片、恢复默认与页面级 widget 测试

**Files:**
- Modify: `frontend/lib/features/settings/presentation/software_settings_page.dart`
- Create: `frontend/lib/features/settings/presentation/widgets/software_settings_preview_card.dart`
- Test: `frontend/test/widgets/software_settings_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定双栏导航、恢复默认、状态提示和预览行为**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/software_settings_page.dart';

void main() {
  testWidgets('SoftwareSettingsPage 渲染外观与布局偏好两个分区', (tester) async {
    final controller = SoftwareSettingsController.memory();

    await tester.pumpWidget(
      MaterialApp(home: SoftwareSettingsPage(controller: controller)),
    );

    expect(find.text('软件设置'), findsOneWidget);
    expect(find.text('外观'), findsWidgets);
    expect(find.text('布局偏好'), findsWidgets);
    expect(find.text('恢复默认'), findsOneWidget);
  });

  testWidgets('切换深色与紧凑密度后会更新预览卡片', (tester) async {
    final controller = SoftwareSettingsController.memory();

    await tester.pumpWidget(
      MaterialApp(home: SoftwareSettingsPage(controller: controller)),
    );

    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('紧凑').last);
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
        lastVisitedPageCode: 'quality',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: SoftwareSettingsPage(controller: controller)),
    );

    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();

    expect(controller.settings, const SoftwareSettings.defaults());
    expect(find.text('已自动保存'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认因为页面未实现完整字段与预览而失败**

Run: `flutter test test/widgets/software_settings_page_test.dart`

Expected: FAIL，报错包含找不到 `恢复默认`、`当前主题：深色` 或 `当前密度：紧凑`

- [ ] **Step 3: 实现完整页面、恢复默认按钮和预览卡片**

```dart
// frontend/lib/features/settings/presentation/widgets/software_settings_preview_card.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';

class SoftwareSettingsPreviewCard extends StatelessWidget {
  const SoftwareSettingsPreviewCard({
    super.key,
    required this.themePreference,
    required this.densityPreference,
  });

  final AppThemePreference themePreference;
  final AppDensityPreference densityPreference;

  @override
  Widget build(BuildContext context) {
    final themeLabel = switch (themePreference) {
      AppThemePreference.system => '跟随系统',
      AppThemePreference.light => '浅色',
      AppThemePreference.dark => '深色',
    };
    final densityLabel = switch (densityPreference) {
      AppDensityPreference.comfortable => '舒适',
      AppDensityPreference.compact => '紧凑',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('实时预览', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('当前主题：$themeLabel'),
            Text('当前密度：$densityLabel'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                Chip(label: Text('示例标签')),
                FilledButton(onPressed: null, child: Text('示例按钮')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/settings/presentation/software_settings_page.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/widgets/software_settings_preview_card.dart';

class SoftwareSettingsPage extends StatefulWidget {
  const SoftwareSettingsPage({super.key, required this.controller});

  final SoftwareSettingsController controller;

  @override
  State<SoftwareSettingsPage> createState() => _SoftwareSettingsPageState();
}

class _SoftwareSettingsPageState extends State<SoftwareSettingsPage> {
  String _sectionCode = 'appearance';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final settings = widget.controller.settings;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                child: Card(
                  child: Column(
                    children: [
                      ListTile(
                        selected: _sectionCode == 'appearance',
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text('外观'),
                        onTap: () => setState(() => _sectionCode = 'appearance'),
                      ),
                      ListTile(
                        selected: _sectionCode == 'layout',
                        leading: const Icon(Icons.view_sidebar_outlined),
                        title: const Text('布局偏好'),
                        onTap: () => setState(() => _sectionCode = 'layout'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '软件设置',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              const Text('控制本机软件的外观和布局偏好。'),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: widget.controller.restoreDefaults,
                          child: const Text('恢复默认'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (widget.controller.saveMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.controller.saveFailed
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(widget.controller.saveMessage!),
                      ),
                    const SizedBox(height: 16),
                    if (_sectionCode == 'appearance') ...[
                      RadioListTile<AppThemePreference>(
                        value: AppThemePreference.system,
                        groupValue: settings.themePreference,
                        title: const Text('跟随系统'),
                        onChanged: (value) => widget.controller.updateThemePreference(value!),
                      ),
                      RadioListTile<AppThemePreference>(
                        value: AppThemePreference.light,
                        groupValue: settings.themePreference,
                        title: const Text('浅色'),
                        onChanged: (value) => widget.controller.updateThemePreference(value!),
                      ),
                      RadioListTile<AppThemePreference>(
                        value: AppThemePreference.dark,
                        groupValue: settings.themePreference,
                        title: const Text('深色'),
                        onChanged: (value) => widget.controller.updateThemePreference(value!),
                      ),
                      RadioListTile<AppDensityPreference>(
                        value: AppDensityPreference.comfortable,
                        groupValue: settings.densityPreference,
                        title: const Text('舒适'),
                        onChanged: (value) => widget.controller.updateDensityPreference(value!),
                      ),
                      RadioListTile<AppDensityPreference>(
                        value: AppDensityPreference.compact,
                        groupValue: settings.densityPreference,
                        title: const Text('紧凑'),
                        onChanged: (value) => widget.controller.updateDensityPreference(value!),
                      ),
                      const SizedBox(height: 16),
                      SoftwareSettingsPreviewCard(
                        themePreference: settings.themePreference,
                        densityPreference: settings.densityPreference,
                      ),
                    ] else ...[
                      RadioListTile<AppLaunchTargetPreference>(
                        value: AppLaunchTargetPreference.home,
                        groupValue: settings.launchTargetPreference,
                        title: const Text('启动后默认进入首页'),
                        onChanged: (value) => widget.controller.updateLaunchTargetPreference(value!),
                      ),
                      RadioListTile<AppLaunchTargetPreference>(
                        value: AppLaunchTargetPreference.lastVisitedModule,
                        groupValue: settings.launchTargetPreference,
                        title: const Text('启动后默认进入上次停留模块'),
                        onChanged: (value) => widget.controller.updateLaunchTargetPreference(value!),
                      ),
                      RadioListTile<AppSidebarPreference>(
                        value: AppSidebarPreference.expanded,
                        groupValue: settings.sidebarPreference,
                        title: const Text('展开'),
                        onChanged: (value) => widget.controller.updateSidebarPreference(value!),
                      ),
                      RadioListTile<AppSidebarPreference>(
                        value: AppSidebarPreference.collapsed,
                        groupValue: settings.sidebarPreference,
                        title: const Text('折叠'),
                        onChanged: (value) => widget.controller.updateSidebarPreference(value!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 运行页面级 widget 测试，确认设置页交互完整**

Run: `flutter test test/widgets/software_settings_page_test.dart test/widgets/software_settings_controller_test.dart`

Expected: PASS，能够切换外观、布局偏好并看到恢复默认与预览文案

- [ ] **Step 5: 提交**

```bash
git add lib/features/settings/presentation/software_settings_page.dart lib/features/settings/presentation/widgets/software_settings_preview_card.dart test/widgets/software_settings_page_test.dart
git commit -m "完成软件设置页界面与交互"
```

## 任务 5：补集成验证，确认设置持久化但不会恢复登录态

**Files:**
- Create: `frontend/integration_test/software_settings_flow_test.dart`
- Modify: `frontend/test/widgets/main_shell_page_test.dart`

- [ ] **Step 1: 先写失败的 integration test，固定“重启后主题保留但仍显示登录页”**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page.dart';
import 'package:mes_client/features/shell/services/home_dashboard_service.dart';
import 'package:mes_client/core/services/page_catalog_service.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('软件设置修改后重建应用仍保留主题，但不会恢复登录态', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final firstService = SoftwareSettingsService(
      await SharedPreferences.getInstance(),
    );
    final firstController = SoftwareSettingsController(service: firstService);
    await firstController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: MainShellPage(
          session: const AppSession(
            baseUrl: 'http://example.test/api/v1',
            accessToken: 'token',
          ),
          onLogout: () {},
          softwareSettingsController: firstController,
          authService: _FakeAuthService(),
          authzService: _FakeAuthzService(),
          pageCatalogService: _FakePageCatalogService(),
          messageService: _FakeMessageService(),
          homeDashboardService: _FakeHomeDashboardService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('软件设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();

    expect(firstController.settings.themePreference, AppThemePreference.dark);

    final secondService = SoftwareSettingsService(
      await SharedPreferences.getInstance(),
    );
    final secondController = SoftwareSettingsController(service: secondService);
    await secondController.load();

    await tester.pumpWidget(
      MesClientApp(softwareSettingsController: secondController),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行 integration test，确认在完整链路下仍有缺口时先失败**

Run: `flutter test integration_test/software_settings_flow_test.dart`

Expected: FAIL，通常会落在“找不到软件设置入口”“主题未保留”或“MainShellPage 缺少 settings 注入”之一

- [ ] **Step 3: 补齐最后的回归缺口，并给主壳层补一条回归测试**

```dart
// frontend/test/widgets/main_shell_page_test.dart
testWidgets('主壳层可打开软件设置页并渲染设置标题', (tester) async {
  final settingsController = SoftwareSettingsController.memory();

  await _pumpMainShellPage(
    tester,
    softwareSettingsController: settingsController,
  );

  await tester.tap(find.text('软件设置'));
  await tester.pumpAndSettle();

  expect(find.text('软件设置'), findsWidgets);
  expect(find.text('外观'), findsWidgets);
});
```

如果 integration test 暴露的是主题或持久化时序问题，优先修正：

```dart
// main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsService = await SoftwareSettingsService.create();
  final settingsController = SoftwareSettingsController(service: settingsService);
  await settingsController.load();
  runApp(MesClientApp(softwareSettingsController: settingsController));
}
```

- [ ] **Step 4: 跑完整验证，确认设置页功能、壳层回归和集成链路全部通过**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test test/services/software_settings_service_test.dart test/widgets/software_settings_controller_test.dart test/widgets/software_settings_page_test.dart test/widget_test.dart test/widgets/app_bootstrap_page_test.dart test/widgets/login_page_test.dart test/widgets/main_shell_controller_test.dart test/widgets/main_shell_scaffold_test.dart test/widgets/main_shell_page_test.dart`

Expected: PASS

Run: `flutter test integration_test/software_settings_flow_test.dart`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add integration_test/software_settings_flow_test.dart test/widgets/main_shell_page_test.dart
git commit -m "补充软件设置页验证用例"
```

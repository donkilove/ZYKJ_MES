import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/config/runtime_endpoints.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/software_settings_page.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    SoftwareSettingsController controller, {
    TimeSyncController? timeSyncController,
    double? contentWidth,
  }) async {
    final effectiveTimeSyncController =
        timeSyncController ?? _buildTimeSyncController(controller);
    Widget page = SoftwareSettingsPage(
      controller: controller,
      timeSyncController: effectiveTimeSyncController,
      apiBaseUrl: defaultApiBaseUrl,
    );
    if (contentWidth != null) {
      page = Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: contentWidth, height: 900, child: page),
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SoftwareSettingsPage 渲染外观与布局偏好两个分区', (tester) async {
    final controller = SoftwareSettingsController.memory();

    await pumpPage(tester, controller);

    expect(find.text('外观'), findsWidgets);
    expect(find.text('布局偏好'), findsWidgets);
    expect(find.text('时间同步'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, '恢复默认'), findsOneWidget);
  });

  testWidgets('切换深色与紧凑密度后会更新预览卡片', (tester) async {
    final controller = SoftwareSettingsController.memory();

    await pumpPage(tester, controller);
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('紧凑'));
    await tester.pumpAndSettle();

    expect(controller.settings.themePreference, AppThemePreference.dark);
    expect(controller.settings.densityPreference, AppDensityPreference.compact);
    expect(find.text('当前主题：深色'), findsOneWidget);
    expect(find.text('当前密度：紧凑'), findsOneWidget);
  });

  testWidgets('恢复默认会清回默认值并展示真实成功提示', (tester) async {
    final controller = SoftwareSettingsController.memory(
      initialSettings: const SoftwareSettings(
        themePreference: AppThemePreference.dark,
        densityPreference: AppDensityPreference.compact,
        launchTargetPreference: AppLaunchTargetPreference.lastVisitedModule,
        sidebarPreference: AppSidebarPreference.collapsed,
        timeSyncEnabled: true,
        lastVisitedPageCode: 'quality',
      ),
    );

    await pumpPage(tester, controller);
    await tester.tap(find.widgetWithText(OutlinedButton, '恢复默认'));
    await tester.pumpAndSettle();

    expect(controller.settings, const SoftwareSettings.defaults());
    expect(find.text('软件设置已恢复默认值'), findsOneWidget);
    expect(find.text('已自动保存'), findsNothing);
  });

  testWidgets('切换到布局偏好后可修改启动入口与侧边栏状态', (tester) async {
    final controller = SoftwareSettingsController.memory();

    await pumpPage(tester, controller);
    await tester.tap(find.text('布局偏好').first);
    await tester.pumpAndSettle();

    expect(find.text('启动后默认进入'), findsOneWidget);
    expect(find.text('侧边栏默认状态'), findsOneWidget);

    await tester.tap(find.text('上次停留模块'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('折叠'));
    await tester.pumpAndSettle();

    expect(
      controller.settings.launchTargetPreference,
      AppLaunchTargetPreference.lastVisitedModule,
    );
    expect(controller.settings.sidebarPreference, AppSidebarPreference.collapsed);
  });

  testWidgets('窄屏下仍可切换到布局偏好并显示对应内容', (tester) async {
    final controller = SoftwareSettingsController.memory();

    await pumpPage(tester, controller, contentWidth: 600);
    await tester.tap(find.text('布局偏好').first);
    await tester.pumpAndSettle();

    expect(find.text('启动后默认进入'), findsOneWidget);
    expect(find.text('侧边栏默认状态'), findsOneWidget);
  });

  testWidgets('切换到时间同步分区后显示同步策略与操作按钮', (tester) async {
    final controller = SoftwareSettingsController.memory();
    final timeSyncController = _buildTimeSyncController(
      controller,
      nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 0),
    );
    await timeSyncController.checkAtStartup(baseUrl: defaultApiBaseUrl);

    await pumpPage(
      tester,
      controller,
      timeSyncController: timeSyncController,
    );
    await tester.tap(find.text('时间同步').first);
    await tester.pumpAndSettle();

    expect(find.text('启用时间同步'), findsOneWidget);
    expect(find.text('立即检查并同步'), findsOneWidget);
    expect(find.text('仅重新校准软件内时间'), findsOneWidget);
    expect(find.textContaining('服务器时间：'), findsOneWidget);
    expect(find.textContaining('本机时间：'), findsOneWidget);
    expect(find.textContaining('最近同步结果：'), findsOneWidget);
    expect(find.textContaining('最近同步时间：'), findsOneWidget);
  });
}

TimeSyncController _buildTimeSyncController(
  SoftwareSettingsController controller, {
  DateTime Function()? nowProvider,
}) {
  return TimeSyncController(
    softwareSettingsController: controller,
    serverTimeService: _FakeServerTimeService(),
    systemTimeSyncService: _FakeWindowsTimeSyncService(),
    effectiveClock: EffectiveClock(),
    nowProvider: nowProvider,
  );
}

class _FakeServerTimeService extends ServerTimeService {
  @override
  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) async {
    return ServerTimeSnapshot(
      serverUtc: DateTime.utc(2026, 4, 20, 2, 0, 0),
      serverTimezoneOffsetMinutes: 480,
      sampledAtEpochMs:
          DateTime.utc(2026, 4, 20, 2, 0, 0).millisecondsSinceEpoch,
    );
  }
}

class _FakeWindowsTimeSyncService extends WindowsTimeSyncService {}

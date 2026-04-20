import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/config/runtime_endpoints.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';
import 'package:mes_client/main.dart';

void main() {
  testWidgets('应用启动后会使用默认接口地址触发一次时间同步检查', (tester) async {
    final serverTimeService = _ProbeServerTimeService();
    final timeSyncController = TimeSyncController(
      softwareSettingsController: SoftwareSettingsController.memory(),
      serverTimeService: serverTimeService,
      systemTimeSyncService: _FakeWindowsTimeSyncService(),
      effectiveClock: EffectiveClock(),
    );

    await tester.pumpWidget(
      MesClientApp(
        softwareSettingsController: SoftwareSettingsController.memory(),
        timeSyncController: timeSyncController,
      ),
    );
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(serverTimeService.baseUrls.single, defaultApiBaseUrl);
  });

  testWidgets('启动期改时失败时会展示退化提示', (tester) async {
    final settingsController = SoftwareSettingsController.memory();
    final timeSyncController = TimeSyncController(
      softwareSettingsController: settingsController,
      serverTimeService: _ProbeServerTimeService(
        snapshot: ServerTimeSnapshot(
          serverUtc: DateTime.utc(2026, 4, 20, 2, 1, 0),
          serverTimezoneOffsetMinutes: 480,
          sampledAtEpochMs: DateTime.utc(2026, 4, 20, 2, 1, 0)
              .millisecondsSinceEpoch,
        ),
      ),
      systemTimeSyncService: _FakeWindowsTimeSyncService(
        result: TimeSyncResultCode.cancelledByUser,
      ),
      effectiveClock: EffectiveClock(),
      nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 0),
    );

    await tester.pumpWidget(
      MesClientApp(
        softwareSettingsController: settingsController,
        timeSyncController: timeSyncController,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('你已取消管理员授权，系统时间未修改，当前已切换为软件内时间校准'),
      findsOneWidget,
    );
  });
}

class _ProbeServerTimeService extends ServerTimeService {
  _ProbeServerTimeService({
    ServerTimeSnapshot? snapshot,
  }) : snapshot =
           snapshot ??
           ServerTimeSnapshot(
             serverUtc: DateTime.utc(2026, 4, 20, 2, 0, 0),
             serverTimezoneOffsetMinutes: 480,
             sampledAtEpochMs: DateTime.utc(2026, 4, 20, 2, 0, 0)
                 .millisecondsSinceEpoch,
           );

  final ServerTimeSnapshot snapshot;
  final List<String> baseUrls = <String>[];

  @override
  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) async {
    baseUrls.add(baseUrl);
    return snapshot;
  }
}

class _FakeWindowsTimeSyncService extends WindowsTimeSyncService {
  _FakeWindowsTimeSyncService({
    this.result = TimeSyncResultCode.success,
  });

  final TimeSyncResultCode result;

  @override
  Future<TimeSyncResultCode> requestElevatedSync({
    required DateTime targetUtc,
  }) async {
    return result;
  }
}

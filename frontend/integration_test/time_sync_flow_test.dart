import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';
import 'package:mes_client/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('启动检查失败后会退化为软件内时间校准', (tester) async {
    final settingsController = SoftwareSettingsController.memory();
    final effectiveClock = EffectiveClock();
    final timeSyncController = TimeSyncController(
      softwareSettingsController: settingsController,
      serverTimeService: _FakeServerTimeService(),
      systemTimeSyncService: _FakeWindowsTimeSyncService(
        result: TimeSyncResultCode.cancelledByUser,
      ),
      effectiveClock: effectiveClock,
      nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 0),
    );

    await tester.pumpWidget(
      MesClientApp(
        softwareSettingsController: settingsController,
        timeSyncController: timeSyncController,
      ),
    );
    await tester.pumpAndSettle();

    expect(timeSyncController.state.mode, TimeSyncMode.softwareTimeCalibrated);
    expect(effectiveClock.isCalibrated, isTrue);
  });
}

class _FakeServerTimeService extends ServerTimeService {
  @override
  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) async {
    return ServerTimeSnapshot(
      serverUtc: DateTime.utc(2026, 4, 20, 2, 1, 0),
      serverTimezoneOffsetMinutes: 480,
      sampledAtEpochMs:
          DateTime.utc(2026, 4, 20, 2, 1, 0).millisecondsSinceEpoch,
    );
  }
}

class _FakeWindowsTimeSyncService extends WindowsTimeSyncService {
  _FakeWindowsTimeSyncService({
    required this.result,
  });

  final TimeSyncResultCode result;

  @override
  Future<TimeSyncResultCode> requestElevatedSync({
    required DateTime targetUtc,
  }) async {
    return result;
  }
}

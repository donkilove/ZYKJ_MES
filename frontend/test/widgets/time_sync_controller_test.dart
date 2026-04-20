import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

void main() {
  test('偏差未超过 30 秒时不会触发系统改时', () async {
    final settingsController = SoftwareSettingsController.memory();
    final effectiveClock = EffectiveClock();
    final syncService = _FakeWindowsTimeSyncService();
    final controller = TimeSyncController(
      softwareSettingsController: settingsController,
      serverTimeService: _FakeServerTimeService(
        snapshot: ServerTimeSnapshot(
          serverUtc: DateTime.utc(2026, 4, 20, 2, 0, 10),
          serverTimezoneOffsetMinutes: 480,
          sampledAtEpochMs: DateTime.utc(2026, 4, 20, 2, 0, 10)
              .millisecondsSinceEpoch,
        ),
      ),
      systemTimeSyncService: syncService,
      effectiveClock: effectiveClock,
      nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 0),
    );

    await controller.checkAtStartup(baseUrl: 'http://127.0.0.1:8000/api/v1');

    expect(syncService.callCount, 0);
    expect(controller.state.mode, TimeSyncMode.systemTimeOk);
    expect(effectiveClock.isCalibrated, isFalse);
  });

  test('系统改时失败时会退化为软件内时间校准', () async {
    final settingsController = SoftwareSettingsController.memory();
    final effectiveClock = EffectiveClock();
    final controller = TimeSyncController(
      softwareSettingsController: settingsController,
      serverTimeService: _FakeServerTimeService(
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
      effectiveClock: effectiveClock,
      nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 0),
    );

    await controller.checkAtStartup(baseUrl: 'http://127.0.0.1:8000/api/v1');

    expect(controller.state.mode, TimeSyncMode.softwareTimeCalibrated);
    expect(
      controller.state.lastResultCode,
      TimeSyncResultCode.cancelledByUser,
    );
    expect(effectiveClock.isCalibrated, isTrue);
  });
}

class _FakeServerTimeService extends ServerTimeService {
  _FakeServerTimeService({required this.snapshot});

  final ServerTimeSnapshot snapshot;

  @override
  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) async {
    return snapshot;
  }
}

class _FakeWindowsTimeSyncService extends WindowsTimeSyncService {
  _FakeWindowsTimeSyncService({
    this.result = TimeSyncResultCode.success,
  });

  final TimeSyncResultCode result;
  int callCount = 0;

  @override
  Future<TimeSyncResultCode> requestElevatedSync({
    required DateTime targetUtc,
  }) async {
    callCount += 1;
    return result;
  }
}

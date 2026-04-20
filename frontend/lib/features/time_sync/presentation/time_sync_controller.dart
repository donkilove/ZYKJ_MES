import 'package:flutter/foundation.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

class TimeSyncController extends ChangeNotifier {
  TimeSyncController({
    required this.softwareSettingsController,
    required this.serverTimeService,
    required this.systemTimeSyncService,
    required this.effectiveClock,
    DateTime Function()? nowProvider,
  }) : nowProvider = nowProvider ?? DateTime.now,
       _state = const TimeSyncState.initial() {
    softwareSettingsController.addListener(_handleSettingsChanged);
  }

  static const driftThreshold = Duration(seconds: 30);

  final SoftwareSettingsController softwareSettingsController;
  final ServerTimeService serverTimeService;
  final WindowsTimeSyncService systemTimeSyncService;
  final EffectiveClock effectiveClock;
  final DateTime Function() nowProvider;

  TimeSyncState _state;
  String? _lastCheckedBaseUrl;

  TimeSyncState get state => _state;

  Future<void> checkAtStartup({
    required String baseUrl,
    bool force = false,
  }) async {
    if (!softwareSettingsController.settings.timeSyncEnabled) {
      _setDisabledState();
      return;
    }
    if (!force && _lastCheckedBaseUrl == baseUrl && _state.lastCheckedAt != null) {
      return;
    }

    final requestedAt = nowProvider().toUtc();
    try {
      final snapshot = await serverTimeService.fetchSnapshot(baseUrl: baseUrl);
      final receivedAt = nowProvider().toUtc();
      final roundTrip = receivedAt.difference(requestedAt);
      final estimatedServerNow = snapshot.serverUtc.add(roundTrip ~/ 2);
      final drift = receivedAt.difference(estimatedServerNow);
      final offset = estimatedServerNow.difference(receivedAt);
      _lastCheckedBaseUrl = baseUrl;

      if (drift.abs() <= driftThreshold) {
        effectiveClock.clearCalibration();
        _state = TimeSyncState(
          mode: TimeSyncMode.systemTimeOk,
          lastResultCode: TimeSyncResultCode.skippedWithinThreshold,
          serverUtc: snapshot.serverUtc,
          localUtc: receivedAt,
          drift: drift,
          serverOffset: Duration.zero,
          lastCheckedAt: receivedAt,
          message: '系统时间正常',
        );
        notifyListeners();
        return;
      }

      final result = await systemTimeSyncService.requestElevatedSync(
        targetUtc: estimatedServerNow,
      );
      if (result == TimeSyncResultCode.success) {
        effectiveClock.clearCalibration();
        _state = TimeSyncState(
          mode: TimeSyncMode.systemTimeCorrected,
          lastResultCode: result,
          serverUtc: snapshot.serverUtc,
          localUtc: receivedAt,
          drift: drift,
          serverOffset: Duration.zero,
          lastCheckedAt: receivedAt,
          message: '检测到时间偏差 ${drift.inSeconds.abs()} 秒，已自动修正',
        );
      } else {
        effectiveClock.applyServerOffset(offset);
        _state = TimeSyncState(
          mode: TimeSyncMode.softwareTimeCalibrated,
          lastResultCode: result,
          serverUtc: snapshot.serverUtc,
          localUtc: receivedAt,
          drift: drift,
          serverOffset: offset,
          lastCheckedAt: receivedAt,
          message: _fallbackMessage(result),
        );
      }
    } catch (_) {
      _state = TimeSyncState(
        mode: TimeSyncMode.unavailable,
        lastResultCode: TimeSyncResultCode.serverTimeUnavailable,
        lastCheckedAt: nowProvider().toUtc(),
        message: '无法连接服务器时间接口，暂未完成同步',
      );
    }
    notifyListeners();
  }

  Future<void> calibrateSoftwareClock({required String baseUrl}) async {
    final requestedAt = nowProvider().toUtc();
    final snapshot = await serverTimeService.fetchSnapshot(baseUrl: baseUrl);
    final receivedAt = nowProvider().toUtc();
    final roundTrip = receivedAt.difference(requestedAt);
    final estimatedServerNow = snapshot.serverUtc.add(roundTrip ~/ 2);
    final offset = estimatedServerNow.difference(receivedAt);
    effectiveClock.applyServerOffset(offset);
    _state = TimeSyncState(
      mode: TimeSyncMode.softwareTimeCalibrated,
      lastResultCode: TimeSyncResultCode.syncFailed,
      serverUtc: snapshot.serverUtc,
      localUtc: receivedAt,
      drift: receivedAt.difference(estimatedServerNow),
      serverOffset: offset,
      lastCheckedAt: receivedAt,
      message: '已重新校准软件内时间',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    softwareSettingsController.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (!softwareSettingsController.settings.timeSyncEnabled) {
      _setDisabledState();
    }
  }

  void _setDisabledState() {
    effectiveClock.clearCalibration();
    _state = const TimeSyncState(
      mode: TimeSyncMode.disabled,
      lastResultCode: TimeSyncResultCode.idle,
      message: '时间同步已关闭',
    );
    notifyListeners();
  }

  String _fallbackMessage(TimeSyncResultCode result) {
    switch (result) {
      case TimeSyncResultCode.cancelledByUser:
        return '你已取消管理员授权，系统时间未修改，当前已切换为软件内时间校准';
      case TimeSyncResultCode.permissionDenied:
        return '未能修改 Windows 系统时间，当前已切换为软件内时间校准，软件内业务时间仍按服务器时间对齐';
      default:
        return '未能修改 Windows 系统时间，当前已切换为软件内时间校准，软件内业务时间仍按服务器时间对齐';
    }
  }
}

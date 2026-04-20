enum TimeSyncResultCode {
  idle,
  success,
  skippedWithinThreshold,
  cancelledByUser,
  permissionDenied,
  syncFailed,
  serverTimeUnavailable,
}

enum TimeSyncMode {
  disabled,
  systemTimeOk,
  systemTimeCorrected,
  softwareTimeCalibrated,
  unavailable,
}

class ServerTimeSnapshot {
  const ServerTimeSnapshot({
    required this.serverUtc,
    required this.serverTimezoneOffsetMinutes,
    required this.sampledAtEpochMs,
  });

  final DateTime serverUtc;
  final int serverTimezoneOffsetMinutes;
  final int sampledAtEpochMs;

  factory ServerTimeSnapshot.fromJson(Map<String, dynamic> json) {
    return ServerTimeSnapshot(
      serverUtc: DateTime.parse(json['server_utc_iso'] as String).toUtc(),
      serverTimezoneOffsetMinutes:
          json['server_timezone_offset_minutes'] as int? ?? 0,
      sampledAtEpochMs: json['sampled_at_epoch_ms'] as int? ?? 0,
    );
  }
}

class TimeSyncState {
  const TimeSyncState({
    required this.mode,
    required this.lastResultCode,
    this.serverUtc,
    this.localUtc,
    this.drift,
    this.serverOffset,
    this.lastCheckedAt,
    this.message,
  });

  const TimeSyncState.initial()
      : mode = TimeSyncMode.unavailable,
        lastResultCode = TimeSyncResultCode.idle,
        serverUtc = null,
        localUtc = null,
        drift = null,
        serverOffset = null,
        lastCheckedAt = null,
        message = null;

  final TimeSyncMode mode;
  final TimeSyncResultCode lastResultCode;
  final DateTime? serverUtc;
  final DateTime? localUtc;
  final Duration? drift;
  final Duration? serverOffset;
  final DateTime? lastCheckedAt;
  final String? message;
}

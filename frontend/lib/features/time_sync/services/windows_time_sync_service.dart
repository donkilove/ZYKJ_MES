import 'dart:convert';
import 'dart:io';

import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:path/path.dart' as p;

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

Future<ProcessResult> _defaultProcessRunner(
  String executable,
  List<String> arguments,
) {
  return Process.run(executable, arguments);
}

class WindowsTimeSyncService {
  WindowsTimeSyncService({
    ProcessRunner? processRunner,
    File Function()? resultFileFactory,
    String? executablePath,
  }) : processRunner = processRunner ?? _defaultProcessRunner,
       resultFileFactory =
           resultFileFactory ??
           (() => File(
                 p.join(
                   Directory.systemTemp.path,
                   'mes_time_sync_${DateTime.now().millisecondsSinceEpoch}.json',
                 ),
               )),
       executablePath = executablePath ?? Platform.resolvedExecutable;

  final ProcessRunner processRunner;
  final File Function() resultFileFactory;
  final String executablePath;

  bool isCommand(List<String> args) => args.contains('--sync-system-time');

  Future<TimeSyncResultCode> requestElevatedSync({
    required DateTime targetUtc,
  }) async {
    final resultFile = resultFileFactory();
    final arguments = <String>[
      '--sync-system-time',
      '--target-utc-iso=${targetUtc.toUtc().toIso8601String()}',
      '--result-file=${resultFile.path}',
    ];
    final quotedArguments = arguments
        .map((item) => "'${item.replaceAll("'", "''")}'")
        .join(', ');

    final result = await processRunner('powershell', [
      '-NoProfile',
      '-Command',
      "Start-Process -FilePath '${executablePath.replaceAll("'", "''")}' -Verb RunAs -ArgumentList @($quotedArguments) -Wait",
    ]);
    if (await resultFile.exists()) {
      final payload = jsonDecode(await resultFile.readAsString())
          as Map<String, dynamic>;
      return _parseResultCode(payload['code'] as String?);
    }
    return _mapProcessFailure(result);
  }

  Future<int> handleCommandMode(List<String> args) async {
    final targetArg = args.firstWhere(
      (item) => item.startsWith('--target-utc-iso='),
      orElse: () => '',
    );
    final resultFileArg = args.firstWhere(
      (item) => item.startsWith('--result-file='),
      orElse: () => '',
    );
    if (targetArg.isEmpty || resultFileArg.isEmpty) {
      return 2;
    }

    final targetUtc = DateTime.parse(
      targetArg.substring('--target-utc-iso='.length),
    ).toUtc();
    final resultFile = File(resultFileArg.substring('--result-file='.length));

    try {
      final result = await processRunner('powershell', [
        '-NoProfile',
        '-Command',
        "Set-Date -Date '${targetUtc.toLocal().toIso8601String()}'",
      ]);
      if (result.exitCode == 0) {
        await resultFile.writeAsString(jsonEncode({'code': 'success'}));
        return 0;
      }
      final failureCode = _mapProcessFailure(result);
      await resultFile.writeAsString(
        jsonEncode({'code': _resultCodeToStorage(failureCode)}),
      );
      return 1;
    } catch (error) {
      await resultFile.writeAsString(
        jsonEncode({'code': 'sync_failed', 'message': error.toString()}),
      );
      return 1;
    }
  }

  TimeSyncResultCode _parseResultCode(String? code) {
    switch (code) {
      case 'success':
        return TimeSyncResultCode.success;
      case 'cancelled_by_user':
        return TimeSyncResultCode.cancelledByUser;
      case 'permission_denied':
        return TimeSyncResultCode.permissionDenied;
      default:
        return TimeSyncResultCode.syncFailed;
    }
  }

  TimeSyncResultCode _mapProcessFailure(ProcessResult result) {
    final stderrText = '${result.stderr}'.toLowerCase();
    if (stderrText.contains('canceled by the user') ||
        stderrText.contains('operation was canceled') ||
        stderrText.contains('cancelled by user')) {
      return TimeSyncResultCode.cancelledByUser;
    }
    if (stderrText.contains('access is denied')) {
      return TimeSyncResultCode.permissionDenied;
    }
    return TimeSyncResultCode.syncFailed;
  }

  String _resultCodeToStorage(TimeSyncResultCode code) {
    switch (code) {
      case TimeSyncResultCode.success:
        return 'success';
      case TimeSyncResultCode.cancelledByUser:
        return 'cancelled_by_user';
      case TimeSyncResultCode.permissionDenied:
        return 'permission_denied';
      default:
        return 'sync_failed';
    }
  }
}

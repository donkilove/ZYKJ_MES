import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

void main() {
  test('requestElevatedSync 读取结果文件后返回 success', () async {
    final resultFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}mes_time_sync_result.json',
    );
    await resultFile.writeAsString(jsonEncode({'code': 'success'}));
    addTearDown(() async {
      if (await resultFile.exists()) {
        await resultFile.delete();
      }
    });

    final service = WindowsTimeSyncService(
      processRunner: (ignoredCommand, ignoredArguments) async =>
          ProcessResult(1, 0, '', ''),
      resultFileFactory: () => resultFile,
      executablePath: r'C:\demo\mes_client.exe',
    );

    final result = await service.requestElevatedSync(
      targetUtc: DateTime.utc(2026, 4, 20, 2, 0, 45),
    );

    expect(result, TimeSyncResultCode.success);
  });

  test('handleCommandMode 缺少参数时返回 2', () async {
    final service = WindowsTimeSyncService();

    final exitCode = await service.handleCommandMode(const ['--sync-system-time']);

    expect(exitCode, 2);
  });
}

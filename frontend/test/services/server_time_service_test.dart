import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';

void main() {
  test('fetchSnapshot 会解析服务器时间快照', () async {
    final service = ServerTimeService(
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'http://127.0.0.1:8000/api/v1/system/time',
        );
        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'ok',
            'data': {
              'server_utc_iso': '2026-04-20T02:00:45Z',
              'server_timezone_offset_minutes': 480,
              'sampled_at_epoch_ms': 1776650445000,
            },
          }),
          200,
        );
      }),
    );

    final snapshot = await service.fetchSnapshot(
      baseUrl: 'http://127.0.0.1:8000/api/v1',
    );

    expect(snapshot.serverUtc, DateTime.parse('2026-04-20T02:00:45Z'));
    expect(snapshot.serverTimezoneOffsetMinutes, 480);
    expect(snapshot.sampledAtEpochMs, 1776650445000);
  });

  test('fetchSnapshot 在非 200 时抛出 ApiException', () async {
    final service = ServerTimeService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'server unavailable'}),
          503,
        );
      }),
    );

    await expectLater(
      () => service.fetchSnapshot(baseUrl: 'http://127.0.0.1:8000/api/v1'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.message, 'message', 'server unavailable'),
      ),
    );
  });
}

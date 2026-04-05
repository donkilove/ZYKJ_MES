import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/authz_models.dart';
import 'package:mes_client/pages/production_page.dart';

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.url);

  final Uri url;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    final path = url.path;
    final isAssistRecords = path == '/production/assist-authorizations';
    final isOverview = path == '/production/stats/overview';
    final isProcessStats = path == '/production/stats/processes';
    final isOperatorStats = path == '/production/stats/operators';
    final isTodayRealtime = path == '/production/data/today-realtime';
    return _FakeHttpClientResponse(
      statusCode:
          isAssistRecords ||
              isOverview ||
              isProcessStats ||
              isOperatorStats ||
              isTodayRealtime
          ? 200
          : 404,
      body: jsonEncode(
        isAssistRecords
            ? {
                'data': {'total': 0, 'items': <Object>[]},
              }
            : isOverview
            ? {
                'data': {
                  'total_orders': 5,
                  'pending_orders': 2,
                  'in_progress_orders': 2,
                  'completed_orders': 1,
                  'total_quantity': 100,
                  'finished_quantity': 40,
                },
              }
            : isProcessStats
            ? {
                'data': {
                  'items': [
                    {
                      'process_code': '01-01',
                      'process_name': '切割',
                      'total_orders': 5,
                      'pending_orders': 2,
                      'in_progress_orders': 2,
                      'partial_orders': 0,
                      'completed_orders': 1,
                      'total_visible_quantity': 100,
                      'total_completed_quantity': 40,
                    },
                  ],
                },
              }
            : isOperatorStats
            ? {
                'data': {
                  'items': [
                    {
                      'operator_user_id': 8,
                      'operator_username': 'worker',
                      'process_code': '01-01',
                      'process_name': '切割',
                      'production_records': 3,
                      'production_quantity': 40,
                      'last_production_at': '2026-03-01T00:00:00Z',
                    },
                  ],
                },
              }
            : isTodayRealtime
            ? {
                'data': {
                  'stat_mode': 'main_order',
                  'summary': {'total_products': 1, 'total_quantity': 10},
                  'table_rows': [
                    {
                      'product_id': 1,
                      'product_name': '产品A',
                      'quantity': 10,
                      'latest_time': '2026-03-01T00:00:00Z',
                      'latest_time_text': '2026-03-01 08:00:00',
                    },
                  ],
                  'chart_data': [
                    {'label': '产品A', 'value': 10},
                  ],
                  'query_signature': '{"view":"today_realtime"}',
                },
              }
            : {'detail': 'not found'},
      ),
    );
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({required this.statusCode, required String body})
    : _bytes = utf8.encode(body);

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders(contentType: ContentType.json);

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Not Found';

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnsupportedError('redirect is not supported in tests');
  }

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('detachSocket is not supported in tests');
  }

  bool get chunkedTransferEncoding => false;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  _FakeHttpHeaders({ContentType? contentType}) : _contentType = contentType;

  ContentType? _contentType;

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) {
    _contentType = value;
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('production page mounts assist records tab', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductionPage(
              session: AppSession(
                baseUrl: 'http://example.test',
                accessToken: 'test-token',
              ),
              onLogout: () {},
              visibleTabCodes: const <String>[productionAssistRecordsTabCode],
              capabilityCodes: const <String>{
                ProductionFeaturePermissionCodes.assistRecordsView,
              },
              preferredTabCode: productionAssistRecordsTabCode,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('代班记录'), findsWidgets);
      expect(
        find.byKey(const ValueKey('productionAssistRecordsListCard')),
        findsOneWidget,
      );
    }, createHttpClient: (_) => _FakeHttpClient());
  });

  testWidgets('production page expands production data into dedicated tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductionPage(
              session: AppSession(
                baseUrl: 'http://example.test',
                accessToken: 'test-token',
              ),
              onLogout: () {},
              visibleTabCodes: const <String>[productionDataQueryTabCode],
              capabilityCodes: const <String>{},
              preferredTabCode: productionDataQueryTabCode,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('工序统计'), findsWidgets);
      expect(find.text('今日实时产量'), findsOneWidget);
      expect(find.text('人员统计'), findsOneWidget);
      expect(find.text('手动筛选'), findsNothing);
      expect(find.text('未完工进度'), findsNothing);
    }, createHttpClient: (_) => _FakeHttpClient());
  });
}

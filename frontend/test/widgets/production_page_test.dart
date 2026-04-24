import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/features/production/presentation/production_assist_records_page.dart';
import 'package:mes_client/features/production/presentation/production_page.dart';
import 'package:mes_client/features/production/presentation/production_order_query_page.dart';
import 'package:mes_client/features/production/presentation/production_repair_orders_page.dart';

class _PayloadProbe extends StatelessWidget {
  const _PayloadProbe(this.label, {required this.payload});

  final String label;
  final String? payload;

  @override
  Widget build(BuildContext context) {
    return Text('$label:${payload ?? 'null'}');
  }
}

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
  AppSession buildSession() =>
      AppSession(baseUrl: 'http://example.test', accessToken: 'test-token');

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
              session: buildSession(),
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
              session: buildSession(),
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

  testWidgets('production page supports full tab mounting and preferred tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPage(
            session: buildSession(),
            onLogout: () {},
            visibleTabCodes: const <String>[
              productionOrderManagementTabCode,
              productionOrderQueryTabCode,
              productionAssistRecordsTabCode,
              productionDataQueryTabCode,
              productionScrapStatisticsTabCode,
              productionRepairOrdersTabCode,
              productionPipelineInstancesTabCode,
            ],
            capabilityCodes: const <String>{},
            preferredTabCode: productionPipelineInstancesTabCode,
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('订单管理'), findsOneWidget);
    expect(find.text('订单查询'), findsOneWidget);
    expect(find.text('代班记录'), findsOneWidget);
    expect(find.text('工序统计'), findsOneWidget);
    expect(find.text('今日实时产量'), findsOneWidget);
    expect(find.text('人员统计'), findsOneWidget);
    expect(find.text('报废统计'), findsOneWidget);
    expect(find.text('维修订单'), findsOneWidget);
    expect(find.text('并行实例追踪'), findsOneWidget);
    expect(
      find.text('tab:$productionPipelineInstancesTabCode'),
      findsOneWidget,
    );
  });

  testWidgets('production page shows empty state when no visible tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPage(
            session: buildSession(),
            onLogout: () {},
            visibleTabCodes: const <String>[],
            capabilityCodes: const <String>{},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('当前账号无可见生产页面'), findsOneWidget);
  });

  testWidgets('production page forwards route payload to target tab pages', (
    tester,
  ) async {
    const assistPayload =
        '{"target_tab_code":"production_assist_records","assist_authorization_id":91}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPage(
            session: buildSession(),
            onLogout: () {},
            visibleTabCodes: const <String>[
              productionAssistRecordsTabCode,
              productionRepairOrdersTabCode,
            ],
            capabilityCodes: const <String>{
              ProductionFeaturePermissionCodes.assistRecordsView,
              ProductionFeaturePermissionCodes.repairOrdersManage,
              ProductionFeaturePermissionCodes.repairOrdersExport,
            },
            preferredTabCode: productionAssistRecordsTabCode,
            routePayloadJson: assistPayload,
            tabPageBuilder: (tabCode, child) {
              if (child is ProductionAssistRecordsPage) {
                return _PayloadProbe('assist', payload: child.routePayloadJson);
              }
              if (child is ProductionRepairOrdersPage) {
                return _PayloadProbe('repair', payload: child.jumpPayloadJson);
              }
              return child;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('assist:$assistPayload'), findsOneWidget);

    const repairPayload =
        '{"target_tab_code":"production_repair_orders","repair_order_id":15}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPage(
            session: buildSession(),
            onLogout: () {},
            visibleTabCodes: const <String>[
              productionAssistRecordsTabCode,
              productionRepairOrdersTabCode,
            ],
            capabilityCodes: const <String>{
              ProductionFeaturePermissionCodes.assistRecordsView,
              ProductionFeaturePermissionCodes.repairOrdersManage,
              ProductionFeaturePermissionCodes.repairOrdersExport,
            },
            preferredTabCode: productionRepairOrdersTabCode,
            routePayloadJson: repairPayload,
            tabPageBuilder: (tabCode, child) {
              if (child is ProductionAssistRecordsPage) {
                return _PayloadProbe('assist', payload: child.routePayloadJson);
              }
              if (child is ProductionRepairOrdersPage) {
                return _PayloadProbe('repair', payload: child.jumpPayloadJson);
              }
              return child;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('repair:$repairPayload'), findsOneWidget);
  });

  testWidgets('production page updates tabs when visibleTabCodes changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPage(
            session: buildSession(),
            onLogout: () {},
            visibleTabCodes: const <String>[
              productionOrderManagementTabCode,
              productionAssistRecordsTabCode,
            ],
            capabilityCodes: const <String>{},
            preferredTabCode: productionAssistRecordsTabCode,
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('tab:$productionAssistRecordsTabCode'), findsOneWidget);
    expect(find.text('订单管理'), findsOneWidget);
    expect(find.text('代班记录'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPage(
            session: buildSession(),
            onLogout: () {},
            visibleTabCodes: const <String>[
              productionOrderQueryTabCode,
              productionPipelineInstancesTabCode,
            ],
            capabilityCodes: const <String>{},
            preferredTabCode: productionPipelineInstancesTabCode,
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('订单管理'), findsNothing);
    expect(find.text('代班记录'), findsNothing);
    expect(find.text('订单查询'), findsOneWidget);
    expect(find.text('并行实例追踪'), findsOneWidget);
    expect(find.text('tab:$productionOrderQueryTabCode'), findsOneWidget);
  });

  testWidgets('production page 会在页签切换时联动订单查询轮询活跃态', (
    tester,
  ) async {
    bool? latestPollingEnabled;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPage(
            session: buildSession(),
            onLogout: () {},
            visibleTabCodes: const <String>[
              productionOrderQueryTabCode,
              productionPipelineInstancesTabCode,
            ],
            capabilityCodes: const <String>{},
            preferredTabCode: productionOrderQueryTabCode,
            tabPageBuilder: (tabCode, child) {
              if (child is ProductionOrderQueryPage) {
                latestPollingEnabled = child.pollingEnabled;
                return const SizedBox.shrink();
              }
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(latestPollingEnabled, isTrue);

    await tester.tap(find.text('并行实例追踪'));
    await tester.pumpAndSettle();
    expect(latestPollingEnabled, isFalse);

    await tester.tap(find.text('订单查询'));
    await tester.pumpAndSettle();
    expect(latestPollingEnabled, isTrue);
  });
}

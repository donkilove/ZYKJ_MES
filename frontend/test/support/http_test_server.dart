import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.bodyText,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String bodyText;

  dynamic get decodedBody {
    if (bodyText.trim().isEmpty) {
      return null;
    }
    return jsonDecode(bodyText);
  }
}

class TestResponse {
  const TestResponse({
    required this.statusCode,
    this.body,
    this.headers = const {},
  });

  final int statusCode;
  final Object? body;
  final Map<String, String> headers;

  factory TestResponse.json(
    int statusCode, {
    Object? body,
    Map<String, String> headers = const {},
  }) {
    return TestResponse(statusCode: statusCode, body: body, headers: headers);
  }
}

typedef TestRouteHandler = FutureOr<TestResponse> Function(
  RecordedRequest request,
);

class TestHttpServer {
  TestHttpServer._(this._server, this._routes) {
    _server.listen(_handleRequest);
  }

  final HttpServer _server;
  final Map<String, TestRouteHandler> _routes;
  final List<RecordedRequest> requests = <RecordedRequest>[];

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  static Future<TestHttpServer> start(
    Map<String, TestRouteHandler> routes,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return TestHttpServer._(server, routes);
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest rawRequest) async {
    final bodyText = await utf8.decoder.bind(rawRequest).join();
    final headers = <String, String>{};
    rawRequest.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(',');
    });

    final request = RecordedRequest(
      method: rawRequest.method.toUpperCase(),
      uri: rawRequest.uri,
      headers: headers,
      bodyText: bodyText,
    );
    requests.add(request);

    final routeKey = '${request.method} ${request.uri.path}';
    final handler = _routes[routeKey];
    if (handler == null) {
      _writeResponse(
        rawRequest.response,
        TestResponse.json(
          404,
          body: <String, dynamic>{
            'detail': 'No test handler for $routeKey',
          },
        ),
      );
      return;
    }

    try {
      final response = await handler(request);
      _writeResponse(rawRequest.response, response);
    } catch (error) {
      _writeResponse(
        rawRequest.response,
        TestResponse.json(
          500,
          body: <String, dynamic>{
            'detail': error.toString(),
          },
        ),
      );
    }
  }

  void _writeResponse(HttpResponse target, TestResponse response) {
    target.statusCode = response.statusCode;
    response.headers.forEach((key, value) {
      target.headers.set(key, value);
    });

    final body = response.body;
    if (body == null) {
      target.close();
      return;
    }

    if (body is String) {
      if (!target.headers.contentType
          .toString()
          .toLowerCase()
          .contains('application/json')) {
        target.headers.contentType = ContentType.text;
      }
      target.write(body);
      target.close();
      return;
    }

    target.headers.contentType = ContentType.json;
    target.write(jsonEncode(body));
    target.close();
  }
}

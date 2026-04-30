import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as package_http;
export 'package:http/http.dart' show Response;

import 'package:mes_client/core/network/api_exception.dart';

const Duration _requestTimeout = Duration(seconds: 30);

Future<package_http.Response> get(Uri url, {Map<String, String>? headers}) {
  return _guardNetworkFailure(() => package_http.get(url, headers: headers));
}

Future<package_http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  return _guardNetworkFailure(
    () => package_http.post(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    ),
  );
}

Future<package_http.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  return _guardNetworkFailure(
    () =>
        package_http.put(url, headers: headers, body: body, encoding: encoding),
  );
}

Future<package_http.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  return _guardNetworkFailure(
    () => package_http.patch(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    ),
  );
}

Future<package_http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  return _guardNetworkFailure(
    () => package_http.delete(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    ),
  );
}

Future<package_http.Response> _guardNetworkFailure(
  Future<package_http.Response> Function() request,
) async {
  try {
    return await request().timeout(_requestTimeout);
  } on ApiException {
    rethrow;
  } on TimeoutException {
    throw ApiException('网络请求失败：连接超时，请稍后重试。', 0);
  } on package_http.ClientException catch (error) {
    throw ApiException('网络请求失败：${error.message}', 0);
  }
}

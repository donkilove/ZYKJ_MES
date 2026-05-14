import 'dart:convert';

import 'package:mes_client/core/network/api_error_message.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/network/http_client.dart' as http;

class FileDownloadResponse {
  const FileDownloadResponse({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  final String filename;
  final String mimeType;
  final List<int> bytes;
}

FileDownloadResponse parseFileDownloadResponse(
  http.Response response, {
  required String fallbackFilename,
  int expectedStatusCode = 200,
  String fallbackMimeType = 'application/octet-stream',
}) {
  if (response.statusCode != expectedStatusCode) {
    throw _buildFileDownloadApiException(response);
  }
  return FileDownloadResponse(
    filename:
        resolveDownloadFilename(
          response.headers['content-disposition'] ?? '',
        ) ??
        fallbackFilename,
    mimeType: response.headers['content-type'] ?? fallbackMimeType,
    bytes: response.bodyBytes,
  );
}

String? resolveDownloadFilename(String contentDisposition) {
  final filenameUtf8Match = RegExp(
    r"filename\*=UTF-8''([^;]+)",
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  if (filenameUtf8Match != null) {
    return Uri.decodeComponent(filenameUtf8Match.group(1)!);
  }
  final filenameMatch = RegExp(
    r'filename=\"?([^\";]+)\"?',
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  if (filenameMatch != null) {
    return filenameMatch.group(1);
  }
  return null;
}

ApiException _buildFileDownloadApiException(http.Response response) {
  final jsonBody = _tryDecodeJsonBody(response.bodyBytes);
  if (jsonBody != null) {
    return ApiException(
      extractApiErrorMessage(jsonBody, response.statusCode),
      response.statusCode,
    );
  }
  final textBody = _decodePlainTextBody(response.bodyBytes);
  if (textBody.isEmpty || _looksLikeMarkup(textBody)) {
    return ApiException('请求失败，状态码 ${response.statusCode}', response.statusCode);
  }
  return ApiException(textBody, response.statusCode);
}

Map<String, dynamic>? _tryDecodeJsonBody(List<int> bytes) {
  final text = _decodePlainTextBody(bytes);
  if (text.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } on FormatException {
    return null;
  }
  return null;
}

String _decodePlainTextBody(List<int> bytes) {
  return utf8
      .decode(bytes, allowMalformed: true)
      .replaceFirst('\ufeff', '')
      .trim();
}

bool _looksLikeMarkup(String text) {
  final normalized = text.trimLeft().toLowerCase();
  return normalized.startsWith('<!doctype html') ||
      normalized.startsWith('<html') ||
      normalized.startsWith('<?xml');
}

import 'package:mes_client/core/network/api_error_message.dart';

class ApiException implements Exception {
  ApiException(String message, this.statusCode)
    : message = normalizeApiErrorMessage(message, statusCode: statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

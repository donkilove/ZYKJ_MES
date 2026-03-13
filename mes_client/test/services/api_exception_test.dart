import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/services/api_exception.dart';

void main() {
  test('ApiException stores message/statusCode and toString returns message', () {
    final exception = ApiException('failure', 400);

    expect(exception.message, 'failure');
    expect(exception.statusCode, 400);
    expect(exception.toString(), 'failure');
  });
}

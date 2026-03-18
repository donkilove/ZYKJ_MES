import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';

void main() {
  test('AppSession stores baseUrl and accessToken', () {
    final session = AppSession(
      baseUrl: 'http://127.0.0.1:8000/api/v1',
      accessToken: 'token-123',
    );

    expect(session.baseUrl, 'http://127.0.0.1:8000/api/v1');
    expect(session.accessToken, 'token-123');
  });
}

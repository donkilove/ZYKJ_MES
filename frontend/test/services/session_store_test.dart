import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionStore', () {
    test('save and load session', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SessionStore();
      final session = AppSession(
        baseUrl: 'http://127.0.0.1:8000/api/v1',
        accessToken: 'token-1',
      );

      await store.save(session);
      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.baseUrl, session.baseUrl);
      expect(loaded.accessToken, session.accessToken);
    });

    test('load returns null when token missing or empty and clear removes data', () async {
      SharedPreferences.setMockInitialValues({
        'base_url': 'http://127.0.0.1:8000/api/v1',
        'access_token': '',
      });
      final store = SessionStore();

      expect(await store.load(), isNull);

      await store.save(
        AppSession(
          baseUrl: 'http://127.0.0.1:8000/api/v1',
          accessToken: 'token-2',
        ),
      );
      await store.clear();
      expect(await store.load(), isNull);
    });
  });
}

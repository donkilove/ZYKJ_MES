import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_session.dart';

class SessionStore {
  static const _baseUrlKey = 'base_url';
  static const _accessTokenKey = 'access_token';

  Future<void> save(AppSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, session.baseUrl);
    await prefs.setString(_accessTokenKey, session.accessToken);
  }

  Future<AppSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_baseUrlKey);
    final accessToken = prefs.getString(_accessTokenKey);

    if (baseUrl == null || accessToken == null || accessToken.isEmpty) {
      return null;
    }
    return AppSession(baseUrl: baseUrl, accessToken: accessToken);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_accessTokenKey);
  }
}


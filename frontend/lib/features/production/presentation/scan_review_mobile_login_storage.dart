import 'package:shared_preferences/shared_preferences.dart';

class ScanReviewMobileLoginState {
  const ScanReviewMobileLoginState({
    required this.accessToken,
    required this.expiresAt,
    this.username,
  });

  final String accessToken;
  final DateTime expiresAt;
  final String? username;
}

abstract class ScanReviewMobileLoginStorage {
  Future<ScanReviewMobileLoginState?> read();
  Future<void> write(ScanReviewMobileLoginState state);
  Future<void> clear();
}

class SharedPreferencesScanReviewMobileLoginStorage
    implements ScanReviewMobileLoginStorage {
  static const _accessTokenKey = 'firstArticleScanReview.accessToken';
  static const _expiresAtKey = 'firstArticleScanReview.expiresAt';
  static const _usernameKey = 'firstArticleScanReview.username';

  @override
  Future<ScanReviewMobileLoginState?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);
    final expiresAtRaw = prefs.getString(_expiresAtKey);
    if (token == null || expiresAtRaw == null) {
      return null;
    }
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
      await clear();
      return null;
    }
    return ScanReviewMobileLoginState(
      accessToken: token,
      expiresAt: expiresAt,
      username: prefs.getString(_usernameKey),
    );
  }

  @override
  Future<void> write(ScanReviewMobileLoginState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, state.accessToken);
    await prefs.setString(_expiresAtKey, state.expiresAt.toIso8601String());
    final username = (state.username ?? '').trim();
    if (username.isEmpty) {
      await prefs.remove(_usernameKey);
    } else {
      await prefs.setString(_usernameKey, username);
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_usernameKey);
  }
}

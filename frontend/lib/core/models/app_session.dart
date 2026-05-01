import 'dart:convert';

class AppSession {
  AppSession({
    required this.baseUrl,
    required this.accessToken,
    this.mustChangePassword = false,
    this.expiresIn = 0,
  });

  final String baseUrl;
  final String accessToken;
  final bool mustChangePassword;
  final int expiresIn;

  DateTime? get tokenIssuedAt {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
      final iat = payload['iat'];
      if (iat is int) {
        return DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true);
      }
      if (iat is double) {
        return DateTime.fromMillisecondsSinceEpoch(
          (iat * 1000).toInt(),
          isUtc: true,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? get loginType {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
      return payload['login_type'] as String?;
    } catch (_) {
      return null;
    }
  }

  int get tokenAgeSeconds {
    final iat = tokenIssuedAt;
    if (iat == null) return 0;
    return DateTime.now().toUtc().difference(iat).inSeconds;
  }

  bool get canRenewToken => tokenAgeSeconds >= 3600;

  bool get isTokenNearExpiry {
    if (expiresIn <= 0) return false;
    final remaining = expiresIn - tokenAgeSeconds;
    return remaining <= 300 && remaining > 0;
  }
}

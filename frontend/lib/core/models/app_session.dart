class AppSession {
  AppSession({
    required this.baseUrl,
    required this.accessToken,
    this.mustChangePassword = false,
  });

  final String baseUrl;
  final String accessToken;
  final bool mustChangePassword;
}


import 'package:flutter/material.dart';

import 'models/app_session.dart';
import 'pages/login_page.dart';
import 'pages/main_shell_page.dart';
import 'services/auth_service.dart';
import 'services/session_store.dart';

void main() {
  runApp(const MesClientApp());
}

class MesClientApp extends StatelessWidget {
  const MesClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZYKJ MES 系统',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A67)),
        useMaterial3: true,
        fontFamily: 'Microsoft YaHei',
        fontFamilyFallback: const [
          '微软雅黑',
          'Microsoft YaHei',
          'PingFang SC',
          'Noto Sans CJK SC',
          'sans-serif',
        ],
      ),
      home: const AppBootstrapPage(),
    );
  }
}

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  final SessionStore _sessionStore = SessionStore();
  final AuthService _authService = AuthService();
  AppSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resetSessionAtStartup();
  }

  Future<void> _resetSessionAtStartup() async {
    try {
      await _sessionStore.clear();
    } catch (_) {
      // Ignore clear failure and continue forcing login flow.
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
      _loading = false;
    });
  }

  void _handleLoginSuccess(AppSession session) {
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
    });
  }

  Future<void> _handleLogout() async {
    final session = _session;
    if (session != null) {
      try {
        await _authService.logout(
          baseUrl: session.baseUrl,
          accessToken: session.accessToken,
        );
      } catch (_) {
        // Fallback to local logout if backend logout fails.
      }
    }
    await _sessionStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_session == null) {
      return LoginPage(onLoginSuccess: _handleLoginSuccess);
    }

    return MainShellPage(session: _session!, onLogout: _handleLogout);
  }
}

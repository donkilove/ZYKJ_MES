import 'package:flutter/material.dart';

import 'models/app_session.dart';
import 'pages/login_page.dart';
import 'pages/user_management_page.dart';
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
  AppSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await _sessionStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _loading = false;
    });
  }

  Future<void> _handleLoginSuccess(AppSession session) async {
    await _sessionStore.save(session);
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
    });
  }

  Future<void> _handleLogout() async {
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_session == null) {
      return LoginPage(onLoginSuccess: _handleLoginSuccess);
    }

    return UserManagementPage(
      session: _session!,
      onLogout: _handleLogout,
    );
  }
}

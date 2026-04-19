import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/misc/presentation/force_change_password_page.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page.dart';

typedef SoftwareSettingsServiceFactory =
    Future<SoftwareSettingsService> Function();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final softwareSettingsController =
      await bootstrapSoftwareSettingsController();

  runApp(MesClientApp(softwareSettingsController: softwareSettingsController));
}

Future<SoftwareSettingsController> bootstrapSoftwareSettingsController({
  SoftwareSettingsServiceFactory createService = SoftwareSettingsService.create,
}) async {
  try {
    final service = await createService();
    final controller = SoftwareSettingsController(service: service);
    await controller.load();
    return controller;
  } catch (_) {
    return SoftwareSettingsController.memory();
  }
}

class MesClientApp extends StatelessWidget {
  const MesClientApp({required this.softwareSettingsController, super.key});

  final SoftwareSettingsController softwareSettingsController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: softwareSettingsController,
      builder: (context, child) {
        return MaterialApp(
          title: 'ZYKJ MES 系统',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN')],
          locale: const Locale('zh', 'CN'),
          theme: _buildTheme(
            brightness: Brightness.light,
            visualDensity: softwareSettingsController.visualDensity,
          ),
          darkTheme: _buildTheme(
            brightness: Brightness.dark,
            visualDensity: softwareSettingsController.visualDensity,
          ),
          themeMode: softwareSettingsController.themeMode,
          home: AppBootstrapPage(
            softwareSettingsController: softwareSettingsController,
          ),
        );
      },
    );
  }

  ThemeData _buildTheme({
    required Brightness brightness,
    required VisualDensity visualDensity,
  }) {
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A67),
        brightness: brightness,
      ),
      useMaterial3: true,
      visualDensity: visualDensity,
      fontFamily: 'Microsoft YaHei',
      fontFamilyFallback: const [
        '微软雅黑',
        'Microsoft YaHei',
        'PingFang SC',
        'Noto Sans CJK SC',
        'sans-serif',
      ],
    );
  }
}

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({required this.softwareSettingsController, super.key});

  final SoftwareSettingsController softwareSettingsController;

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  final AuthService _authService = AuthService();
  AppSession? _session;
  String? _loginNotice;

  @override
  void initState() {
    super.initState();
  }

  void _handleLoginSuccess(AppSession session) {
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _loginNotice = null;
    });
  }

  Future<void> _handleForcePasswordChanged() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
      _loginNotice = '密码已修改，请使用新密码重新登录。';
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
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return LoginPage(
        onLoginSuccess: _handleLoginSuccess,
        initialMessage: _loginNotice,
      );
    }

    if (_session!.mustChangePassword) {
      return ForceChangePasswordPage(
        session: _session!,
        onRequireRelogin: _handleForcePasswordChanged,
      );
    }

    return MainShellPage(
      session: _session!,
      onLogout: _handleLogout,
      softwareSettingsController: widget.softwareSettingsController,
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/config/runtime_endpoints.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/misc/presentation/force_change_password_page.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/features/production/presentation/first_article_scan_review_mobile_page.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/services/software_settings_service.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

typedef SoftwareSettingsServiceFactory =
    Future<SoftwareSettingsService> Function();

Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();

  final uri = Uri.base;
  if (uri.path == '/first-article-review') {
    runApp(
      FirstArticleScanReviewMobileApp(
        baseUrl: defaultApiBaseUrl,
        token: uri.queryParameters['token'] ?? '',
      ),
    );
    return;
  }

  final softwareSettingsController =
      await bootstrapSoftwareSettingsController();
  final effectiveClock = EffectiveClock();
  final systemTimeSyncService = WindowsTimeSyncService();
  if (systemTimeSyncService.isCommand(args)) {
    final exitCode = await systemTimeSyncService.handleCommandMode(args);
    exit(exitCode);
  }
  final timeSyncController = TimeSyncController(
    softwareSettingsController: softwareSettingsController,
    serverTimeService: ServerTimeService(),
    systemTimeSyncService: systemTimeSyncService,
    effectiveClock: effectiveClock,
  );

  runApp(
    MesClientApp(
      softwareSettingsController: softwareSettingsController,
      timeSyncController: timeSyncController,
    ),
  );
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
  const MesClientApp({
    required this.softwareSettingsController,
    required this.timeSyncController,
    super.key,
  });

  final SoftwareSettingsController softwareSettingsController;
  final TimeSyncController timeSyncController;

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
          theme: buildMesTheme(
            brightness: Brightness.light,
            visualDensity: softwareSettingsController.visualDensity,
          ),
          darkTheme: buildMesTheme(
            brightness: Brightness.dark,
            visualDensity: softwareSettingsController.visualDensity,
          ),
          themeMode: softwareSettingsController.themeMode,
          home: AppBootstrapPage(
            softwareSettingsController: softwareSettingsController,
            timeSyncController: timeSyncController,
          ),
        );
      },
    );
  }
}

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({
    required this.softwareSettingsController,
    required this.timeSyncController,
    super.key,
  });

  final SoftwareSettingsController softwareSettingsController;
  final TimeSyncController timeSyncController;

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  final AuthService _authService = AuthService();
  AppSession? _session;
  String? _loginNotice;
  String? _lastTimeSyncNotice;

  @override
  void initState() {
    super.initState();
    widget.timeSyncController.addListener(_handleTimeSyncChanged);
    unawaited(
      widget.timeSyncController.checkAtStartup(baseUrl: defaultApiBaseUrl),
    );
  }

  void _handleLoginSuccess(AppSession session) {
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _loginNotice = null;
    });
    unawaited(
      widget.timeSyncController.checkAtStartup(
        baseUrl: session.baseUrl,
        force: session.baseUrl != defaultApiBaseUrl,
      ),
    );
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
  void dispose() {
    widget.timeSyncController.removeListener(_handleTimeSyncChanged);
    super.dispose();
  }

  void _handleTimeSyncChanged() {
    if (!mounted) {
      return;
    }
    final state = widget.timeSyncController.state;
    final shouldWarn =
        state.lastResultCode == TimeSyncResultCode.cancelledByUser ||
        state.lastResultCode == TimeSyncResultCode.permissionDenied ||
        state.lastResultCode == TimeSyncResultCode.syncFailed ||
        state.lastResultCode == TimeSyncResultCode.serverTimeUnavailable;
    final message = state.message;
    if (!shouldWarn || message == null || message == _lastTimeSyncNotice) {
      return;
    }
    _lastTimeSyncNotice = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
      timeSyncController: widget.timeSyncController,
    );
  }
}

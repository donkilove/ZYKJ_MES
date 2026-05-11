import 'package:flutter/services.dart';

class WindowsDesktopShellService {
  WindowsDesktopShellService._();

  static const String baseTitle = '成都泽耀科技有限公司生产部-MES';
  static const MethodChannel channel = MethodChannel(
    'mes_client/windows_shell',
  );

  static Future<void> syncDesktopState({
    required bool loggedIn,
    String? username,
  }) async {
    final trimmedUsername = username?.trim() ?? '';
    final title = loggedIn && trimmedUsername.isNotEmpty
        ? '$baseTitle+$trimmedUsername'
        : baseTitle;
    final tooltip = loggedIn && trimmedUsername.isNotEmpty
        ? trimmedUsername
        : baseTitle;

    try {
      await channel.invokeMethod<void>('syncDesktopState', {
        'loggedIn': loggedIn,
        'title': title,
        'tooltip': tooltip,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<void> resetDesktopState() {
    return syncDesktopState(loggedIn: false);
  }
}

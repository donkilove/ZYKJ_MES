import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/services/windows_desktop_shell_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WindowsDesktopShellService.channel, null);
  });

  test('syncDesktopState sends logged in title and tooltip', () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WindowsDesktopShellService.channel, (
          call,
        ) async {
          capturedCall = call;
          return null;
        });

    await WindowsDesktopShellService.syncDesktopState(
      loggedIn: true,
      username: 'tester',
    );

    expect(capturedCall?.method, 'syncDesktopState');
    expect(capturedCall?.arguments, isA<Map>());
    final arguments = capturedCall!.arguments as Map<dynamic, dynamic>;
    expect(arguments['loggedIn'], isTrue);
    expect(arguments['title'], '成都泽耀科技有限公司生产部-MES+tester');
    expect(arguments['tooltip'], 'tester');
  });

  test('resetDesktopState restores base title', () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WindowsDesktopShellService.channel, (
          call,
        ) async {
          capturedCall = call;
          return null;
        });

    await WindowsDesktopShellService.resetDesktopState();

    final arguments = capturedCall!.arguments as Map<dynamic, dynamic>;
    expect(capturedCall?.method, 'syncDesktopState');
    expect(arguments['loggedIn'], isFalse);
    expect(arguments['title'], WindowsDesktopShellService.baseTitle);
    expect(arguments['tooltip'], WindowsDesktopShellService.baseTitle);
  });
}

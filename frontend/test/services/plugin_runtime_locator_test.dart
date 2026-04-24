import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/plugin_host/services/plugin_runtime_locator.dart';

void main() {
  test('resolvePythonExecutable 优先使用环境变量指定的外部运行时', () {
    final locator = PluginRuntimeLocator(
      executablePath: r'C:\ZYKJ_MES\mes_client.exe',
      environment: const {
        'MES_PYTHON_RUNTIME_DIR': r'D:\MES_RUNTIME\python',
      },
    );

    expect(
      locator.resolvePythonExecutable(),
      r'D:\MES_RUNTIME\python\python.exe',
    );
  });

  test('resolvePluginRoot 在无环境变量时回退到可执行文件旁的 plugins 目录', () {
    final locator = PluginRuntimeLocator(
      executablePath: r'C:\ZYKJ_MES\mes_client.exe',
      environment: const {},
      currentDirectory: r'C:\ZYKJ_MES',
      directoryExists: (path) => path == r'C:\ZYKJ_MES\plugins',
    );

    expect(
      locator.resolvePluginRoot(),
      r'C:\ZYKJ_MES\plugins',
    );
  });

  test('resolvePluginRoot 会从 frontend 与构建目录向上回退到仓库根 plugins', () {
    final locator = PluginRuntimeLocator(
      executablePath:
          r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend\build\windows\x64\runner\Debug\mes_client.exe',
      environment: const {},
      currentDirectory: r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend',
      directoryExists: (path) =>
          path == r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins',
    );

    expect(
      locator.resolvePluginRoot(),
      r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins',
    );
  });
}

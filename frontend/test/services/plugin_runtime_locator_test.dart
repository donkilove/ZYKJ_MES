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

  test('resolvePythonExecutable 在无环境变量时固定到仓库 plugins/runtime/python312', () {
    final locator = PluginRuntimeLocator(
      executablePath:
          r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend\build\windows\x64\runner\Debug\mes_client.exe',
      environment: const {},
      currentDirectory: r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend',
      directoryExists: (path) =>
          path == r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend' ||
          path == r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins',
    );

    expect(
      locator.resolvePythonExecutable(),
      r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins\runtime\python312\python.exe',
    );
  });

  test('resolvePluginRoot 在无环境变量时固定到仓库根 plugins', () {
    final locator = PluginRuntimeLocator(
      executablePath:
          r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend\build\windows\x64\runner\Debug\mes_client.exe',
      environment: const {},
      currentDirectory: r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend',
      directoryExists: (path) =>
          path == r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend' ||
          path == r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins',
    );

    expect(
      locator.resolvePluginRoot(),
      r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins',
    );
  });

  test('resolvePluginRoot 优先基于 executablePath 推断，不受误导性 currentDirectory 影响', () {
    final locator = PluginRuntimeLocator(
      executablePath:
          r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend\build\windows\x64\runner\Debug\mes_client.exe',
      environment: const {},
      currentDirectory: r'D:\Temp\other_project',
      directoryExists: (path) =>
          path == r'C:\Users\Donki\Desktop\ZYKJ_MES\frontend' ||
          path == r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins' ||
          path == r'D:\Temp\other_project\plugins',
    );

    expect(
      locator.resolvePluginRoot(),
      r'C:\Users\Donki\Desktop\ZYKJ_MES\plugins',
    );
  });

  test('resolvePluginRoot 不会把祖先链上无关 plugins 目录识别成仓库根', () {
    final locator = PluginRuntimeLocator(
      executablePath: r'C:\tools\launcher\mes_client.exe',
      environment: const {},
      currentDirectory: r'D:\scratch',
      directoryExists: (path) => path == r'C:\tools\plugins',
    );

    expect(
      locator.resolvePluginRoot(),
      r'C:\tools\launcher\plugins',
    );
  });

  test('resolvePluginRoot 找不到仓库标记时回退到可执行文件同级 plugins', () {
    final locator = PluginRuntimeLocator(
      executablePath: r'C:\standalone\mes_client.exe',
      environment: const {},
      currentDirectory: r'D:\scratch',
      directoryExists: (_) => false,
    );

    expect(
      locator.resolvePluginRoot(),
      r'C:\standalone\plugins',
    );
  });
}

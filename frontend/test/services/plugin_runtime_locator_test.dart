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
    );

    expect(
      locator.resolvePluginRoot(),
      r'C:\ZYKJ_MES\plugins',
    );
  });
}

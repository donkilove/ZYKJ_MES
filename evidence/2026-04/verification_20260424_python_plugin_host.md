# Python 插件宿主验证

- 执行日期：2026-04-24
- 对应主日志：`evidence/2026-04-24_Python插件宿主实施.md`
- 当前状态：已通过

## 1. 自动化验证

### Flutter 目标测试集

命令：

```powershell
flutter test test/services/plugin_catalog_service_test.dart test/services/plugin_runtime_locator_test.dart test/services/plugin_process_service_test.dart test/widgets/plugin_host_page_test.dart test/widgets/main_shell_page_registry_test.dart test/widgets/main_shell_page_test.dart -r expanded
```

结果：

- 37 项目标测试全部通过
- 覆盖插件扫描、运行时定位、进程握手、插件中心 UI、主壳入口联动

### Python 插件测试

命令：

```powershell
python -m pytest plugins/serial_assistant/tests/test_serial_bridge.py -q
```

结果：

- 1 项测试通过
- `loop://` 回环端口完成真实打开、发送、接收、关闭

### 静态检查

命令：

```powershell
flutter analyze
```

结果：

- 通过
- 中途因 `MainShellScaffold` 新增 `onOpenPluginHost` 参数触发 4 处老测试编译错误，已补齐测试调用后重新验证通过

## 2. Windows 构建与启动验证

### 构建阻塞复现

命令：

```powershell
python -u start_frontend.py --skip-pub-get --skip-bootstrap-admin
```

首次结果：

- `webview_all_windows` 在 CMake 阶段提示 `NuGet is not installed`
- 插件内置下载的 `nuget.exe` 发生完整性校验失败

### 阻塞修复

命令：

```powershell
winget install --id Microsoft.NuGet --accept-source-agreements --accept-package-agreements --silent
```

修复后观察：

- `frontend/build/windows/x64/runner/Debug/mes_client.exe` 已生成
- 受控启动命令：

```powershell
$exe='C:\Users\Donki\Desktop\ZYKJ_MES\.worktrees\python-plugin-host\frontend\build\windows\x64\runner\Debug\mes_client.exe'
$p=Start-Process -FilePath $exe -PassThru
Start-Sleep -Seconds 8
Get-Process -Id $p.Id
Stop-Process -Id $p.Id -Force
```

结果：

- 进程在 8 秒观测窗口内保持存活
- 返回：`RUNNING:<pid>`
- 说明 Windows 产物可成功拉起，不再在 WebView 依赖阶段崩溃

## 3. 结论

1. 宿主扫描、运行时定位、进程握手、主壳入口和插件中心 UI 已通过自动化验证。
2. 串口助手 PoC 的“依赖自带 + 回环串口能力”已通过真实 Python 测试。
3. Windows 构建链已经打通，产物可启动。
4. 残余限制：
   - 本轮未进行肉眼 UI 浏览级验证，只做到了构建产物可启动与进程存活验证
   - 若后续需要更高置信度，建议在真实桌面会话里补一轮手工点击验证

## 4. 迁移说明

- 无迁移，直接替换

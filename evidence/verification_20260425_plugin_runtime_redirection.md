# 插件运行时目录重定向验证

- 执行日期：2026-04-25
- 对应主日志：`evidence/2026-04-25_插件运行时目录重定向实施.md`
- 当前状态：已通过

## 1. Python 启动脚本测试

命令：

```powershell
python -m pytest backend/tests/test_start_frontend_script_unit.py plugins/serial_assistant/tests/test_launcher.py -q
```

结果：

- 4 项测试通过
- 说明：
  - 启动脚本已注入固定插件根目录和固定运行时目录
  - 仓库内置 Python 3.12 解释器可直接启动 `serial_assistant/launcher.py`
  - `launcher.py` 已能输出合法 `ready` payload
  - `launcher.py` 已改为在 embeddable runtime 下自行组装 `sys.path`

## 2. Flutter 目标测试

命令：

```powershell
flutter test test/services/plugin_runtime_locator_test.dart test/services/plugin_host_controller_test.dart test/widgets/plugin_host_page_test.dart -r expanded --concurrency=1
```

结果：

- 21 项测试全部通过
- 覆盖：
  - 运行时路径定位
  - 启动前目录/解释器检查
  - 启动失败 / 迟到回收 / 错误面板

## 3. 静态检查

命令：

```powershell
flutter analyze
```

结果：

- 通过

## 4. 运行级验证

命令：

```powershell
$python='C:\Users\Donki\Desktop\ZYKJ_MES\.worktrees\plugin-runtime-redirection\plugins\runtime\python312\python.exe'
$launcher='C:\Users\Donki\Desktop\ZYKJ_MES\.worktrees\plugin-runtime-redirection\plugins\serial_assistant\launcher.py'
Push-Location 'C:\Users\Donki\Desktop\ZYKJ_MES\.worktrees\plugin-runtime-redirection\plugins\serial_assistant'
'' | & $python $launcher
Pop-Location
```

结果：

```json
{"event": "ready", "pid": 15736, "entry_url": "http://127.0.0.1:61483/index.html", "heartbeat_url": "http://127.0.0.1:61483/__heartbeat__"}
```

说明：

- 仓库内固定解释器与插件目录组合能够直接拉起插件
- 宿主后续只需复用同一路径即可

## 5. 结论

1. 固定运行时目录口径已经打通。
2. 宿主路径定位、错误提示和运行级插件启动都可验证。
3. 在 embeddable runtime 下，插件依赖装配已改为“宿主传目录信息 + launcher 自行组装 sys.path”。
4. 运行时重定向任务已满足交付标准。

## 6. 迁移说明

- 无迁移，直接替换

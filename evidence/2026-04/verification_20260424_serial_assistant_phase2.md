# 串口助手第二阶段验证

- 执行日期：2026-04-24
- 对应主日志：`evidence/2026-04-24_串口助手第二阶段实施.md`
- 当前状态：已通过

## 1. 宿主侧自动化验证

命令：

```powershell
flutter test test/services/plugin_process_service_test.dart test/services/plugin_host_controller_test.dart test/widgets/plugin_host_page_test.dart -r expanded
```

结果：

- 12 项测试全部通过
- 覆盖：
  - `ready` 超时
  - 非法 `ready` 消息
  - 直接打开进入启动中
  - 单实例不重复启动
  - 启动失败进入异常态
  - 运行态工作区与宿主工具条

## 2. Python 串口验证

命令：

```powershell
python -m pytest plugins/serial_assistant/tests/test_serial_bridge.py -q
```

结果：

- 3 项测试全部通过
- 覆盖：
  - `loop://` 回环收发
  - `list_ports()` 包含 `loop://`
  - 关闭后再次读取抛出 `KeyError`

## 3. 静态检查

命令：

```powershell
flutter analyze lib/features/plugin_host test/services/plugin_host_controller_test.dart test/widgets/plugin_host_page_test.dart test/services/plugin_process_service_test.dart
```

结果：

- 通过

## 4. 运行级验证

命令：

```powershell
$env:PATH = "$env:LOCALAPPDATA\Microsoft\WinGet\Links;" + $env:PATH
python -u start_frontend.py --skip-pub-get --skip-bootstrap-admin
```

观察结果：

- `mes_client.exe` 被成功拉起
- `frontend/build/windows/x64/runner/Debug/mes_client.exe` 运行中
- 验证后已主动停止受控启动的 `mes_client.exe` 与对应 `dart` 进程

## 5. 结论

1. 第二阶段宿主直开链路已打通。
2. 串口助手第一页已收敛为可用工作台。
3. 自动化验证、静态检查和运行级启动验证均已通过。

## 6. 迁移说明

- 无迁移，直接替换

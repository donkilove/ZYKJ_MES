# 时间同步功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为桌面前端新增默认启用的“时间同步”能力：应用启动后以后端服务器时间为准自动检查本机时间，偏差超过 `30 秒` 时自动尝试提权修正 Windows 系统时间；若失败则明确告警，并退化为仅软件内时间校准。

**Architecture:** 后端新增无登录态依赖的服务器时间接口；前端新增 `TimeSyncController + ServerTimeService + WindowsTimeSyncService + EffectiveClock` 四层结构。启动期先用共享默认接口地址完成一次预登录检查，登录成功后若 `session.baseUrl` 与默认地址不同，则按实际会话地址补做一次检查；设置页新增“时间同步”分区，展示状态并支持手动触发；关键业务页面先在消息中心落地 `EffectiveClock`，保证软件内时间校准不是空壳状态。

**Tech Stack:** FastAPI、Pydantic、Flutter、Dart、`http`、`shared_preferences`、`flutter_test`、`integration_test`、Windows PowerShell `Start-Process -Verb RunAs`

---

> Backend 命令默认在 `backend/` 目录执行；Flutter 命令默认在 `frontend/` 目录执行。  
> Windows 桌面 `integration_test` 已知多文件批量命令不稳定，最终验证统一按“逐文件执行”写入计划。

## 文件结构

### 新增文件

- `backend/app/api/v1/endpoints/system.py`
  - 暴露 `/api/v1/system/time`，返回服务器时间快照
- `backend/app/schemas/system.py`
  - 定义服务器时间快照响应模型
- `backend/tests/test_system_time_endpoint_unit.py`
  - 覆盖时间接口无登录访问和返回结构
- `frontend/lib/core/config/runtime_endpoints.dart`
  - 统一定义默认 API Base URL，供登录页和启动时间同步共用
- `frontend/lib/core/services/effective_clock.dart`
  - 提供软件内统一“有效时间”入口和偏移量校准能力
- `frontend/lib/features/time_sync/models/time_sync_models.dart`
  - 定义服务器时间快照、结果码、模式和状态模型
- `frontend/lib/features/time_sync/services/server_time_service.dart`
  - 拉取服务器时间接口并解析响应
- `frontend/lib/features/time_sync/services/windows_time_sync_service.dart`
  - 封装 Windows 自提权改时和命令模式
- `frontend/lib/features/time_sync/presentation/time_sync_controller.dart`
  - 协调启动检查、阈值判断、系统改时、失败退化和设置页状态
- `frontend/lib/features/settings/presentation/widgets/software_time_sync_section.dart`
  - 渲染“时间同步”设置分区
- `frontend/test/services/server_time_service_test.dart`
  - 覆盖服务器时间接口解析与错误映射
- `frontend/test/services/windows_time_sync_service_test.dart`
  - 覆盖 Windows 改时结果映射和命令模式
- `frontend/test/widgets/time_sync_controller_test.dart`
  - 覆盖阈值判断、启动检查、失败退化和关闭开关
- `frontend/integration_test/time_sync_flow_test.dart`
  - 覆盖启动检测失败后退化为软件内时间校准的桌面链路

### 修改文件

- `backend/app/api/v1/api.py`
  - 注册 `system` 路由
- `backend/openapi.generated.json`
  - 同步新增时间接口契约
- `frontend/lib/main.dart`
  - 接入 `TimeSyncController`、`EffectiveClock` 和命令模式
- `frontend/lib/features/misc/presentation/login_page.dart`
  - 复用共享默认接口地址常量
- `frontend/lib/features/settings/models/software_settings_models.dart`
  - 为软件设置新增 `timeSyncEnabled`
- `frontend/lib/features/settings/services/software_settings_service.dart`
  - 持久化读取 / 保存时间同步开关
- `frontend/lib/features/settings/presentation/software_settings_controller.dart`
  - 支持更新时间同步开关
- `frontend/lib/features/settings/presentation/software_settings_page.dart`
  - 新增“时间同步”分区，并接入新部件
- `frontend/lib/features/message/presentation/message_center_page.dart`
  - 在关键业务页面优先接入 `EffectiveClock`，让消息中心的当前时间展示与日期选择边界使用统一有效时间
- `frontend/lib/features/shell/presentation/main_shell_page.dart`
  - 透传 `TimeSyncController` 到软件设置页
- `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
  - 构建软件设置页时传入 `timeSyncController` 与 `session.baseUrl`
- `frontend/test/services/software_settings_service_test.dart`
  - 覆盖时间同步开关默认值、读写和恢复默认
- `frontend/test/widgets/software_settings_controller_test.dart`
  - 覆盖 `updateTimeSyncEnabled()`
- `frontend/test/widgets/software_settings_page_test.dart`
  - 覆盖“时间同步”分区 UI、手动按钮和状态展示
- `frontend/test/widgets/message_center_page_test.dart`
  - 覆盖消息中心使用统一有效时间后的展示与交互边界
- `frontend/test/widget_test.dart`
  - 适配 `MesClientApp` 新构造参数
- `frontend/test/widgets/app_bootstrap_page_test.dart`
  - 覆盖启动时用默认接口地址触发时间同步检查
- `frontend/test/widgets/main_shell_page_test.dart`
  - 覆盖壳层中打开“时间同步”分区
- `frontend/test/widgets/main_shell_page_registry_test.dart`
  - 覆盖设置页注册时的 `timeSyncController` 注入
- `frontend/integration_test/software_settings_flow_test.dart`
  - 适配 `MesClientApp` / `MainShellPage` 新参数
- `frontend/integration_test/home_dashboard_flow_test.dart`
  - 适配 `MainShellPage` 新参数
- `frontend/integration_test/home_shell_flow_test.dart`
  - 适配 `MainShellPage` 新参数
- `frontend/integration_test/login_flow_test.dart`
  - 适配 `MesClientApp` / `MainShellPage` 新参数

## 任务 1：新增后端服务器时间接口并同步契约

**Files:**
- Create: `backend/app/schemas/system.py`
- Create: `backend/app/api/v1/endpoints/system.py`
- Modify: `backend/app/api/v1/api.py`
- Modify: `backend/openapi.generated.json`
- Test: `backend/tests/test_system_time_endpoint_unit.py`

- [ ] **Step 1: 先写失败测试，固定无登录访问和时间快照结构**

```python
import sys
import unittest
from pathlib import Path

from fastapi.testclient import TestClient


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.main import app


class SystemTimeEndpointUnitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def test_system_time_endpoint_returns_snapshot_without_auth(self) -> None:
        response = self.client.get("/api/v1/system/time")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["code"], 0)
        self.assertEqual(payload["message"], "ok")

        data = payload["data"]
        self.assertTrue(data["server_utc_iso"].endswith("Z"))
        self.assertIsInstance(data["server_timezone_offset_minutes"], int)
        self.assertIsInstance(data["sampled_at_epoch_ms"], int)
        self.assertGreater(data["sampled_at_epoch_ms"], 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 运行测试，确认接口尚不存在而失败**

Run: `pytest tests/test_system_time_endpoint_unit.py -q`

Expected: FAIL，报错包含 `404 != 200` 或路由不存在

- [ ] **Step 3: 新增 schema 与 endpoint，实现时间快照返回**

```python
# backend/app/schemas/system.py
from pydantic import BaseModel


class SystemTimeSnapshot(BaseModel):
    server_utc_iso: str
    server_timezone_offset_minutes: int
    sampled_at_epoch_ms: int
```

```python
# backend/app/api/v1/endpoints/system.py
from datetime import UTC, datetime

from fastapi import APIRouter

from app.schemas.common import ApiResponse, success_response
from app.schemas.system import SystemTimeSnapshot


router = APIRouter()


@router.get("/time", response_model=ApiResponse[SystemTimeSnapshot])
def get_system_time() -> ApiResponse[SystemTimeSnapshot]:
    now_utc = datetime.now(UTC)
    local_offset = datetime.now().astimezone().utcoffset()
    offset_minutes = int((local_offset.total_seconds() if local_offset else 0) // 60)
    iso_text = now_utc.isoformat().replace("+00:00", "Z")
    payload = SystemTimeSnapshot(
        server_utc_iso=iso_text,
        server_timezone_offset_minutes=offset_minutes,
        sampled_at_epoch_ms=int(now_utc.timestamp() * 1000),
    )
    return success_response(payload)
```

```python
# backend/app/api/v1/api.py
from app.api.v1.endpoints import (
    audits,
    auth,
    authz,
    craft,
    equipment,
    me,
    messages,
    processes,
    production,
    products,
    quality,
    roles,
    sessions,
    system,
    ui,
    users,
)

api_router.include_router(system.router, prefix="/system", tags=["System"])
```

- [ ] **Step 4: 生成 OpenAPI 契约并确认新接口被导出**

Run: `python -c "import json; from app.main import app; print(json.dumps(app.openapi(), ensure_ascii=False, indent=2))" > openapi.generated.json`

Expected: 成功生成 `openapi.generated.json`，其中包含 `/api/v1/system/time`

- [ ] **Step 5: 重新运行后端测试，确认接口通过**

Run: `pytest tests/test_system_time_endpoint_unit.py -q`

Expected: PASS，显示 `1 passed`

- [ ] **Step 6: 提交后端接口改动**

```bash
git add app/schemas/system.py app/api/v1/endpoints/system.py app/api/v1/api.py openapi.generated.json tests/test_system_time_endpoint_unit.py
git commit -m "新增服务器时间接口"
```

## 任务 2：扩展软件设置持久化，加入时间同步开关与共享默认接口地址

**Files:**
- Create: `frontend/lib/core/config/runtime_endpoints.dart`
- Modify: `frontend/lib/features/misc/presentation/login_page.dart`
- Modify: `frontend/lib/features/settings/models/software_settings_models.dart`
- Modify: `frontend/lib/features/settings/services/software_settings_service.dart`
- Modify: `frontend/lib/features/settings/presentation/software_settings_controller.dart`
- Test: `frontend/test/services/software_settings_service_test.dart`
- Test: `frontend/test/widgets/software_settings_controller_test.dart`

- [ ] **Step 1: 先写失败测试，固定 `timeSyncEnabled` 的默认值、恢复值与更新行为**

```dart
// frontend/test/services/software_settings_service_test.dart
test('load 在本地无配置时默认启用时间同步', () async {
  SharedPreferences.setMockInitialValues({});
  final service = SoftwareSettingsService(await SharedPreferences.getInstance());

  final settings = await service.load();

  expect(settings.timeSyncEnabled, isTrue);
});

test('save 会持久化时间同步开关', () async {
  SharedPreferences.setMockInitialValues({});
  final service = SoftwareSettingsService(await SharedPreferences.getInstance());

  await service.save(
    const SoftwareSettings(
      themePreference: AppThemePreference.system,
      densityPreference: AppDensityPreference.comfortable,
      launchTargetPreference: AppLaunchTargetPreference.home,
      sidebarPreference: AppSidebarPreference.expanded,
      timeSyncEnabled: false,
    ),
  );

  final settings = await service.load();
  expect(settings.timeSyncEnabled, isFalse);
});
```

```dart
// frontend/test/widgets/software_settings_controller_test.dart
test('updateTimeSyncEnabled() 会更新内存态并调用 save()', () async {
  final service = _FakeSoftwareSettingsService(
    settingsToLoad: const SoftwareSettings.defaults(),
  );
  final controller = SoftwareSettingsController(service: service);

  await controller.updateTimeSyncEnabled(false);

  expect(controller.settings.timeSyncEnabled, isFalse);
  expect(service.savedSettings.single.timeSyncEnabled, isFalse);
  expect(controller.saveMessage, '时间同步已关闭');
});
```

- [ ] **Step 2: 运行相关测试，确认新增字段和方法都尚未存在**

Run: `flutter test test/services/software_settings_service_test.dart test/widgets/software_settings_controller_test.dart`

Expected: FAIL，报错包含 `The getter 'timeSyncEnabled' isn't defined` 或 `The method 'updateTimeSyncEnabled' isn't defined`

- [ ] **Step 3: 新增共享默认接口地址常量，并扩展软件设置模型 / 服务 / 控制器**

```dart
// frontend/lib/core/config/runtime_endpoints.dart
const String defaultApiBaseUrl = String.fromEnvironment(
  'MES_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/api/v1',
);
```

```dart
// frontend/lib/features/misc/presentation/login_page.dart
import 'package:mes_client/core/config/runtime_endpoints.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    this.defaultBaseUrl = defaultApiBaseUrl,
    this.initialMessage,
    this.authService,
  });
}
```

```dart
// frontend/lib/features/settings/models/software_settings_models.dart
class SoftwareSettings {
  const SoftwareSettings({
    required this.themePreference,
    required this.densityPreference,
    required this.launchTargetPreference,
    required this.sidebarPreference,
    required this.timeSyncEnabled,
    this.lastVisitedPageCode,
  });

  const SoftwareSettings.defaults()
      : themePreference = AppThemePreference.system,
        densityPreference = AppDensityPreference.comfortable,
        launchTargetPreference = AppLaunchTargetPreference.home,
        sidebarPreference = AppSidebarPreference.expanded,
        timeSyncEnabled = true,
        lastVisitedPageCode = null;

  final bool timeSyncEnabled;

  SoftwareSettings copyWith({
    AppThemePreference? themePreference,
    AppDensityPreference? densityPreference,
    AppLaunchTargetPreference? launchTargetPreference,
    AppSidebarPreference? sidebarPreference,
    bool? timeSyncEnabled,
    Object? lastVisitedPageCode = _unsetLastVisitedPageCode,
  }) {
    return SoftwareSettings(
      themePreference: themePreference ?? this.themePreference,
      densityPreference: densityPreference ?? this.densityPreference,
      launchTargetPreference: launchTargetPreference ?? this.launchTargetPreference,
      sidebarPreference: sidebarPreference ?? this.sidebarPreference,
      timeSyncEnabled: timeSyncEnabled ?? this.timeSyncEnabled,
      lastVisitedPageCode: identical(lastVisitedPageCode, _unsetLastVisitedPageCode)
          ? this.lastVisitedPageCode
          : lastVisitedPageCode as String?,
    );
  }
}
```

```dart
// frontend/lib/features/settings/services/software_settings_service.dart
static const _timeSyncEnabledKey = '${_keyPrefix}time_sync_enabled';

Future<SoftwareSettings> load() async {
  return SoftwareSettings(
    themePreference: _parseTheme(_preferences.getString(_themeKey)),
    densityPreference: _parseDensity(_preferences.getString(_densityKey)),
    launchTargetPreference: _parseLaunchTarget(_preferences.getString(_launchTargetKey)),
    sidebarPreference: _parseSidebar(_preferences.getString(_sidebarKey)),
    timeSyncEnabled: _preferences.getBool(_timeSyncEnabledKey) ?? true,
    lastVisitedPageCode: _normalizePageCode(_preferences.getString(_lastVisitedPageKey)),
  );
}

Future<void> save(SoftwareSettings settings) async {
  await _preferences.setString(_themeKey, _themeToStorage(settings.themePreference));
  await _preferences.setString(_densityKey, _densityToStorage(settings.densityPreference));
  await _preferences.setString(_launchTargetKey, _launchTargetToStorage(settings.launchTargetPreference));
  await _preferences.setString(_sidebarKey, _sidebarToStorage(settings.sidebarPreference));
  await _preferences.setBool(_timeSyncEnabledKey, settings.timeSyncEnabled);
  // 其余 lastVisitedPageCode 逻辑保持不变
}
```

```dart
// frontend/lib/features/settings/presentation/software_settings_controller.dart
Future<void> updateTimeSyncEnabled(bool enabled) {
  return _persist(
    _settings.copyWith(timeSyncEnabled: enabled),
    successMessage: enabled ? '时间同步已启用' : '时间同步已关闭',
    failureMessage: enabled ? '时间同步启用失败' : '时间同步关闭失败',
  );
}
```

- [ ] **Step 4: 重新运行设置相关测试，确认时间同步开关已纳入持久化**

Run: `flutter test test/services/software_settings_service_test.dart test/widgets/software_settings_controller_test.dart`

Expected: PASS，相关新增断言全部通过

- [ ] **Step 5: 提交设置持久化改动**

```bash
git add lib/core/config/runtime_endpoints.dart lib/features/misc/presentation/login_page.dart lib/features/settings/models/software_settings_models.dart lib/features/settings/services/software_settings_service.dart lib/features/settings/presentation/software_settings_controller.dart test/services/software_settings_service_test.dart test/widgets/software_settings_controller_test.dart
git commit -m "扩展时间同步设置持久化"
```

## 任务 3：实现服务器时间模型与拉取服务

**Files:**
- Create: `frontend/lib/features/time_sync/models/time_sync_models.dart`
- Create: `frontend/lib/features/time_sync/services/server_time_service.dart`
- Test: `frontend/test/services/server_time_service_test.dart`

- [ ] **Step 1: 先写失败测试，固定服务器时间快照解析与错误映射**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';

void main() {
  test('fetchSnapshot 会解析服务器时间快照', () async {
    final service = ServerTimeService(
      client: MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/api/v1/system/time');
        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'ok',
            'data': {
              'server_utc_iso': '2026-04-20T02:00:45Z',
              'server_timezone_offset_minutes': 480,
              'sampled_at_epoch_ms': 1776650445000,
            },
          }),
          200,
        );
      }),
    );

    final snapshot = await service.fetchSnapshot(
      baseUrl: 'http://127.0.0.1:8000/api/v1',
    );

    expect(snapshot.serverUtc, DateTime.parse('2026-04-20T02:00:45Z'));
    expect(snapshot.serverTimezoneOffsetMinutes, 480);
    expect(snapshot.sampledAtEpochMs, 1776650445000);
  });

  test('fetchSnapshot 在非 200 时抛出 ApiException', () async {
    final service = ServerTimeService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'server unavailable'}),
          503,
        );
      }),
    );

    await expectLater(
      () => service.fetchSnapshot(baseUrl: 'http://127.0.0.1:8000/api/v1'),
      throwsA(isA<ApiException>()),
    );
  });
}
```

- [ ] **Step 2: 运行服务测试，确认模型和服务尚未实现**

Run: `flutter test test/services/server_time_service_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ServerTimeService'`

- [ ] **Step 3: 新增时间同步模型与服务器时间服务**

```dart
// frontend/lib/features/time_sync/models/time_sync_models.dart
enum TimeSyncResultCode {
  idle,
  success,
  skippedWithinThreshold,
  cancelledByUser,
  permissionDenied,
  syncFailed,
  serverTimeUnavailable,
}

enum TimeSyncMode {
  disabled,
  systemTimeOk,
  systemTimeCorrected,
  softwareTimeCalibrated,
  unavailable,
}

class ServerTimeSnapshot {
  const ServerTimeSnapshot({
    required this.serverUtc,
    required this.serverTimezoneOffsetMinutes,
    required this.sampledAtEpochMs,
  });

  final DateTime serverUtc;
  final int serverTimezoneOffsetMinutes;
  final int sampledAtEpochMs;

  factory ServerTimeSnapshot.fromJson(Map<String, dynamic> json) {
    return ServerTimeSnapshot(
      serverUtc: DateTime.parse(json['server_utc_iso'] as String).toUtc(),
      serverTimezoneOffsetMinutes: json['server_timezone_offset_minutes'] as int? ?? 0,
      sampledAtEpochMs: json['sampled_at_epoch_ms'] as int? ?? 0,
    );
  }
}

class TimeSyncState {
  const TimeSyncState({
    required this.mode,
    required this.lastResultCode,
    this.serverUtc,
    this.localUtc,
    this.drift,
    this.serverOffset,
    this.lastCheckedAt,
    this.message,
  });

  const TimeSyncState.initial()
      : mode = TimeSyncMode.unavailable,
        lastResultCode = TimeSyncResultCode.idle,
        serverUtc = null,
        localUtc = null,
        drift = null,
        serverOffset = null,
        lastCheckedAt = null,
        message = null;

  final TimeSyncMode mode;
  final TimeSyncResultCode lastResultCode;
  final DateTime? serverUtc;
  final DateTime? localUtc;
  final Duration? drift;
  final Duration? serverOffset;
  final DateTime? lastCheckedAt;
  final String? message;

  TimeSyncState copyWith({
    TimeSyncMode? mode,
    TimeSyncResultCode? lastResultCode,
    DateTime? serverUtc,
    DateTime? localUtc,
    Duration? drift,
    Duration? serverOffset,
    DateTime? lastCheckedAt,
    String? message,
  }) {
    return TimeSyncState(
      mode: mode ?? this.mode,
      lastResultCode: lastResultCode ?? this.lastResultCode,
      serverUtc: serverUtc ?? this.serverUtc,
      localUtc: localUtc ?? this.localUtc,
      drift: drift ?? this.drift,
      serverOffset: serverOffset ?? this.serverOffset,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      message: message ?? this.message,
    );
  }
}
```

```dart
// frontend/lib/features/time_sync/services/server_time_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';

class ServerTimeService {
  ServerTimeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) async {
    final uri = Uri.parse('$baseUrl/system/time');
    final response = await _client
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 15));

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(decoded, response.statusCode), response.statusCode);
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('获取服务器时间失败：响应数据为空', response.statusCode);
    }
    return ServerTimeSnapshot.fromJson(data);
  }

  String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    final message = body['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return '获取服务器时间失败，状态码 $statusCode';
  }
}
```

- [ ] **Step 4: 重新运行服务器时间服务测试，确认解析行为通过**

Run: `flutter test test/services/server_time_service_test.dart`

Expected: PASS，显示 `2 tests passed`

- [ ] **Step 5: 提交服务器时间模型与服务**

```bash
git add lib/features/time_sync/models/time_sync_models.dart lib/features/time_sync/services/server_time_service.dart test/services/server_time_service_test.dart
git commit -m "新增服务器时间拉取服务"
```

## 任务 4：实现有效时间入口、Windows 改时服务与时间同步协调器

**Files:**
- Create: `frontend/lib/core/services/effective_clock.dart`
- Create: `frontend/lib/features/time_sync/services/windows_time_sync_service.dart`
- Create: `frontend/lib/features/time_sync/presentation/time_sync_controller.dart`
- Test: `frontend/test/services/windows_time_sync_service_test.dart`
- Test: `frontend/test/widgets/time_sync_controller_test.dart`

- [ ] **Step 1: 先写失败测试，固定阈值判断、用户取消 UAC 和软件内时间校准**

```dart
// frontend/test/widgets/time_sync_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

void main() {
  test('偏差未超过 30 秒时不会触发系统改时', () async {
    final settingsController = SoftwareSettingsController.memory();
    final effectiveClock = EffectiveClock();
    final syncService = _FakeWindowsTimeSyncService();
    final controller = TimeSyncController(
      softwareSettingsController: settingsController,
      serverTimeService: _FakeServerTimeService(
        snapshot: ServerTimeSnapshot(
          serverUtc: DateTime.utc(2026, 4, 20, 2, 0, 10),
          serverTimezoneOffsetMinutes: 480,
          sampledAtEpochMs: DateTime.utc(2026, 4, 20, 2, 0, 10).millisecondsSinceEpoch,
        ),
      ),
      systemTimeSyncService: syncService,
      effectiveClock: effectiveClock,
      nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 0),
    );

    await controller.checkAtStartup(baseUrl: 'http://127.0.0.1:8000/api/v1');

    expect(syncService.callCount, 0);
    expect(controller.state.mode, TimeSyncMode.systemTimeOk);
    expect(effectiveClock.isCalibrated, isFalse);
  });

  test('系统改时失败时会退化为软件内时间校准', () async {
    final settingsController = SoftwareSettingsController.memory();
    final effectiveClock = EffectiveClock();
    final controller = TimeSyncController(
      softwareSettingsController: settingsController,
      serverTimeService: _FakeServerTimeService(
        snapshot: ServerTimeSnapshot(
          serverUtc: DateTime.utc(2026, 4, 20, 2, 1, 0),
          serverTimezoneOffsetMinutes: 480,
          sampledAtEpochMs: DateTime.utc(2026, 4, 20, 2, 1, 0).millisecondsSinceEpoch,
        ),
      ),
      systemTimeSyncService: _FakeWindowsTimeSyncService(
        result: TimeSyncResultCode.cancelledByUser,
      ),
      effectiveClock: effectiveClock,
      nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 0),
    );

    await controller.checkAtStartup(baseUrl: 'http://127.0.0.1:8000/api/v1');

    expect(controller.state.mode, TimeSyncMode.softwareTimeCalibrated);
    expect(controller.state.lastResultCode, TimeSyncResultCode.cancelledByUser);
    expect(effectiveClock.isCalibrated, isTrue);
  });
}
```

```dart
// frontend/test/services/windows_time_sync_service_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

void main() {
  test('requestElevatedSync 读取结果文件后返回 success', () async {
    final resultFile = File('${Directory.systemTemp.path}\\mes_time_sync_result.json');
    await resultFile.writeAsString(jsonEncode({'code': 'success'}));
    final service = WindowsTimeSyncService(
      processRunner: (_, __) async => ProcessResult(1, 0, '', ''),
      resultFileFactory: () => resultFile,
      executablePath: 'C:\\\\demo\\\\mes_client.exe',
    );

    final result = await service.requestElevatedSync(
      targetUtc: DateTime.utc(2026, 4, 20, 2, 0, 45),
    );

    expect(result, TimeSyncResultCode.success);
  });
}
```

- [ ] **Step 2: 运行新增测试，确认控制器、有效时间和 Windows 改时服务都尚未实现**

Run: `flutter test test/services/windows_time_sync_service_test.dart test/widgets/time_sync_controller_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'TimeSyncController'`

- [ ] **Step 3: 新增有效时间入口与 Windows 改时服务**

```dart
// frontend/lib/core/services/effective_clock.dart
import 'package:flutter/foundation.dart';

class EffectiveClock extends ChangeNotifier {
  Duration _serverOffset = Duration.zero;
  bool _calibrated = false;

  DateTime now() => DateTime.now().add(_serverOffset);

  Duration get serverOffset => _serverOffset;
  bool get isCalibrated => _calibrated;

  void applyServerOffset(Duration offset) {
    _serverOffset = offset;
    _calibrated = true;
    notifyListeners();
  }

  void clearCalibration() {
    _serverOffset = Duration.zero;
    _calibrated = false;
    notifyListeners();
  }
}
```

```dart
// frontend/lib/features/time_sync/services/windows_time_sync_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:path/path.dart' as p;

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class WindowsTimeSyncService {
  WindowsTimeSyncService({
    ProcessRunner? processRunner,
    File Function()? resultFileFactory,
    String? executablePath,
  })  : processRunner = processRunner ?? Process.run,
        resultFileFactory = resultFileFactory ??
            (() => File(
                  p.join(
                    Directory.systemTemp.path,
                    'mes_time_sync_${DateTime.now().millisecondsSinceEpoch}.json',
                  ),
                )),
        executablePath = executablePath ?? Platform.resolvedExecutable;

  final ProcessRunner processRunner;
  final File Function() resultFileFactory;
  final String executablePath;

  bool isCommand(List<String> args) => args.contains('--sync-system-time');

  Future<TimeSyncResultCode> requestElevatedSync({
    required DateTime targetUtc,
  }) async {
    final resultFile = resultFileFactory();
    final arguments = <String>[
      '--sync-system-time',
      '--target-utc-iso=${targetUtc.toIso8601String()}',
      '--result-file=${resultFile.path}',
    ];

    final command = [
      '-NoProfile',
      '-Command',
      "Start-Process -FilePath '$executablePath' -Verb RunAs -ArgumentList '${arguments.join(' ')}' -Wait",
    ];

    final result = await processRunner('powershell', command);
    if (await resultFile.exists()) {
      final payload = jsonDecode(await resultFile.readAsString()) as Map<String, dynamic>;
      return _parseResultCode(payload['code'] as String?);
    }
    return _mapProcessFailure(result);
  }

  Future<int> handleCommandMode(List<String> args) async {
    final targetArg = args.firstWhere(
      (item) => item.startsWith('--target-utc-iso='),
      orElse: () => '',
    );
    final resultFileArg = args.firstWhere(
      (item) => item.startsWith('--result-file='),
      orElse: () => '',
    );
    if (targetArg.isEmpty || resultFileArg.isEmpty) {
      return 2;
    }

    final targetUtc = DateTime.parse(
      targetArg.substring('--target-utc-iso='.length),
    ).toUtc();
    final resultFile = File(resultFileArg.substring('--result-file='.length));
    try {
      await processRunner('powershell', [
        '-NoProfile',
        '-Command',
        "Set-Date -Date '${targetUtc.toLocal().toIso8601String()}'",
      ]);
      await resultFile.writeAsString(jsonEncode({'code': 'success'}));
      return 0;
    } catch (error) {
      await resultFile.writeAsString(
        jsonEncode({'code': 'sync_failed', 'message': error.toString()}),
      );
      return 1;
    }
  }

  TimeSyncResultCode _parseResultCode(String? code) {
    switch (code) {
      case 'success':
        return TimeSyncResultCode.success;
      case 'cancelled_by_user':
        return TimeSyncResultCode.cancelledByUser;
      case 'permission_denied':
        return TimeSyncResultCode.permissionDenied;
      default:
        return TimeSyncResultCode.syncFailed;
    }
  }

  TimeSyncResultCode _mapProcessFailure(ProcessResult result) {
    final stderrText = '${result.stderr}'.toLowerCase();
    if (stderrText.contains('canceled by the user') ||
        stderrText.contains('operation was canceled')) {
      return TimeSyncResultCode.cancelledByUser;
    }
    if (stderrText.contains('access is denied')) {
      return TimeSyncResultCode.permissionDenied;
    }
    return TimeSyncResultCode.syncFailed;
  }
}
```

- [ ] **Step 4: 新增时间同步协调器，把阈值判断、系统改时和软件内校准收口到一个控制器**

```dart
// frontend/lib/features/time_sync/presentation/time_sync_controller.dart
import 'package:flutter/foundation.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

class TimeSyncController extends ChangeNotifier {
  TimeSyncController({
    required this.softwareSettingsController,
    required this.serverTimeService,
    required this.systemTimeSyncService,
    required this.effectiveClock,
    DateTime Function()? nowProvider,
  })  : nowProvider = nowProvider ?? DateTime.now,
        _state = const TimeSyncState.initial() {
    softwareSettingsController.addListener(_handleSettingsChanged);
  }

  static const driftThreshold = Duration(seconds: 30);

  final SoftwareSettingsController softwareSettingsController;
  final ServerTimeService serverTimeService;
  final WindowsTimeSyncService systemTimeSyncService;
  final EffectiveClock effectiveClock;
  final DateTime Function() nowProvider;

  TimeSyncState _state;
  String? _lastCheckedBaseUrl;

  TimeSyncState get state => _state;

  Future<void> checkAtStartup({
    required String baseUrl,
    bool force = false,
  }) async {
    if (!softwareSettingsController.settings.timeSyncEnabled) {
      _setDisabledState();
      return;
    }
    if (!force && _lastCheckedBaseUrl == baseUrl && _state.lastCheckedAt != null) {
      return;
    }

    final requestedAt = nowProvider().toUtc();
    try {
      final snapshot = await serverTimeService.fetchSnapshot(baseUrl: baseUrl);
      final receivedAt = nowProvider().toUtc();
      final roundTrip = receivedAt.difference(requestedAt);
      final estimatedServerNow = snapshot.serverUtc.add(roundTrip ~/ 2);
      final drift = receivedAt.difference(estimatedServerNow);
      final offset = estimatedServerNow.difference(receivedAt);
      _lastCheckedBaseUrl = baseUrl;

      if (drift.abs() <= driftThreshold) {
        effectiveClock.clearCalibration();
        _state = TimeSyncState(
          mode: TimeSyncMode.systemTimeOk,
          lastResultCode: TimeSyncResultCode.skippedWithinThreshold,
          serverUtc: snapshot.serverUtc,
          localUtc: receivedAt,
          drift: drift,
          serverOffset: Duration.zero,
          lastCheckedAt: receivedAt,
          message: '系统时间正常',
        );
        notifyListeners();
        return;
      }

      final result = await systemTimeSyncService.requestElevatedSync(
        targetUtc: estimatedServerNow,
      );
      if (result == TimeSyncResultCode.success) {
        effectiveClock.clearCalibration();
        _state = TimeSyncState(
          mode: TimeSyncMode.systemTimeCorrected,
          lastResultCode: result,
          serverUtc: snapshot.serverUtc,
          localUtc: receivedAt,
          drift: drift,
          serverOffset: Duration.zero,
          lastCheckedAt: receivedAt,
          message: '检测到时间偏差 ${drift.inSeconds.abs()} 秒，已自动修正',
        );
      } else {
        effectiveClock.applyServerOffset(offset);
        _state = TimeSyncState(
          mode: TimeSyncMode.softwareTimeCalibrated,
          lastResultCode: result,
          serverUtc: snapshot.serverUtc,
          localUtc: receivedAt,
          drift: drift,
          serverOffset: offset,
          lastCheckedAt: receivedAt,
          message: _fallbackMessage(result),
        );
      }
    } catch (_) {
      _state = TimeSyncState(
        mode: TimeSyncMode.unavailable,
        lastResultCode: TimeSyncResultCode.serverTimeUnavailable,
        lastCheckedAt: nowProvider().toUtc(),
        message: '无法连接服务器时间接口，暂未完成同步',
      );
    }
    notifyListeners();
  }

  Future<void> calibrateSoftwareClock({required String baseUrl}) async {
    final requestedAt = nowProvider().toUtc();
    final snapshot = await serverTimeService.fetchSnapshot(baseUrl: baseUrl);
    final receivedAt = nowProvider().toUtc();
    final roundTrip = receivedAt.difference(requestedAt);
    final estimatedServerNow = snapshot.serverUtc.add(roundTrip ~/ 2);
    final offset = estimatedServerNow.difference(receivedAt);
    effectiveClock.applyServerOffset(offset);
    _state = TimeSyncState(
      mode: TimeSyncMode.softwareTimeCalibrated,
      lastResultCode: TimeSyncResultCode.syncFailed,
      serverUtc: snapshot.serverUtc,
      localUtc: receivedAt,
      drift: receivedAt.difference(estimatedServerNow),
      serverOffset: offset,
      lastCheckedAt: receivedAt,
      message: '已重新校准软件内时间',
    );
    notifyListeners();
  }

  void _handleSettingsChanged() {
    if (!softwareSettingsController.settings.timeSyncEnabled) {
      _setDisabledState();
    }
  }

  void _setDisabledState() {
    effectiveClock.clearCalibration();
    _state = const TimeSyncState(
      mode: TimeSyncMode.disabled,
      lastResultCode: TimeSyncResultCode.idle,
      message: '时间同步已关闭',
    );
    notifyListeners();
  }

  String _fallbackMessage(TimeSyncResultCode result) {
    switch (result) {
      case TimeSyncResultCode.cancelledByUser:
        return '你已取消管理员授权，系统时间未修改，当前已切换为软件内时间校准';
      case TimeSyncResultCode.permissionDenied:
        return '未能修改 Windows 系统时间，当前已切换为软件内时间校准，软件内业务时间仍按服务器时间对齐';
      default:
        return '未能修改 Windows 系统时间，当前已切换为软件内时间校准，软件内业务时间仍按服务器时间对齐';
    }
  }
}
```

- [ ] **Step 5: 运行核心时间同步测试，确认控制器和系统改时链路通过**

Run: `flutter test test/services/windows_time_sync_service_test.dart test/widgets/time_sync_controller_test.dart`

Expected: PASS，显示所有新增测试通过

- [ ] **Step 6: 提交时间同步核心服务**

```bash
git add lib/core/services/effective_clock.dart lib/features/time_sync/services/windows_time_sync_service.dart lib/features/time_sync/presentation/time_sync_controller.dart test/services/windows_time_sync_service_test.dart test/widgets/time_sync_controller_test.dart
git commit -m "新增时间同步核心服务"
```

## 任务 5：接入应用启动检查、命令模式与预登录默认接口地址

**Files:**
- Modify: `frontend/lib/main.dart`
- Modify: `frontend/test/widget_test.dart`
- Modify: `frontend/test/widgets/app_bootstrap_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定应用启动会持有 `TimeSyncController` 并用默认接口地址发起检查**

```dart
// frontend/test/widgets/app_bootstrap_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/config/runtime_endpoints.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';
import 'package:mes_client/main.dart';

void main() {
  testWidgets('应用启动后会使用默认接口地址触发一次时间同步检查', (tester) async {
    final serverTimeService = _ProbeServerTimeService();
    final timeSyncController = TimeSyncController(
      softwareSettingsController: SoftwareSettingsController.memory(),
      serverTimeService: serverTimeService,
      systemTimeSyncService: _FakeWindowsTimeSyncService(),
      effectiveClock: EffectiveClock(),
    );

    await tester.pumpWidget(
      MesClientApp(
        softwareSettingsController: SoftwareSettingsController.memory(),
        timeSyncController: timeSyncController,
      ),
    );
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(serverTimeService.baseUrls.single, defaultApiBaseUrl);
  });

  testWidgets('启动期改时失败时会展示退化提示', (tester) async {
    final settingsController = SoftwareSettingsController.memory();
    final timeSyncController = TimeSyncController(
      softwareSettingsController: settingsController,
      serverTimeService: _FakeServerTimeService(
        snapshot: ServerTimeSnapshot(
          serverUtc: DateTime.utc(2026, 4, 20, 2, 1, 0),
          serverTimezoneOffsetMinutes: 480,
          sampledAtEpochMs: DateTime.utc(2026, 4, 20, 2, 1, 0).millisecondsSinceEpoch,
        ),
      ),
      systemTimeSyncService: _FakeWindowsTimeSyncService(
        result: TimeSyncResultCode.cancelledByUser,
      ),
      effectiveClock: EffectiveClock(),
      nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 0),
    );

    await tester.pumpWidget(
      MesClientApp(
        softwareSettingsController: settingsController,
        timeSyncController: timeSyncController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('你已取消管理员授权，系统时间未修改，当前已切换为软件内时间校准'), findsOneWidget);
  });
}
```

```dart
// frontend/test/widget_test.dart
testWidgets('默认 memory controller 也能驱动应用入口和时间同步控制器', (tester) async {
  final settingsController = SoftwareSettingsController.memory();
  final timeSyncController = TimeSyncController(
    softwareSettingsController: settingsController,
    serverTimeService: _ThrowingServerTimeService(),
    systemTimeSyncService: _FakeWindowsTimeSyncService(),
    effectiveClock: EffectiveClock(),
  );

  await tester.pumpWidget(
    MesClientApp(
      softwareSettingsController: settingsController,
      timeSyncController: timeSyncController,
    ),
  );

  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  expect(app.themeMode, ThemeMode.system);
});
```

- [ ] **Step 2: 运行应用入口测试，确认 `MesClientApp` 还没有时间同步依赖**

Run: `flutter test test/widget_test.dart test/widgets/app_bootstrap_page_test.dart`

Expected: FAIL，报错包含 `No named parameter with the name 'timeSyncController'`

- [ ] **Step 3: 修改 `main.dart`，接入时间同步控制器并支持命令模式**

```dart
// frontend/lib/main.dart
import 'dart:async';
import 'dart:io';

import 'package:mes_client/core/config/runtime_endpoints.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final softwareSettingsController = await bootstrapSoftwareSettingsController();
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
  String? _lastTimeSyncNotice;

  @override
  void initState() {
    super.initState();
    widget.timeSyncController.addListener(_handleTimeSyncChanged);
    unawaited(
      widget.timeSyncController.checkAtStartup(baseUrl: defaultApiBaseUrl),
    );
  }

  @override
  void dispose() {
    widget.timeSyncController.removeListener(_handleTimeSyncChanged);
    super.dispose();
  }

  void _handleLoginSuccess(AppSession session) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }
}
```

- [ ] **Step 4: 更新应用入口测试，使其显式传入 `TimeSyncController`**

```dart
// frontend/test/widget_test.dart 与 frontend/test/widgets/app_bootstrap_page_test.dart
final settingsController = SoftwareSettingsController.memory();
final timeSyncController = TimeSyncController(
  softwareSettingsController: settingsController,
  serverTimeService: _FakeServerTimeService(),
  systemTimeSyncService: _FakeWindowsTimeSyncService(),
  effectiveClock: EffectiveClock(),
);

await tester.pumpWidget(
  MesClientApp(
    softwareSettingsController: settingsController,
    timeSyncController: timeSyncController,
  ),
);
```

- [ ] **Step 5: 重新运行应用入口测试，确认启动期时间同步接线通过**

Run: `flutter test test/widget_test.dart test/widgets/app_bootstrap_page_test.dart`

Expected: PASS，应用入口相关测试通过

- [ ] **Step 6: 提交启动期接线改动**

```bash
git add lib/main.dart test/widget_test.dart test/widgets/app_bootstrap_page_test.dart
git commit -m "接入启动期时间同步主链路"
```

## 任务 6：接入设置页“时间同步”分区，并把控制器透传到主壳层

**Files:**
- Create: `frontend/lib/features/settings/presentation/widgets/software_time_sync_section.dart`
- Modify: `frontend/lib/features/settings/presentation/software_settings_page.dart`
- Modify: `frontend/lib/features/message/presentation/message_center_page.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page.dart`
- Modify: `frontend/lib/features/shell/presentation/main_shell_page_registry.dart`
- Test: `frontend/test/widgets/software_settings_page_test.dart`
- Test: `frontend/test/widgets/message_center_page_test.dart`
- Test: `frontend/test/widgets/main_shell_page_test.dart`
- Test: `frontend/test/widgets/main_shell_page_registry_test.dart`

- [ ] **Step 1: 先写失败测试，固定“时间同步”分区的渲染、切换和手动按钮**

```dart
// frontend/test/widgets/software_settings_page_test.dart
testWidgets('SoftwareSettingsPage 渲染时间同步分区与总开关', (tester) async {
  final settingsController = SoftwareSettingsController.memory();
  final timeSyncController = TimeSyncController(
    softwareSettingsController: settingsController,
    serverTimeService: _FakeServerTimeService(
      snapshot: ServerTimeSnapshot(
        serverUtc: DateTime.utc(2026, 4, 20, 2, 0, 45),
        serverTimezoneOffsetMinutes: 480,
        sampledAtEpochMs: DateTime.utc(2026, 4, 20, 2, 0, 45).millisecondsSinceEpoch,
      ),
    ),
    systemTimeSyncService: _FakeWindowsTimeSyncService(),
    effectiveClock: EffectiveClock(),
    nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 45),
  );
  await timeSyncController.checkAtStartup(baseUrl: 'http://127.0.0.1:8000/api/v1');

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SoftwareSettingsPage(
          controller: settingsController,
          timeSyncController: timeSyncController,
          apiBaseUrl: 'http://127.0.0.1:8000/api/v1',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('时间同步').first);
  await tester.pumpAndSettle();

  expect(find.text('启用时间同步'), findsOneWidget);
  expect(find.text('立即检查并同步'), findsOneWidget);
  expect(find.text('仅重新校准软件内时间'), findsOneWidget);
  expect(find.textContaining('服务器时间：'), findsOneWidget);
  expect(find.textContaining('本机时间：'), findsOneWidget);
  expect(find.textContaining('最近同步结果：'), findsOneWidget);
  expect(find.textContaining('最近同步时间：'), findsOneWidget);
});

testWidgets('关闭时间同步开关后会更新设置并切到 disabled 状态', (tester) async {
  final settingsController = SoftwareSettingsController.memory();
  final timeSyncController = TimeSyncController(
    softwareSettingsController: settingsController,
    serverTimeService: _FakeServerTimeService(),
    systemTimeSyncService: _FakeWindowsTimeSyncService(),
    effectiveClock: EffectiveClock(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SoftwareSettingsPage(
          controller: settingsController,
          timeSyncController: timeSyncController,
          apiBaseUrl: 'http://127.0.0.1:8000/api/v1',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('时间同步').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(SwitchListTile));
  await tester.pumpAndSettle();

  expect(settingsController.settings.timeSyncEnabled, isFalse);
  expect(timeSyncController.state.mode, TimeSyncMode.disabled);
});
```

```dart
// frontend/test/widgets/message_center_page_test.dart
Future<void> _pumpMessageCenterPage(
  WidgetTester tester, {
  required _FakeMessageService service,
  DateTime Function()? nowProvider,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MessageCenterPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          service: service,
          userService: _FakeUserService(),
          nowProvider: nowProvider,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

testWidgets('message center 使用统一有效时间展示当前生效时间', (tester) async {
  final service = _FakeMessageService();

  await _pumpMessageCenterPage(
    tester,
    service: service,
    nowProvider: () => DateTime(2026, 4, 20, 10, 30),
  );

  expect(find.text('2026-04-20 10:30'), findsOneWidget);
});
```

```dart
// frontend/test/widgets/main_shell_page_test.dart
testWidgets('主壳层可打开时间同步分区并显示当前模式', (tester) async {
  final settingsController = SoftwareSettingsController.memory();
  final timeSyncController = TimeSyncController(
    softwareSettingsController: settingsController,
    serverTimeService: _FakeServerTimeService(),
    systemTimeSyncService: _FakeWindowsTimeSyncService(),
    effectiveClock: EffectiveClock(),
  );

  await _pumpMainShellPage(
    tester,
    softwareSettingsController: settingsController,
    timeSyncController: timeSyncController,
    onLogout: () {},
  );

  await tester.tap(find.byKey(const ValueKey('main-shell-entry-software-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('时间同步').first);
  await tester.pumpAndSettle();

  expect(find.textContaining('当前模式：'), findsOneWidget);
});
```

- [ ] **Step 2: 运行页面测试，确认新分区和壳层透传都尚未实现**

Run: `flutter test test/widgets/software_settings_page_test.dart test/widgets/message_center_page_test.dart test/widgets/main_shell_page_test.dart test/widgets/main_shell_page_registry_test.dart`

Expected: FAIL，报错包含 `No named parameter with the name 'timeSyncController'` 或找不到 `时间同步`

- [ ] **Step 3: 新增时间同步分区组件，并把设置页扩展为三分区结构**

```dart
// frontend/lib/features/settings/presentation/widgets/software_time_sync_section.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';

class SoftwareTimeSyncSection extends StatelessWidget {
  const SoftwareTimeSyncSection({
    super.key,
    required this.softwareSettingsController,
    required this.timeSyncController,
    required this.apiBaseUrl,
  });

  final SoftwareSettingsController softwareSettingsController;
  final TimeSyncController timeSyncController;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final settings = softwareSettingsController.settings;
    final state = timeSyncController.state;
    return Column(
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('启用时间同步'),
            subtitle: const Text('启动时自动检查并在偏差超阈值时尝试修正 Windows 时间'),
            value: settings.timeSyncEnabled,
            onChanged: (value) {
              unawaited(softwareSettingsController.updateTimeSyncEnabled(value));
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('同步策略摘要'),
                const SizedBox(height: 8),
                const Text('权威时间源：后端服务器时间'),
                const Text('自动修正阈值：30 秒'),
                if (state.serverUtc != null) Text('服务器时间：${_formatDateTime(state.serverUtc!)}'),
                if (state.localUtc != null) Text('本机时间：${_formatDateTime(state.localUtc!)}'),
                Text('当前模式：${_modeLabel(state.mode)}'),
                if (state.drift != null) Text('当前偏差：${state.drift!.inSeconds.abs()} 秒'),
                Text('最近同步结果：${_resultLabel(state.lastResultCode)}'),
                if (state.lastCheckedAt != null)
                  Text('最近同步时间：${_formatDateTime(state.lastCheckedAt!)}'),
                if (state.message != null) Text(state.message!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: settings.timeSyncEnabled
                  ? () => unawaited(timeSyncController.checkAtStartup(baseUrl: apiBaseUrl, force: true))
                  : null,
              child: const Text('立即检查并同步'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: settings.timeSyncEnabled
                  ? () => unawaited(timeSyncController.calibrateSoftwareClock(baseUrl: apiBaseUrl))
                  : null,
              child: const Text('仅重新校准软件内时间'),
            ),
          ],
        ),
      ],
    );
  }

  String _modeLabel(TimeSyncMode mode) {
    switch (mode) {
      case TimeSyncMode.disabled:
        return '未启用';
      case TimeSyncMode.systemTimeOk:
        return '系统时间同步';
      case TimeSyncMode.systemTimeCorrected:
        return '已自动修正';
      case TimeSyncMode.softwareTimeCalibrated:
        return '软件内校准';
      case TimeSyncMode.unavailable:
        return '不可用';
    }
  }

  String _resultLabel(TimeSyncResultCode code) {
    switch (code) {
      case TimeSyncResultCode.idle:
        return '尚未执行';
      case TimeSyncResultCode.success:
        return '系统时间已修正';
      case TimeSyncResultCode.skippedWithinThreshold:
        return '偏差未超过阈值';
      case TimeSyncResultCode.cancelledByUser:
        return '用户取消管理员授权';
      case TimeSyncResultCode.permissionDenied:
        return '系统拒绝改时';
      case TimeSyncResultCode.syncFailed:
        return '系统改时失败';
      case TimeSyncResultCode.serverTimeUnavailable:
        return '服务器时间不可用';
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }
}
```

```dart
// frontend/lib/features/settings/presentation/software_settings_page.dart
enum _SettingsSectionType { appearance, layout, timeSync }

// 在导航区新增
_SectionNavTile(
  title: '时间同步',
  subtitle: '服务器对时与系统改时',
  selected: selectedSection == _SettingsSectionType.timeSync,
  onTap: () => onSelect(_SettingsSectionType.timeSync),
),

// 构造器改为
class SoftwareSettingsPage extends StatefulWidget {
  const SoftwareSettingsPage({
    super.key,
    required this.controller,
    required this.timeSyncController,
    required this.apiBaseUrl,
  });

  final SoftwareSettingsController controller;
  final TimeSyncController timeSyncController;
  final String apiBaseUrl;
}

// 内容分发新增
case _SettingsSectionType.timeSync:
  return SoftwareTimeSyncSection(
    softwareSettingsController: controller,
    timeSyncController: widget.timeSyncController,
    apiBaseUrl: widget.apiBaseUrl,
  );
```

- [ ] **Step 4: 修改消息中心、主壳层与页面注册表，透传 `timeSyncController`、`session.baseUrl` 和统一有效时间**

```dart
// frontend/lib/features/message/presentation/message_center_page.dart
class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.canPublishAnnouncement = false,
    this.canViewDetail = false,
    this.canUseJump = false,
    this.onUnreadCountChanged,
    this.onNavigateToPage,
    this.service,
    this.userService,
    this.refreshTick = 0,
    this.onPickDateRange,
    this.routePayloadJson,
    DateTime Function()? nowProvider,
  }) : nowProvider = nowProvider ?? DateTime.now;

  final DateTime Function() nowProvider;
}

// showDateRangePicker 和当前生效时间展示都改成使用 widget.nowProvider()
final now = widget.nowProvider();
picked = await showDateRangePicker(
  context: context,
  firstDate: DateTime(now.year - 2, now.month, now.day),
  lastDate: now,
  initialDateRange: _dateRange,
);

subtitle: Text(_formatLocalDateTime(now)),
```

```dart
// frontend/lib/features/shell/presentation/main_shell_page.dart
class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.softwareSettingsController,
    required this.timeSyncController,
    this.authService,
    this.authzService,
    this.pageCatalogService,
    this.messageService,
    this.messageWsServiceFactory,
    this.homeDashboardService,
    this.userPageBuilder,
  });

  final TimeSyncController timeSyncController;
}
```

```dart
// frontend/lib/features/shell/presentation/main_shell_page_registry.dart
case 'message':
  return MessageCenterPage(
    session: session,
    service: messageService,
    onLogout: onLogout,
    canPublishAnnouncement: messageCapabilityCodes.contains(
      'feature.message.announcement.publish',
    ),
    canViewDetail: messageCapabilityCodes.contains(
      'feature.message.detail.view',
    ),
    canUseJump: true,
    refreshTick: state.messageRefreshTick,
    onUnreadCountChanged: onUnreadCountChanged,
    onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
      onNavigateToPageTarget(
        pageCode: pageCode,
        tabCode: tabCode,
        routePayloadJson: routePayloadJson,
      );
    },
    routePayloadJson: state.preferredRoutePayloadJson,
    nowProvider: timeSyncController.effectiveClock.now,
  );

case softwareSettingsUtilityCode:
return SoftwareSettingsPage(
  controller: softwareSettingsController,
  timeSyncController: timeSyncController,
  apiBaseUrl: session.baseUrl,
);
```

- [ ] **Step 5: 重新运行设置页与壳层测试，确认“时间同步”分区闭环通过**

Run: `flutter test test/widgets/software_settings_page_test.dart test/widgets/message_center_page_test.dart test/widgets/main_shell_page_test.dart test/widgets/main_shell_page_registry_test.dart`

Expected: PASS，新增分区、开关和壳层透传断言通过

- [ ] **Step 6: 提交设置页与壳层接线改动**

```bash
git add lib/features/settings/presentation/widgets/software_time_sync_section.dart lib/features/settings/presentation/software_settings_page.dart lib/features/message/presentation/message_center_page.dart lib/features/shell/presentation/main_shell_page.dart lib/features/shell/presentation/main_shell_page_registry.dart test/widgets/software_settings_page_test.dart test/widgets/message_center_page_test.dart test/widgets/main_shell_page_test.dart test/widgets/main_shell_page_registry_test.dart
git commit -m "接入时间同步设置页与壳层透传"
```

## 任务 7：补集成验证并完成全量回归

**Files:**
- Create: `frontend/integration_test/time_sync_flow_test.dart`
- Modify: `frontend/integration_test/software_settings_flow_test.dart`
- Modify: `frontend/integration_test/home_dashboard_flow_test.dart`
- Modify: `frontend/integration_test/home_shell_flow_test.dart`
- Modify: `frontend/integration_test/login_flow_test.dart`

- [ ] **Step 1: 先写失败的桌面 integration test，固定“启动失败后退化为软件内时间校准”链路**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';
import 'package:mes_client/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('启动检查失败后会退化为软件内时间校准', (tester) async {
    final settingsController = SoftwareSettingsController.memory();
    final effectiveClock = EffectiveClock();
    final timeSyncController = TimeSyncController(
      softwareSettingsController: settingsController,
      serverTimeService: _FakeServerTimeService(
        snapshot: ServerTimeSnapshot(
          serverUtc: DateTime.utc(2026, 4, 20, 2, 1, 0),
          serverTimezoneOffsetMinutes: 480,
          sampledAtEpochMs: DateTime.utc(2026, 4, 20, 2, 1, 0).millisecondsSinceEpoch,
        ),
      ),
      systemTimeSyncService: _FakeWindowsTimeSyncService(
        result: TimeSyncResultCode.cancelledByUser,
      ),
      effectiveClock: effectiveClock,
      nowProvider: () => DateTime.utc(2026, 4, 20, 2, 0, 0),
    );

    await tester.pumpWidget(
      MesClientApp(
        softwareSettingsController: settingsController,
        timeSyncController: timeSyncController,
      ),
    );
    await tester.pumpAndSettle();

    expect(timeSyncController.state.mode, TimeSyncMode.softwareTimeCalibrated);
    expect(effectiveClock.isCalibrated, isTrue);
  });
}
```

- [ ] **Step 2: 运行新增 integration test，确认应用入口参数或控制器注入仍有缺口时先失败**

Run: `flutter test -d windows integration_test/time_sync_flow_test.dart`

Expected: FAIL，报错包含构造参数不匹配、缺少 `timeSyncController` 或状态未按预期切换

- [ ] **Step 3: 适配现有 integration tests 的新构造参数，避免全量验证时编译失败**

```dart
// frontend/integration_test/software_settings_flow_test.dart
final timeSyncController = TimeSyncController(
  softwareSettingsController: firstController,
  serverTimeService: _FakeServerTimeService(
    snapshot: ServerTimeSnapshot(
      serverUtc: DateTime.utc(2026, 4, 20, 2, 0, 0),
      serverTimezoneOffsetMinutes: 480,
      sampledAtEpochMs: DateTime.utc(2026, 4, 20, 2, 0, 0).millisecondsSinceEpoch,
    ),
  ),
  systemTimeSyncService: _FakeWindowsTimeSyncService(),
  effectiveClock: EffectiveClock(),
);

await tester.pumpWidget(
  MesClientApp(
    softwareSettingsController: secondController,
    timeSyncController: timeSyncController,
  ),
);
```

```dart
// frontend/integration_test/home_dashboard_flow_test.dart
home: MainShellPage(
  session: _session,
  onLogout: () {},
  softwareSettingsController: SoftwareSettingsController.memory(),
  timeSyncController: TimeSyncController(
    softwareSettingsController: SoftwareSettingsController.memory(),
    serverTimeService: _FakeServerTimeService(),
    systemTimeSyncService: _FakeWindowsTimeSyncService(),
    effectiveClock: EffectiveClock(),
  ),
  authService: _FakeAuthService(),
  authzService: _FakeAuthzService(),
  pageCatalogService: _FakePageCatalogService(),
  messageService: messageService,
  homeDashboardService: _FakeHomeDashboardService(),
)
```

```dart
// frontend/integration_test/home_shell_flow_test.dart 与 login_flow_test.dart
final settingsController = SoftwareSettingsController.memory();
final timeSyncController = TimeSyncController(
  softwareSettingsController: settingsController,
  serverTimeService: _FakeServerTimeService(),
  systemTimeSyncService: _FakeWindowsTimeSyncService(),
  effectiveClock: EffectiveClock(),
);

await tester.pumpWidget(
  MesClientApp(
    softwareSettingsController: settingsController,
    timeSyncController: timeSyncController,
  ),
);
```

- [ ] **Step 4: 运行最终验证，逐文件完成 Windows 桌面回归**

Run: `pytest tests/test_system_time_endpoint_unit.py -q`
Expected: PASS

Run: `python -c "import json; from app.main import app; print(json.dumps(app.openapi(), ensure_ascii=False, indent=2))" > openapi.generated.json`
Expected: 成功更新 OpenAPI 契约

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test test/services/software_settings_service_test.dart test/widgets/software_settings_controller_test.dart test/services/server_time_service_test.dart test/services/windows_time_sync_service_test.dart test/widgets/time_sync_controller_test.dart test/widgets/software_settings_page_test.dart test/widget_test.dart test/widgets/app_bootstrap_page_test.dart test/widgets/main_shell_page_test.dart test/widgets/main_shell_page_registry_test.dart`
Expected: PASS

Run: `flutter test -d windows integration_test/time_sync_flow_test.dart`
Expected: PASS

Run: `flutter test -d windows integration_test/software_settings_flow_test.dart`
Expected: PASS

Run: `flutter test -d windows integration_test/home_dashboard_flow_test.dart`
Expected: PASS

Run: `flutter test -d windows integration_test/home_shell_flow_test.dart`
Expected: PASS

Run: `flutter test -d windows integration_test/login_flow_test.dart`
Expected: PASS

- [ ] **Step 5: 提交集成验证与最终收口**

```bash
git add integration_test/time_sync_flow_test.dart integration_test/software_settings_flow_test.dart integration_test/home_dashboard_flow_test.dart integration_test/home_shell_flow_test.dart integration_test/login_flow_test.dart
git commit -m "补齐时间同步功能验证"
```

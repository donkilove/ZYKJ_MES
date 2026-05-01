# 用户系统增强实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增强用户系统三个功能：Token续期机制、单会话并发控制、用户批量导入。

**Architecture:**
- Token续期：JWT新增`iat`+`login_type` claim，后端新增续期API签发新token，前端新增定时监控+模态弹窗
- 并发会话控制：web登录时强制下线同用户所有其他web类型活跃会话，JWT通过`login_type`区分web/mobile_scan
- 用户批量导入：新增文件上传API支持CSV/Excel，逐条创建用户并返回详细导入报告

**Tech Stack:** FastAPI, SQLAlchemy, Flutter (Dart), jose (JWT), openpyxl, csv

---

## 功能一：Token续期机制

### Task 1: 后端 — JWT claims新增 `iat` 和 `login_type`

**Files:**
- Modify: `backend/app/core/security.py:55-67`
- Modify: `backend/app/api/v1/endpoints/auth.py:81-99`
- Modify: `backend/app/api/v1/endpoints/auth.py:102-252`

- [ ] **Step 1: 修改 `create_access_token` 自动注入 `iat` claim**

```python
# backend/app/core/security.py — create_access_token 函数体
def create_access_token(
    subject: str,
    extra_claims: dict[str, Any] | None = None,
    *,
    expires_minutes: int | None = None,
) -> str:
    ensure_runtime_settings_secure()
    resolved_minutes = expires_minutes or settings.jwt_expire_minutes
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=resolved_minutes)
    payload: dict[str, Any] = {
        "sub": subject,
        "exp": expires_at,
        "iat": now,
    }
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
```

- [ ] **Step 2: `_build_login_success_response` 增加 `login_type` 参数传入JWT**

```python
# backend/app/api/v1/endpoints/auth.py
def _build_login_success_response(
    *,
    user: User,
    session_row: object,
    expires_minutes: int,
    login_type: str = "web",
) -> ApiResponse[LoginResult]:
    token = create_access_token(
        subject=str(user.id),
        extra_claims={"sid": session_row.session_token_id, "login_type": login_type},
        expires_minutes=expires_minutes,
    )
    # ...其余不变
```

- [ ] **Step 3: `_login_with_expiry` 增加 `login_type` 参数并传递**

签名新增 `login_type: str = "web"`，末尾 `return _build_login_success_response(... login_type=login_type)`。

- [ ] **Step 4: `login` 端点传 `login_type="web"`，`mobile_scan_review_login` 传 `login_type="mobile_scan"`**

- [ ] **Step 5: 运行测试**

```bash
cd backend && python -m pytest tests/test_security_unit.py tests/test_auth_endpoint_unit.py -v
```

---

### Task 2: 后端 — 新增Token续期API

**Files:**
- Modify: `backend/app/schemas/auth.py` (追加 `RenewTokenRequest` / `RenewTokenResult`)
- Modify: `backend/app/services/session_service.py` (追加 `renew_session`)
- Modify: `backend/app/api/v1/endpoints/auth.py` (追加 `POST /auth/renew-token` 端点)

- [ ] **Step 1: `schemas/auth.py` 追加请求/响应模型**

```python
class RenewTokenRequest(BaseModel):
    password: str = Field(min_length=6, max_length=128)

class RenewTokenResult(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
```

- [ ] **Step 2: `session_service.py` 追加 `renew_session` 函数**

```python
def renew_session(db: Session, *, session_token_id: str, extend_seconds: int = 3600) -> UserSession | None:
    now = _now_utc()
    row = get_session_by_token_id(db, session_token_id)
    if not row or row.status != "active" or row.expires_at <= now:
        return None
    row.expires_at = row.expires_at + timedelta(seconds=extend_seconds)
    row.last_active_at = now
    db.flush()
    remember_active_session_token(session_token_id, expires_at=row.expires_at)
    return row
```

- [ ] **Step 3: `auth.py` 端点追加 `POST /renew-token`**

核心逻辑：
1. 校验密码（`verify_password_cached`）
2. 解码当前token获取 `sid`、`iat`、`login_type`
3. 检查 `iat` 至今 >= 3600秒，否则返回400
4. 调用 `renew_session` 延长后端session 1小时
5. 签发新token（`iat` 重置，`exp` = 当前 + 原有效期 + 1小时）
6. 写审计日志

- [ ] **Step 4: 运行测试**

```bash
cd backend && python -m pytest tests/test_auth_endpoint_unit.py -v
```

---

### Task 3: 前端 — Token续期监控与弹窗

**Files:**
- Modify: `frontend/lib/core/models/app_session.dart` (新增 `expiresIn`、`tokenIssuedAt`、`canRenewToken`、`isTokenNearExpiry`)
- Modify: `frontend/lib/features/auth/services/auth_service.dart` (新增 `renewToken` 方法，`login` 返回 `expiresIn`)
- Create: `frontend/lib/features/auth/presentation/token_renewal_dialog.dart`
- Modify: `frontend/lib/main.dart` (新增 `_tokenMonitorTimer`、`_checkTokenRenewal`)

- [ ] **Step 1: `AppSession` 增加 `expiresIn` 字段和计算属性**

```dart
class AppSession {
  AppSession({
    required this.baseUrl,
    required this.accessToken,
    this.mustChangePassword = false,
    this.expiresIn = 0,
  });

  final String baseUrl;
  final String accessToken;
  final bool mustChangePassword;
  final int expiresIn;

  DateTime? get tokenIssuedAt {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final iat = payload['iat'];
      if (iat is int) return DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true);
      return null;
    } catch (_) { return null; }
  }

  int get tokenAgeSeconds {
    final iat = tokenIssuedAt;
    if (iat == null) return 0;
    return DateTime.now().toUtc().difference(iat).inSeconds;
  }

  bool get canRenewToken => tokenAgeSeconds >= 3600;
  bool get isTokenNearExpiry {
    if (expiresIn <= 0) return false;
    final remaining = expiresIn - tokenAgeSeconds;
    return remaining <= 300 && remaining > 0;
  }
}
```

- [ ] **Step 2: `AuthService` 新增 `renewToken` 方法，`login` 返回 `expiresIn`**

```dart
Future<({String token, bool mustChangePassword, int expiresIn})> login({...}) async {
  // ...现有逻辑，返回中包含 expiresIn
}

Future<({String token, int expiresIn})> renewToken({
  required String baseUrl, required String accessToken, required String password,
}) async {
  final uri = Uri.parse('$baseUrl/auth/renew-token');
  final response = await http.post(uri,
    headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
    body: jsonEncode({'password': password}),
  ).timeout(const Duration(seconds: 30));
  // ...解析返回新token和expiresIn
}
```

- [ ] **Step 3: 创建 `token_renewal_dialog.dart`**

模态弹窗组件，包含：
- 倒计时显示（3分钟=180秒）
- 密码输入框
- 续期/取消按钮
- 错误提示
- 倒计时归零自动返回null

- [ ] **Step 4: `main.dart` 添加token监控定时器**

- `_startTokenMonitor()`: 每60秒检查一次
- `_checkTokenRenewal()`: 当 `isTokenNearExpiry && canRenewToken` 时弹窗
- 续期成功 → 更新 `_session`（新token + 新expiresIn）
- 用户取消/超时 → `_handleLogout()`
- 登录成功时 `_startTokenMonitor()`，登出时 `_stopTokenMonitor()`

- [ ] **Step 5: 运行前端测试**

```bash
cd frontend && flutter test
```

---

## 功能二：单会话并发控制

### Task 4: 后端 — 登录时强制下线旧会话

**Files:**
- Modify: `backend/app/services/session_service.py` (追加 `force_offline_user_sessions_except`)
- Modify: `backend/app/api/v1/endpoints/auth.py` (`_login_with_expiry` 中调用)

- [ ] **Step 1: `session_service.py` 追加批量下线函数**

```python
def force_offline_user_sessions_except(
    db: Session, *, user_id: int, exclude_session_token_id: str | None = None,
) -> int:
    now = _now_utc()
    stmt = select(UserSession).where(
        UserSession.user_id == user_id,
        UserSession.status == "active",
        UserSession.is_forced_offline.is_(False),
    )
    if exclude_session_token_id:
        stmt = stmt.where(UserSession.session_token_id != exclude_session_token_id)
    rows = db.execute(stmt).scalars().all()
    for row in rows:
        row.status = "forced_offline"
        row.is_forced_offline = True
        row.logout_time = now
        row.last_active_at = now
        forget_active_session_token(row.session_token_id)
    if rows:
        db.flush()
    return len(rows)
```

- [ ] **Step 2: `_login_with_expiry` 中在 `create_or_reuse_user_session` 后添加并发控制**

仅当 `login_type == "web"` 时，调用 `force_offline_user_sessions_except` 下线该用户所有其他活跃会话。

- [ ] **Step 3: 运行测试**

```bash
cd backend && python -m pytest tests/test_session_service_unit.py tests/test_auth_endpoint_unit.py -v
```

---

### Task 5: 前端 — 被踢出时显示原因

**Files:**
- Modify: `frontend/lib/main.dart` (`_handleLogout` 支持 `reason` 参数)
- Modify: `frontend/lib/features/shell/presentation/main_shell_controller.dart` (`onLogout` 签名)

- [ ] **Step 1: `_handleLogout` 增加 `reason` 参数，设置 `_loginNotice`**

- [ ] **Step 2: `MainShellController.onLogout` 签名改为 `void Function({String? reason})`**

所有 `onLogout()` 调用点中，401场景改为 `onLogout(reason: '您的账号已在其他终端登录')`。

- [ ] **Step 3: 运行前端测试**

```bash
cd frontend && flutter test
```

---

## 功能三：用户批量导入

### Task 6: 后端 — 批量导入API

**Files:**
- Modify: `backend/app/core/authz_catalog.py` (追加 `user.users.import`)
- Modify: `backend/app/core/authz_hierarchy_catalog.py` (追加权限层级)
- Modify: `backend/app/schemas/user.py` (追加 `UserImportItemResult` / `UserImportResult`)
- Modify: `backend/app/api/v1/endpoints/users.py` (追加 `POST /users/import` 和 `GET /users/import-template`)

- [ ] **Step 1: `authz_catalog.py` 追加权限码**

```python
("user.users.import", "批量导入用户", AUTHZ_MODULE_USER, "user_management"),
```

- [ ] **Step 2: `authz_hierarchy_catalog.py` 追加权限层级**

- [ ] **Step 3: `schemas/user.py` 追加导入结果模型**

```python
class UserImportItemResult(BaseModel):
    row_number: int
    username: str
    success: bool
    error: str | None = None
    user_id: int | None = None

class UserImportResult(BaseModel):
    total_rows: int
    success_count: int
    failure_count: int
    items: list[UserImportItemResult]
```

- [ ] **Step 4: `users.py` 追加 `POST /users/import` 端点**

核心逻辑：
1. 读取上传文件（`UploadFile`）
2. 根据扩展名 `.csv` / `.xlsx` 解析为行数据列表
3. 验证必须列 `username`、`role_code`
4. 逐行调用 `create_user(db, UserCreate(...password="123456"...))`
5. 失败行记录原因，不中断
6. 写审计日志，返回 `UserImportResult`

- [ ] **Step 5: 追加 `GET /users/import-template` 模板下载端点**

返回CSV或Excel模板文件（base64），包含示例行。

- [ ] **Step 6: 运行测试**

```bash
cd backend && python -m pytest tests/ -v -k "user"
```

---

### Task 7: 前端 — 批量导入UI

**Files:**
- Modify: `frontend/lib/features/user/models/user_models.dart` (追加 `UserImportItemResult` / `UserImportResult`)
- Modify: `frontend/lib/features/user/services/user_service.dart` (追加 `importUsers` / `downloadImportTemplate`)
- Create: `frontend/lib/features/user/presentation/user_import_dialog.dart`
- Modify: `frontend/lib/features/user/presentation/user_management_page.dart` (添加"批量导入"按钮)
- Modify: `frontend/pubspec.yaml` (添加 `file_picker` 依赖)

- [ ] **Step 1: `user_models.dart` 追加导入结果模型**

- [ ] **Step 2: `UserService` 追加 `importUsers` 和 `downloadImportTemplate` 方法**

- [ ] **Step 3: 创建 `user_import_dialog.dart`**

包含：文件选择、导入按钮、结果展示（成功数/失败数/失败详情列表）

- [ ] **Step 4: 用户管理页面添加"批量导入"按钮**

- [ ] **Step 5: 添加 `file_picker` 依赖**

```yaml
# frontend/pubspec.yaml — dependencies
  file_picker: ^8.0.0
```

- [ ] **Step 6: 运行前端测试**

```bash
cd frontend && flutter test
```

---

## 验证与收尾

### Task 8: 全链路验证

- [ ] **Step 1: 后端全部测试**

```bash
cd backend && python -m pytest tests/ -v
```

- [ ] **Step 2: 前端全部测试**

```bash
cd frontend && flutter test
```

- [ ] **Step 3: 手动验证三个场景**

1. Token续期：登录 → 等token使用>=1h → 触发弹窗 → 密码续期 → 新token可用
2. 并发会话：终端A登录 → 终端B登录 → 终端A被踢显示提示
3. 批量导入：下载模板 → 填数据（含重复用户名）→ 导入 → 查看报告

- [ ] **Step 4: 提交**

```bash
git add -A && git status --short --untracked-files=all && git diff --check
git commit -m "feat: 用户系统增强 — Token续期、单会话并发控制、用户批量导入"
```

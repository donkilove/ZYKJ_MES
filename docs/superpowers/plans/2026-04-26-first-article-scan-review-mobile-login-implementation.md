# First Article Scan Review Mobile Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为首件扫码复核手机页增加“7 天免登录”，让同一台手机在 7 天内复用扫码复核专用登录态，不再每次扫码都输入账号密码。

**Architecture:** 后端新增扫码复核手机页专用登录口径和 7 天 token 时效；运行中的后端静态扫码页使用 `localStorage` 持久化 token、过期时间和最近登录账号，并在页面初始化时自动恢复。为满足仓库收敛规则，同步把 Flutter 版手机页的登录体验对齐到同样的 7 天本地恢复逻辑。

**Tech Stack:** FastAPI、Pydantic Settings、JWT、pytest、原生 HTML/JavaScript、Flutter/Dart、shared_preferences、flutter_test。

---

## 文件结构

- Modify: `backend/app/core/config.py`
  - 新增扫码复核手机页专用 token 时效配置。
- Modify: `backend/app/core/security.py`
  - 让 token 生成支持按调用方指定过期分钟数。
- Modify: `backend/app/api/v1/endpoints/auth.py`
  - 新增手机扫码复核专用登录接口，复用现有账号密码校验。
- Modify: `backend/tests/test_auth_endpoint_unit.py`
  - 覆盖专用登录口径与常规登录不变的单测。
- Modify: `backend/app/static/first_article_review.html`
  - 增加本地登录态持久化、自动恢复、切换账号与失效回退。
- Modify: `backend/tests/test_first_article_review_web_page.py`
  - 覆盖静态页包含自动恢复所需脚本标记。
- Create: `frontend/lib/features/production/presentation/scan_review_mobile_login_storage.dart`
  - 抽出 Flutter 版手机页登录态存储接口与 SharedPreferences 实现。
- Modify: `frontend/lib/features/production/presentation/first_article_scan_review_mobile_page.dart`
  - 接入 7 天登录态恢复、切换账号与失效回退。
- Modify: `frontend/test/widgets/first_article_scan_review_mobile_page_test.dart`
  - 覆盖 Flutter 版手机页自动恢复与切换账号。
- Modify: `evidence/2026-04-25_扫码首件复核二维码地址与轮询修复.md`
  - 记录本轮 7 天免登录实现与验证证据。

### Task 1: 后端扫码页专用 7 天登录口径

**Files:**
- Modify: `backend/app/core/config.py`
- Modify: `backend/app/core/security.py`
- Modify: `backend/app/api/v1/endpoints/auth.py`
- Test: `backend/tests/test_auth_endpoint_unit.py`

- [ ] **Step 1: 写失败测试，覆盖扫码复核专用登录的 7 天时效**

在 `backend/tests/test_auth_endpoint_unit.py` 追加以下测试：

```python
    def test_mobile_scan_review_login_uses_seven_day_expiry(self) -> None:
        db = MagicMock()
        now = datetime(2026, 4, 26, 9, 0, tzinfo=UTC)
        user = SimpleNamespace(
            id=21,
            is_active=True,
            is_deleted=False,
            password_hash="hashed-password",
            must_change_password=False,
            last_login_at=None,
            last_login_ip=None,
            last_login_terminal=None,
        )
        session_row = SimpleNamespace(
            session_token_id="sid-scan-mobile",
            login_time=now,
            expires_at=now.replace(day=27),
        )
        form_data = SimpleNamespace(username="scan-user", password="Pwd@123")
        request = SimpleNamespace(
            client=SimpleNamespace(host="192.168.1.88"),
            headers={"user-agent": "pytest-mobile"},
        )

        with (
            patch.object(auth, "get_user_by_username", return_value=user),
            patch.object(auth, "verify_password_cached", return_value=True),
            patch.object(auth, "rehash_password_if_needed", return_value=None),
            patch.object(auth, "create_or_reuse_user_session", return_value=session_row),
            patch.object(auth, "should_record_success_login", return_value=False),
            patch.object(auth, "create_login_log"),
            patch.object(auth, "cleanup_expired_login_logs_if_due"),
            patch.object(auth, "remember_active_session_token"),
            patch.object(auth, "touch_user"),
            patch.object(auth, "create_access_token", return_value="token-mobile") as create_token,
        ):
            result = auth.mobile_scan_review_login(
                form_data=form_data,
                request=request,
                db=db,
            )

        create_token.assert_called_once_with(
            subject="21",
            extra_claims={"sid": "sid-scan-mobile"},
            expires_minutes=10080,
        )
        self.assertEqual(result.data.access_token, "token-mobile")
        self.assertEqual(result.data.expires_in, 10080 * 60)

    def test_create_access_token_keeps_default_expiry_when_not_overridden(self) -> None:
        with patch.object(security, "settings", autospec=True) as fake_settings:
            fake_settings.jwt_expire_minutes = 120
            fake_settings.jwt_secret_key = "secret"
            fake_settings.jwt_algorithm = "HS256"
            with patch.object(security, "ensure_runtime_settings_secure"):
                token = security.create_access_token(subject="1")

        payload = security.jwt.get_unverified_claims(token)
        self.assertEqual(payload["sub"], "1")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `python -m pytest backend/tests/test_auth_endpoint_unit.py -k "mobile_scan_review_login_uses_seven_day_expiry or create_access_token_keeps_default_expiry_when_not_overridden" -q`

Expected: FAIL，提示 `mobile_scan_review_login` 不存在，或 `create_access_token()` 不接受 `expires_minutes`。

- [ ] **Step 3: 写最小后端实现**

在 `backend/app/core/config.py` 增加专用配置：

```python
    mobile_scan_review_jwt_expire_minutes: int = 10080
```

在 `backend/app/core/security.py` 调整 token 生成函数：

```python
def create_access_token(
    subject: str,
    extra_claims: dict[str, Any] | None = None,
    *,
    expires_minutes: int | None = None,
) -> str:
    ensure_runtime_settings_secure()
    resolved_minutes = expires_minutes or settings.jwt_expire_minutes
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=resolved_minutes)
    payload: dict[str, Any] = {"sub": subject, "exp": expires_at}
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
```

在 `backend/app/api/v1/endpoints/auth.py` 抽出共用登录成功响应构造，并新增专用接口：

```python
def _build_login_success_response(
    *,
    user: User,
    session_row: object,
    expires_minutes: int,
) -> ApiResponse[LoginResult]:
    token = create_access_token(
        subject=str(user.id),
        extra_claims={"sid": session_row.session_token_id},
        expires_minutes=expires_minutes,
    )
    return success_response(
        LoginResult(
            access_token=token,
            token_type="bearer",
            expires_in=expires_minutes * 60,
            must_change_password=user.must_change_password,
        )
    )


@router.post("/mobile-scan-review-login", response_model=ApiResponse[LoginResult])
def mobile_scan_review_login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    request: Request = None,
    db: Session = Depends(get_db),
) -> ApiResponse[LoginResult]:
    # 复用现有 login 的账号、停用、密码、日志、会话逻辑
    # 唯一区别是成功后使用 settings.mobile_scan_review_jwt_expire_minutes
```

实现时不要复制整段登录逻辑两份。推荐把现有 `login()` 中“用户校验 + 会话写入 + 登录日志 + 成功返回”提成内部 helper，例如：

```python
def _login_with_expiry(
    *,
    form_data: OAuth2PasswordRequestForm,
    request: Request | None,
    db: Session,
    expires_minutes: int,
) -> ApiResponse[LoginResult]:
    ...
```

然后：

```python
def login(...):
    return _login_with_expiry(
        form_data=form_data,
        request=request,
        db=db,
        expires_minutes=settings.jwt_expire_minutes,
    )


def mobile_scan_review_login(...):
    return _login_with_expiry(
        form_data=form_data,
        request=request,
        db=db,
        expires_minutes=settings.mobile_scan_review_jwt_expire_minutes,
    )
```

- [ ] **Step 4: 运行测试验证通过**

Run: `python -m pytest backend/tests/test_auth_endpoint_unit.py -k "mobile_scan_review_login_uses_seven_day_expiry or create_access_token_keeps_default_expiry_when_not_overridden" -q`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add backend/app/core/config.py backend/app/core/security.py backend/app/api/v1/endpoints/auth.py backend/tests/test_auth_endpoint_unit.py
git commit -m "新增扫码复核手机端长效登录口径"
```

### Task 2: 运行中的静态扫码页实现 7 天免登录

**Files:**
- Modify: `backend/app/static/first_article_review.html`
- Test: `backend/tests/test_first_article_review_web_page.py`

- [ ] **Step 1: 写失败测试，覆盖静态页包含自动恢复与切换账号标记**

在 `backend/tests/test_first_article_review_web_page.py` 追加：

```python
    def test_first_article_review_page_contains_persistent_login_hooks(self) -> None:
        client = TestClient(app)
        response = client.get("/first-article-review?token=abc")

        self.assertEqual(response.status_code, 200, response.text)
        self.assertIn("/api/v1/auth/mobile-scan-review-login", response.text)
        self.assertIn("localStorage", response.text)
        self.assertIn("firstArticleScanReview.accessToken", response.text)
        self.assertIn("switch-account-button", response.text)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `python -m pytest backend/tests/test_first_article_review_web_page.py -k "persistent_login_hooks" -q`

Expected: FAIL，因为当前静态页仍调用 `/api/v1/auth/login`，也没有本地存储与切换账号按钮。

- [ ] **Step 3: 写最小静态页实现**

在 `backend/app/static/first_article_review.html` 顶部脚本常量区补充：

```html
    <script>
      const STORAGE_KEYS = {
        accessToken: "firstArticleScanReview.accessToken",
        expiresAt: "firstArticleScanReview.expiresAt",
        username: "firstArticleScanReview.username",
      };
```

新增登录态工具函数：

```html
      function saveLoginState({ accessToken, expiresIn, username }) {
        const expiresAt = Date.now() + Number(expiresIn || 0) * 1000;
        localStorage.setItem(STORAGE_KEYS.accessToken, accessToken);
        localStorage.setItem(STORAGE_KEYS.expiresAt, String(expiresAt));
        localStorage.setItem(STORAGE_KEYS.username, username || "");
      }

      function clearLoginState() {
        localStorage.removeItem(STORAGE_KEYS.accessToken);
        localStorage.removeItem(STORAGE_KEYS.expiresAt);
        localStorage.removeItem(STORAGE_KEYS.username);
        accessToken = "";
        submitted = false;
        showReviewPanel(false);
      }

      function restoreLoginState() {
        const savedToken = localStorage.getItem(STORAGE_KEYS.accessToken) || "";
        const rawExpiresAt = localStorage.getItem(STORAGE_KEYS.expiresAt) || "";
        const expiresAt = Number(rawExpiresAt);
        if (!savedToken || !Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
          clearLoginState();
          return false;
        }
        accessToken = savedToken;
        const savedUsername = localStorage.getItem(STORAGE_KEYS.username) || "";
        if (savedUsername) {
          document.getElementById("username").value = savedUsername;
        }
        return true;
      }
```

将登录接口改为专用长效口径，并在成功时保存：

```html
          const result = await requestJson("/api/v1/auth/mobile-scan-review-login", {
            method: "POST",
            headers: {
              "Content-Type": "application/x-www-form-urlencoded",
            },
            body,
          });
          accessToken = result.access_token || "";
          saveLoginState({
            accessToken,
            expiresIn: result.expires_in,
            username: body.get("username") || "",
          });
```

新增切换账号按钮：

```html
            <button id="switch-account-button" class="secondary" type="button">切换账号</button>
```

并实现交互：

```html
      const switchAccountButton = document.getElementById("switch-account-button");
      switchAccountButton.addEventListener("click", () => {
        clearLoginState();
        setMessage("", "success");
      });
```

在页面加载末尾增加自动恢复：

```html
      async function bootstrapPage() {
        if (!token) {
          setMessage("扫码链接缺少复核令牌", "error");
          return;
        }
        if (!restoreLoginState()) {
          return;
        }
        try {
          await loadDetail();
        } catch (_) {
          clearLoginState();
          setMessage("登录已失效，请重新登录", "error");
        }
      }

      bootstrapPage();
```

并在 `loadDetail()` / `_submitReview()` 的认证失败分支里清理本地状态：

```html
        } catch (error) {
          if ((error.message || "").includes("Invalid") || (error.message || "").includes("credentials")) {
            clearLoginState();
          }
          setMessage(error.message || "加载复核信息失败", "error");
        }
```

这里实现时更稳妥的做法是让 `requestJson()` 在抛错时带上 `statusCode`：

```html
          const error = new Error(detail);
          error.statusCode = response.status;
          throw error;
```

然后在 `401/403` 时清理登录态，而不是靠文案匹配。

- [ ] **Step 4: 运行测试验证通过**

Run: `python -m pytest backend/tests/test_first_article_review_web_page.py -q`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add backend/app/static/first_article_review.html backend/tests/test_first_article_review_web_page.py
git commit -m "实现扫码复核手机页7天免登录"
```

### Task 3: Flutter 版手机页对齐 7 天免登录

**Files:**
- Create: `frontend/lib/features/production/presentation/scan_review_mobile_login_storage.dart`
- Modify: `frontend/lib/features/production/presentation/first_article_scan_review_mobile_page.dart`
- Test: `frontend/test/widgets/first_article_scan_review_mobile_page_test.dart`

- [ ] **Step 1: 写失败测试，覆盖自动恢复与切换账号**

在 `frontend/test/widgets/first_article_scan_review_mobile_page_test.dart` 增加一个假存储类与两个测试：

```dart
class _FakeScanReviewLoginStorage implements ScanReviewMobileLoginStorage {
  String? accessToken;
  DateTime? expiresAt;
  String? username;

  @override
  Future<ScanReviewMobileLoginState?> read() async {
    if (accessToken == null || expiresAt == null) {
      return null;
    }
    return ScanReviewMobileLoginState(
      accessToken: accessToken!,
      expiresAt: expiresAt!,
      username: username,
    );
  }

  @override
  Future<void> write(ScanReviewMobileLoginState state) async {
    accessToken = state.accessToken;
    expiresAt = state.expiresAt;
    username = state.username;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    expiresAt = null;
    username = null;
  }
}

testWidgets('手机扫码复核页读取本地登录态后直接加载详情', (tester) async {
  final authService = _FakeAuthService(token: 'unused');
  final productionService = _FakeProductionService();
  final storage = _FakeScanReviewLoginStorage()
    ..accessToken = 'persisted-token'
    ..expiresAt = DateTime.now().add(const Duration(days: 3))
    ..username = 'qa';

  await tester.pumpWidget(
    MaterialApp(
      home: FirstArticleScanReviewMobilePage(
        baseUrl: 'http://api.test',
        token: 'scan-token',
        authService: authService,
        productionServiceFactory: (_) => productionService,
        loginStorage: storage,
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(authService.lastUsername, isNull);
  expect(find.text('MO-001'), findsOneWidget);
});

testWidgets('手机扫码复核页支持切换账号并清理本地登录态', (tester) async {
  final authService = _FakeAuthService(token: 'mobile-token');
  final productionService = _FakeProductionService();
  final storage = _FakeScanReviewLoginStorage();

  await tester.pumpWidget(
    MaterialApp(
      home: FirstArticleScanReviewMobilePage(
        baseUrl: 'http://api.test',
        token: 'scan-token',
        authService: authService,
        productionServiceFactory: (_) => productionService,
        loginStorage: storage,
      ),
    ),
  );
  await tester.enterText(find.widgetWithText(TextField, '账号'), 'qa');
  await tester.enterText(find.widgetWithText(TextField, '密码'), 'pw');
  await tester.tap(find.widgetWithText(FilledButton, '登录'));
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(TextButton, '切换账号'));
  await tester.pumpAndSettle();

  expect(storage.accessToken, isNull);
  expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/widgets/first_article_scan_review_mobile_page_test.dart`

Expected: FAIL，因为当前页面没有持久化存储接口，也没有切换账号按钮。

- [ ] **Step 3: 写最小 Flutter 对齐实现**

新增文件 `frontend/lib/features/production/presentation/scan_review_mobile_login_storage.dart`：

```dart
import 'package:shared_preferences/shared_preferences.dart';

class ScanReviewMobileLoginState {
  const ScanReviewMobileLoginState({
    required this.accessToken,
    required this.expiresAt,
    this.username,
  });

  final String accessToken;
  final DateTime expiresAt;
  final String? username;
}

abstract class ScanReviewMobileLoginStorage {
  Future<ScanReviewMobileLoginState?> read();
  Future<void> write(ScanReviewMobileLoginState state);
  Future<void> clear();
}

class SharedPreferencesScanReviewMobileLoginStorage
    implements ScanReviewMobileLoginStorage {
  static const _accessTokenKey = 'firstArticleScanReview.accessToken';
  static const _expiresAtKey = 'firstArticleScanReview.expiresAt';
  static const _usernameKey = 'firstArticleScanReview.username';

  @override
  Future<ScanReviewMobileLoginState?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);
    final expiresAtRaw = prefs.getString(_expiresAtKey);
    if (token == null || expiresAtRaw == null) {
      return null;
    }
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
      await clear();
      return null;
    }
    return ScanReviewMobileLoginState(
      accessToken: token,
      expiresAt: expiresAt,
      username: prefs.getString(_usernameKey),
    );
  }

  @override
  Future<void> write(ScanReviewMobileLoginState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, state.accessToken);
    await prefs.setString(_expiresAtKey, state.expiresAt.toIso8601String());
    if ((state.username ?? '').isNotEmpty) {
      await prefs.setString(_usernameKey, state.username!);
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_usernameKey);
  }
}
```

在 `first_article_scan_review_mobile_page.dart` 中接入：

```dart
    this.loginStorage,
```

```dart
  final ScanReviewMobileLoginStorage? loginStorage;
```

状态中新增：

```dart
  late final ScanReviewMobileLoginStorage _loginStorage;
  String? _accessToken;
```

`initState()` 中初始化并尝试恢复：

```dart
    _loginStorage =
        widget.loginStorage ?? SharedPreferencesScanReviewMobileLoginStorage();
    unawaited(_restoreLoginState());
```

新增恢复方法：

```dart
  Future<void> _restoreLoginState() async {
    final state = await _loginStorage.read();
    if (state == null || widget.token.trim().isEmpty) {
      return;
    }
    _usernameController.text = state.username ?? '';
    _accessToken = state.accessToken;
    await _loadDetailWithSession(
      AppSession(baseUrl: widget.baseUrl, accessToken: state.accessToken),
      clearOnAuthFailure: true,
    );
  }
```

将详情加载抽成复用函数：

```dart
  Future<void> _loadDetailWithSession(
    AppSession session, {
    required bool clearOnAuthFailure,
  }) async {
    final service =
        widget.productionServiceFactory?.call(session) ?? ProductionService(session);
    try {
      final detail = await service.getFirstArticleReviewSessionDetail(token: widget.token);
      if (!mounted) return;
      setState(() {
        _productionService = service;
        _detail = detail;
        _loggedIn = true;
      });
    } catch (error) {
      if (clearOnAuthFailure && error is ApiException && error.statusCode == 401) {
        await _loginStorage.clear();
        _accessToken = null;
      }
      rethrow;
    }
  }
```

登录成功后保存：

```dart
      _accessToken = loginResult.token;
      await _loginStorage.write(
        ScanReviewMobileLoginState(
          accessToken: loginResult.token,
          expiresAt: DateTime.now().add(
            Duration(seconds: 7 * 24 * 60 * 60),
          ),
          username: username,
        ),
      );
```

更稳妥的实现应使用后端返回的 `expires_in`；若现有 `AuthService.login()` 没暴露该值，则在本任务中同步扩展返回结构。

补“切换账号”按钮：

```dart
        TextButton(
          onPressed: _loading ? null : _switchAccount,
          child: const Text('切换账号'),
        ),
```

和方法：

```dart
  Future<void> _switchAccount() async {
    await _loginStorage.clear();
    if (!mounted) return;
    setState(() {
      _accessToken = null;
      _productionService = null;
      _detail = null;
      _loggedIn = false;
      _submitted = false;
      _message = '';
    });
  }
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/widgets/first_article_scan_review_mobile_page_test.dart`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add frontend/lib/features/production/presentation/scan_review_mobile_login_storage.dart frontend/lib/features/production/presentation/first_article_scan_review_mobile_page.dart frontend/test/widgets/first_article_scan_review_mobile_page_test.dart
git commit -m "对齐手机扫码复核页长效登录体验"
```

### Task 4: 证据与回归收口

**Files:**
- Modify: `evidence/2026-04-25_扫码首件复核二维码地址与轮询修复.md`

- [ ] **Step 1: 补充 evidence 模板内容**

在 evidence 中补充以下收口：

```markdown
| Exx | `python -m pytest backend/tests/test_auth_endpoint_unit.py -q` | 2026-04-26 xx:xx:xx +08:00 | 扫码复核专用 7 天登录口径单测通过 | Codex |
| Exx | `python -m pytest backend/tests/test_first_article_review_web_page.py -q` | 2026-04-26 xx:xx:xx +08:00 | 静态手机页持久化登录脚本标记验证通过 | Codex |
| Exx | `flutter test test/widgets/first_article_scan_review_mobile_page_test.dart` | 2026-04-26 xx:xx:xx +08:00 | Flutter 版手机页自动恢复与切换账号验证通过 | Codex |
```
```

- [ ] **Step 2: 运行整体验证**

Run:

```bash
python -m pytest backend/tests/test_auth_endpoint_unit.py backend/tests/test_first_article_review_web_page.py -q
flutter test test/widgets/first_article_scan_review_mobile_page_test.dart
```

Expected:

```text
backend: all tests passed
frontend: all tests passed
```

- [ ] **Step 3: 记录人工运行态验证步骤**

在 evidence 中补充：

```markdown
人工验证：
1. 手机首次扫码，输入账号密码登录。
2. 提交或返回后重新扫码另一张单据。
3. 7 天内不再弹登录表单，直接展示复核详情。
4. 点击“切换账号”后重新回到登录页。
5. 人工将 token 置为失效后，再扫码应提示“登录已失效，请重新登录”。
```

- [ ] **Step 4: 提交**

```bash
git add evidence/2026-04-25_扫码首件复核二维码地址与轮询修复.md
git commit -m "补齐扫码复核手机端长效登录留痕"
```

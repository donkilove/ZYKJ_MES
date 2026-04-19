# Login P95 Optimization: bcrypt rounds 12→10 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 login 接口 40并发 P95 从 ~1122ms 压到 500ms 以内，通过降低 bcrypt rounds 12→10 并在登录成功时透明 rehash 旧账号密码。

**Architecture:** 只改 `security.py`（降 rounds + 新增 `rehash_password_if_needed`）和 `auth.py` login 函数（调用 rehash 并写回 DB）。passlib `needs_update` 自动检测旧 rounds=12 哈希，login 成功时顺带迁移，无需批量脚本。

**Tech Stack:** Python 3.12, passlib (bcrypt), SQLAlchemy, FastAPI, pytest (unittest 风格)

---

## File Map

| 文件 | 动作 | 说明 |
|------|------|------|
| `backend/app/core/security.py` | Modify | 加 `bcrypt__rounds=10`，新增 `rehash_password_if_needed` |
| `backend/app/api/v1/endpoints/auth.py` | Modify | login 成功后调用 rehash，写回 `user.password_hash` |
| `backend/tests/test_security_unit.py` | Modify | 新增 `rehash_password_if_needed` 的单元测试 |
| `backend/tests/test_auth_endpoint_unit.py` | Modify | 新增 login 触发 rehash 路径的单元测试 |

---

## Task 1：security.py — 降 rounds + 新增 rehash 函数

**Files:**
- Modify: `backend/app/core/security.py`
- Test: `backend/tests/test_security_unit.py`

- [ ] **Step 1: 写失败的单元测试**

在 `backend/tests/test_security_unit.py` 末尾的 `SecurityUnitTest` 类中追加两个测试方法：

```python
def test_rehash_password_if_needed_returns_new_hash_for_rounds12(self) -> None:
    from passlib.context import CryptContext
    old_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)
    old_hash = old_ctx.hash("Pwd@123")
    result = security.rehash_password_if_needed("Pwd@123", old_hash)
    self.assertIsNotNone(result)
    # 新哈希应可用当前 context 验证通过
    self.assertTrue(security.pwd_context.verify("Pwd@123", result))

def test_rehash_password_if_needed_returns_none_for_current_rounds(self) -> None:
    current_hash = security.pwd_context.hash("Pwd@123")
    result = security.rehash_password_if_needed("Pwd@123", current_hash)
    self.assertIsNone(result)
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd backend
python -m pytest tests/test_security_unit.py -v -k "rehash"
```

预期：`AttributeError: module 'app.core.security' has no attribute 'rehash_password_if_needed'`

- [ ] **Step 3: 修改 security.py**

将 `backend/app/core/security.py` 的第 13 行（`pwd_context = ...`）改为：

```python
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=10)
```

在 `verify_password_cached` 函数之后（第 42 行后），新增：

```python
def rehash_password_if_needed(plain_password: str, hashed_password: str) -> str | None:
    if not pwd_context.needs_update(hashed_password):
        return None
    return pwd_context.hash(plain_password)
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
cd backend
python -m pytest tests/test_security_unit.py -v
```

预期：5 个原有测试 + 2 个新测试，全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add backend/app/core/security.py backend/tests/test_security_unit.py
git commit -m "feat: lower bcrypt rounds to 10 and add rehash_password_if_needed"
```

---

## Task 2：auth.py — login 成功后触发 rehash

**Files:**
- Modify: `backend/app/api/v1/endpoints/auth.py`
- Test: `backend/tests/test_auth_endpoint_unit.py`

- [ ] **Step 1: 写失败的单元测试**

在 `backend/tests/test_auth_endpoint_unit.py` 的 `AuthEndpointUnitTest` 类中追加两个测试方法：

```python
def test_login_rehashes_password_when_needed(self) -> None:
    db = MagicMock()
    from datetime import UTC, datetime
    now = datetime(2026, 4, 19, 10, 0, tzinfo=UTC)
    user = SimpleNamespace(
        id=9,
        is_active=True,
        is_deleted=False,
        password_hash="old-hash-rounds12",
        must_change_password=False,
        last_login_at=None,
        last_login_ip=None,
        last_login_terminal=None,
    )
    session_row = SimpleNamespace(
        session_token_id="sid-2",
        login_time=now,
        expires_at=now.replace(hour=12),
    )
    form_data = SimpleNamespace(username="demo2", password="Pwd@123")
    request = SimpleNamespace(
        client=SimpleNamespace(host="127.0.0.1"),
        headers={"user-agent": "pytest"},
    )

    with (
        patch.object(auth, "get_user_by_username", return_value=user),
        patch.object(auth, "verify_password_cached", return_value=True),
        patch.object(auth, "rehash_password_if_needed", return_value="new-hash-rounds10"),
        patch.object(auth, "create_or_reuse_user_session", return_value=session_row),
        patch.object(auth, "should_record_success_login", return_value=False),
        patch.object(auth, "create_login_log"),
        patch.object(auth, "cleanup_expired_login_logs_if_due"),
        patch.object(auth, "remember_active_session_token"),
        patch.object(auth, "touch_user"),
        patch.object(auth, "create_access_token", return_value="token-2"),
    ):
        auth.login(form_data=form_data, request=request, db=db)

    self.assertEqual(user.password_hash, "new-hash-rounds10")

def test_login_skips_rehash_when_not_needed(self) -> None:
    db = MagicMock()
    from datetime import UTC, datetime
    now = datetime(2026, 4, 19, 10, 0, tzinfo=UTC)
    user = SimpleNamespace(
        id=10,
        is_active=True,
        is_deleted=False,
        password_hash="current-hash-rounds10",
        must_change_password=False,
        last_login_at=None,
        last_login_ip=None,
        last_login_terminal=None,
    )
    session_row = SimpleNamespace(
        session_token_id="sid-3",
        login_time=now,
        expires_at=now.replace(hour=12),
    )
    form_data = SimpleNamespace(username="demo3", password="Pwd@123")
    request = SimpleNamespace(
        client=SimpleNamespace(host="127.0.0.1"),
        headers={"user-agent": "pytest"},
    )
    original_hash = user.password_hash

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
        patch.object(auth, "create_access_token", return_value="token-3"),
    ):
        auth.login(form_data=form_data, request=request, db=db)

    self.assertEqual(user.password_hash, original_hash)
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd backend
python -m pytest tests/test_auth_endpoint_unit.py -v -k "rehash"
```

预期：`ImportError` 或 `AttributeError: module ... has no attribute 'rehash_password_if_needed'`

- [ ] **Step 3: 修改 auth.py**

在 `backend/app/api/v1/endpoints/auth.py` 的 import 块，`verify_password_cached` 那行改为：

```python
from app.core.security import (
    create_access_token,
    decode_access_token,
    rehash_password_if_needed,
    verify_password_cached,
)
```

在 login 函数中，找到 `verify_password_cached(...)` 调用之后（约第 148 行，即 `session_row = create_or_reuse_user_session(...)` 之前），插入：

```python
    new_hash = rehash_password_if_needed(form_data.password, user.password_hash)
    if new_hash is not None:
        user.password_hash = new_hash
```

不新增任何 `db.commit()` 调用——已有的 `db.commit()` 在函数末尾会一并提交。

- [ ] **Step 4: 运行所有相关测试，确认通过**

```bash
cd backend
python -m pytest tests/test_security_unit.py tests/test_auth_endpoint_unit.py -v
```

预期：全部 9 个测试 PASS（5 security + 4 auth endpoint）。

- [ ] **Step 5: 提交**

```bash
git add backend/app/api/v1/endpoints/auth.py backend/tests/test_auth_endpoint_unit.py
git commit -m "feat: rehash password on login when bcrypt rounds outdated"
```

---

## Task 3：重新构建容器并验证 P95

**Files:**（无代码变更，仅部署验证）

- [ ] **Step 1: 重建并重启容器**

```bash
docker compose build backend-web backend-worker
docker compose up -d backend-web backend-worker
```

等待健康检查通过：

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

预期：`zykj_mes-backend-web-1` 显示 `(healthy)`。

- [ ] **Step 2: 重跑 40并发压测**

```bash
cd c:/Users/Donki/Desktop/ZYKJ_MES
python -m tools.perf.backend_capacity_gate \
  --base-url http://127.0.0.1:8000 \
  --concurrency 40 \
  --duration-seconds 60 \
  --warmup-seconds 10 \
  --login-user-prefix ltadm \
  --password "Admin@123456" \
  --token-count 2 \
  --scenarios "login,authz,users,production-orders,production-stats" \
  --p95-ms 500
```

预期：`login` 场景 P95 < 500ms，`gate_passed: true`。

- [ ] **Step 3: 确认 rehash 生效（可选验证）**

```bash
docker exec zykj_mes-postgres-1 psql -U mes_user -d mes_db -c \
  "SELECT username, left(password_hash, 7) as rounds_prefix FROM sys_user WHERE username IN ('ltadm1','ltadm2') LIMIT 5;"
```

登录前应看到 `$2b$12$`（rounds=12），登录后（pressure test 中已登录过）应更新为 `$2b$10$`（rounds=10）。

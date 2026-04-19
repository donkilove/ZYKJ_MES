# Login P95 优化：bcrypt rounds 12 → 10

**日期：** 2026-04-19  
**目标：** 将 login 接口 40并发 P95 从 ~1122ms 压到 500ms 以内  
**部署环境：** 纯内网

---

## 根因

容器内 bcrypt rounds=12，单次 `verify` ≈ 220ms。16 个 gunicorn worker 在 40 并发登录下形成排队（约 5 轮竞争），导致 P95 ≈ 1100ms。

## 方案

将 `CryptContext` 的 bcrypt rounds 从默认 12 降至 10（单次 ≈ 55ms），并利用 passlib 内置的 `needs_update` 机制在登录成功时对旧账号密码做透明 rehash 迁移，无需批量脚本或停机。

**预期 P95：** 55ms × ceil(40 / 16) ≈ 140ms，远低于 500ms 阈值。

**安全评估：** rounds=10 较 rounds=12 离线破解速度提升约 4 倍，但内网场景无公网暴露，可接受。

---

## 变更范围

### 1. `backend/app/core/security.py`

- `CryptContext` 增加 `bcrypt__rounds=10`
- 新增函数 `rehash_password_if_needed(plain_password, hashed_password) -> str | None`
  - 调用 `pwd_context.needs_update(hashed_password)` 判断是否需要迁移
  - 需要时返回新哈希字符串，不需要时返回 `None`

### 2. `backend/app/api/v1/endpoints/auth.py`（`login` 函数）

- 密码验证通过后，调用 `rehash_password_if_needed`
- 若返回新哈希，写回 `user.password_hash`（随当次 `db.commit()` 一同提交，无额外事务）

---

## 不在范围内

- 不改动 Redis 缓存层
- 不改动其他使用 `get_password_hash` / `verify_password` 的地方（注册、修改密码等流程将自动使用新 rounds）
- 不做批量 rehash 脚本

---

## 测试要求

- 单元测试：验证 `rehash_password_if_needed` 对 rounds=12 哈希返回非 None，对 rounds=10 哈希返回 None
- 集成验证：修改部署后重跑 40并发压测，确认 login P95 < 500ms

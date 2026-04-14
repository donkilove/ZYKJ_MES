# Docker 后端自动化回归与后续治理实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 固化 Docker 后端自动化回归入口，补长链路业务校验，并在自动化兜底下继续扩事务边界统一与 `authz` 写路径拆分。

**Architecture:** 先新增单个 Python 脚本作为 Docker 回归入口，统一负责环境变量注入、`docker compose` 生命周期、健康等待和 HTTP 断言；再在这套自动化中补首件、生产订单、导出三类长链路；最后继续清理剩余双层提交链路，并把 `authz` 写路径 helper 进一步下沉到独立模块。

**Tech Stack:** Python 3.14、本地 `.venv`、httpx、docker compose、FastAPI、SQLAlchemy、unittest

---

### Task 1: 固化 Docker 后端自动化烟测脚本

**Files:**
- Create: `tools/docker_backend_smoke.py`
- Modify: `compose.yml`
- Modify: `evidence/2026-04-14_Docker后端自动化回归与后续治理.md`

- [ ] **Step 1: 写失败测试或最小可复现入口约束**

在脚本实现前先锁定当前必须支持的行为：

```python
DEFAULT_ENV = {
    "POSTGRES_HOST_PORT": "5433",
    "BACKEND_WEB_HOST_PORT": "8000",
    "JWT_SECRET_KEY": "docker-local-jwt-secret-20260414",
    "BOOTSTRAP_ADMIN_PASSWORD": "Admin_Local_20260414!",
    "PRODUCTION_DEFAULT_VERIFICATION_CODE": "FA20260414",
}
```

以及必须按顺序完成：

```python
CHECKS = [
    "health",
    "login",
    "authz_catalog",
    "role_create",
    "user_create",
    "product_create",
]
```

- [ ] **Step 2: 运行最小入口确认当前仓库还没有统一脚本**

Run: `.\\.venv\\Scripts\\python.exe tools\\docker_backend_smoke.py --help`
Expected: FAIL，提示文件不存在

- [ ] **Step 3: 实现脚本骨架**

脚本最小结构：

```python
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from dataclasses import dataclass

import httpx


@dataclass(frozen=True)
class SmokeContext:
    base_url: str
    admin_password: str
```

要求：
- 统一注入 Docker 环境变量
- 提供 `up`、`down`、`run` 三类动作或等价参数
- 所有失败都带步骤名和 stderr/response body

- [ ] **Step 4: 实现 Docker 生命周期和健康等待**

至少包含：

```python
def docker_compose(*args: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["docker", "compose", *args],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
        env=env,
    )
```

```python
def wait_for_health(base_url: str, timeout_seconds: float = 60.0) -> None:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        try:
            response = httpx.get(f"{base_url}/health", timeout=5.0)
            if response.status_code == 200:
                return
        except Exception:
            pass
        time.sleep(1.0)
    raise RuntimeError("backend health check timeout")
```

- [ ] **Step 5: 实现第一批烟测**

脚本内至少固化：

```python
def smoke_login(client: httpx.Client, ctx: SmokeContext) -> str:
    response = client.post(
        f"{ctx.base_url}/api/v1/auth/login",
        data={"username": "admin", "password": ctx.admin_password},
    )
    assert response.status_code == 200, response.text
    return response.json()["data"]["access_token"]
```

并继续实现：
- `/health`
- `authz` 目录读取
- 角色创建
- 用户创建
- 产品创建

- [ ] **Step 6: 运行脚本验证第一批烟测**

Run: `.\\.venv\\Scripts\\python.exe tools\\docker_backend_smoke.py`
Expected: 输出每一步状态并以成功退出

### Task 2: 在自动化脚本中补三类长链路

**Files:**
- Modify: `tools/docker_backend_smoke.py`
- Modify: `evidence/2026-04-14_Docker后端自动化回归与后续治理.md`

- [ ] **Step 1: 先补首件提交流程的失败断言**

长链路检查结构示例：

```python
def smoke_first_article_flow(client: httpx.Client, token: str) -> None:
    # 创建工段、工序、产品、订单、模板
    # 拉取模板与参数
    # 提交首件
    # 校验返回体关键字段
```

要求：
- 不只断言 `200`
- 至少校验模板、参与人、提交结果或关键返回字段

- [ ] **Step 2: 先补生产订单主链路**

至少覆盖：
- 创建工段/工序
- 创建产品并激活
- 创建订单
- 查询订单或相关主链路接口

- [ ] **Step 3: 先补导出链路**

至少覆盖一条导出接口：

```python
def smoke_export_flow(client: httpx.Client, token: str) -> None:
    response = client.post(...)
    assert response.status_code == 200, response.text
    payload = response.json()["data"]
    assert payload["content_base64"]
```

- [ ] **Step 4: 重跑脚本，确认长链路成功**

Run: `.\\.venv\\Scripts\\python.exe tools\\docker_backend_smoke.py`
Expected: 第一批烟测 + 三类长链路全部成功

### Task 3: 扩大事务边界统一范围

**Files:**
- Modify: `backend/app/services/message_service.py`
- Modify: `backend/app/api/v1/endpoints/messages.py`
- Modify: `backend/app/services/equipment_service.py`
- Modify: `backend/app/api/v1/endpoints/equipment.py`
- Modify: `backend/tests/test_transaction_boundary_unit.py`

- [ ] **Step 1: 为下一批链路先写红灯测试**

优先锁定两组模式：

```python
def test_message_related_service_does_not_commit_transaction(self) -> None:
    ...
```

```python
def test_equipment_related_api_rolls_back_when_audit_or_followup_fails(self) -> None:
    ...
```

- [ ] **Step 2: 运行事务边界红灯**

Run: `.\\.venv\\Scripts\\python.exe -m unittest backend.tests.test_transaction_boundary_unit`
Expected: 新增场景失败，体现双层提交或缺少回滚

- [ ] **Step 3: 做最小实现**

原则：
- service 只负责对象构建和 `flush()`
- API 负责最终 `commit()/rollback()`
- 不顺手改无关逻辑

- [ ] **Step 4: 重跑事务边界测试**

Run: `.\\.venv\\Scripts\\python.exe -m unittest backend.tests.test_transaction_boundary_unit`
Expected: PASS

### Task 4: 继续拆 authz 写路径

**Files:**
- Create: `backend/app/services/authz_matrix_write_service.py`
- Modify: `backend/app/services/authz_write_service.py`
- Modify: `backend/app/services/authz_service.py`
- Modify: `backend/tests/test_authz_split_unit.py`

- [ ] **Step 1: 先写红灯测试，锁定写路径 helper**

新增至少一类写路径断言：

```python
def test_apply_capability_pack_role_configs_delegates_write_helper(self) -> None:
    ...
```

或：

```python
def test_update_permission_hierarchy_role_config_uses_matrix_write_helper(self) -> None:
    ...
```

- [ ] **Step 2: 运行 authz 拆分红灯**

Run: `.\\.venv\\Scripts\\python.exe -m unittest backend.tests.test_authz_split_unit`
Expected: FAIL，因为新 helper 尚未落地

- [ ] **Step 3: 抽出下一批写路径 helper**

优先抽出：
- 角色权限矩阵更新
- 能力包批量应用中的共享落库逻辑

要求：
- `authz_service.py` 保持对外接口稳定
- 新模块职责单一

- [ ] **Step 4: 重跑 authz 拆分与兼容性测试**

Run:
- `.\\.venv\\Scripts\\python.exe -m unittest backend.tests.test_authz_split_unit`
- `.\\.venv\\Scripts\\python.exe -m unittest backend.tests.test_authz_service_unit backend.tests.test_authz_catalog_unit backend.tests.test_authz_endpoint_unit`

Expected: PASS

### Task 5: 统一验证与留痕

**Files:**
- Modify: `evidence/2026-04-14_Docker后端自动化回归与后续治理.md`
- Modify: `evidence/2026-04-14_后端三项优先改造实施.md`

- [ ] **Step 1: 运行本轮完整验证**

Run:

```powershell
.\\.venv\\Scripts\\python.exe tools\\docker_backend_smoke.py
.\\.venv\\Scripts\\python.exe -m unittest backend.tests.test_transaction_boundary_unit
.\\.venv\\Scripts\\python.exe -m unittest backend.tests.test_authz_split_unit backend.tests.test_authz_service_unit backend.tests.test_authz_catalog_unit backend.tests.test_authz_endpoint_unit
```

Expected:
- Docker 自动化回归成功
- 事务边界测试通过
- authz 相关测试通过

- [ ] **Step 2: 更新 evidence**

补充：
- 本轮新增脚本入口
- Docker 长链路覆盖范围
- 新增事务边界链路
- 新增 authz 写路径拆分
- 真实命令与结果

- [ ] **Step 3: 输出收口结论**

要求：
- 明确完成项与未完成项
- 明确残余风险
- 迁移口径统一写：`无迁移，直接替换`

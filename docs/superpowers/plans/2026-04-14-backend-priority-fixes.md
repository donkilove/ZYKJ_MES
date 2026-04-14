# 后端三项优先改造实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成后端安全硬化、事务边界统一和 `authz` 首批拆分，并保留真实验证结果。

**Architecture:** 先通过配置和入口校验阻断危险默认值，再把产品/角色创建链路的提交职责收回 API 层，最后对 `authz_service` 抽取低耦合职责。实现过程遵循 TDD，先写失败测试，再写最小实现。

**Tech Stack:** FastAPI、SQLAlchemy、Pydantic Settings、unittest、pytest、PowerShell

---

### Task 1: 安全硬化

**Files:**
- Modify: `backend/app/core/config.py`
- Modify: `backend/app/core/security.py`
- Modify: `backend/app/main.py`
- Modify: `backend/app/worker_main.py`
- Modify: `backend/app/services/production_execution_service.py`
- Modify: `backend/app/services/quality_service.py`
- Test: `backend/tests/test_security_unit.py`
- Test: `backend/tests/test_app_startup_worker_split.py`

- [ ] 先写失败测试，覆盖危险默认 JWT 密钥和运行态安全校验
- [ ] 跑最小测试，确认先失败
- [ ] 实现运行态安全校验与 fail-fast
- [ ] 修正首件验证码缺失时的弱默认值回退
- [ ] 重跑最小测试

### Task 2: 事务边界统一

**Files:**
- Modify: `backend/app/services/product_service.py`
- Modify: `backend/app/api/v1/endpoints/products.py`
- Modify: `backend/app/services/role_service.py`
- Modify: `backend/app/api/v1/endpoints/roles.py`
- Test: `backend/tests/test_product_module_integration.py`

- [ ] 先写失败测试，证明审计失败时会留下非原子状态
- [ ] 跑相关测试，确认旧行为不满足要求
- [ ] 移除 service 层内部 `commit()`
- [ ] 由 API 层统一 `commit()/rollback()`
- [ ] 重跑相关测试

### Task 3: authz 首批拆分

**Files:**
- Create: `backend/app/services/authz_cache_service.py`
- Create: `backend/app/services/authz_query_service.py`
- Modify: `backend/app/services/authz_service.py`
- Test: `backend/tests/test_authz_service_unit.py`

- [ ] 先写失败测试或锁定当前行为
- [ ] 抽出缓存 / revision 职责
- [ ] 抽出权限读取 / code 计算职责
- [ ] 重跑 authz 相关测试

### Task 4: 验证与留痕

**Files:**
- Modify: `evidence/2026-04-14_后端三项优先改造实施.md`

- [ ] 运行本轮最小验证集合
- [ ] 写明通过结果与未验证边界
- [ ] 交付口径统一写明：`无迁移，直接替换`

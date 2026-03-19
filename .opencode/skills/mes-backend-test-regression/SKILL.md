---
name: mes-backend-test-regression
description: 为 ZYKJ_MES 后端补充或执行服务层与接口层回归测试，并控制启动 bootstrap 与数据库副作用。
---

# mes-backend-test-regression

## 何时使用

- 后端业务逻辑改动较大，需要可重复回归验证。
- 需要给 FastAPI 接口、Service 规则或鉴权依赖补测试。
- 需要避免只靠 `compileall` 判断后端改动是否安全。

## 不适用场景

- 用户只要求快速改 UI 文案，不涉及后端。
- 仅做代码审查，不准备新增或运行测试。
- 任务目标是本地启动联调而不是测试建设。

## 本仓库关键路径

- `backend/app/services/`
- `backend/app/api/v1/endpoints/`
- `backend/app/api/deps.py`
- `backend/app/core/`
- `backend/tests/`
- `backend/requirements.txt`

## 当前仓库现状

- 当前仓库前端测试较多，后端测试基础相对薄弱。
- 若任务要求补后端测试，可以在 `backend/tests/` 下按模块建立最小可用测试结构。
- 若当前环境未安装 pytest 相关依赖，要先判断是否允许补依赖，再决定是否新增测试代码。

## 默认原则

- 优先写针对变更点的最小回归，不盲目铺全量大而全测试。
- 优先隔离业务逻辑与鉴权依赖，避免测试触发真实启动 bootstrap。
- 未经批准，不连接或污染真实数据库；能用 fixture 或临时库就不要碰现有业务库。

## 执行步骤

1. 确定测试目标：Service 规则、Endpoint 契约、权限依赖还是异常路径。
2. 优先为高风险业务规则写服务层测试，为公开契约与鉴权写接口层测试。
3. 若新增测试目录，按模块分层放到 `backend/tests/`，命名保持可读与可定位。
4. 处理数据库依赖时，优先使用可隔离的 fixture、事务回滚或临时库。
5. 避免通过 `start_backend.py` 拉服务来测试接口，以免触发建库、迁移、seed。
6. 运行目标测试；若环境不具备 pytest 条件，至少执行 `python -m compileall backend/app backend/alembic` 并说明限制。

## 验证与证据

- 首选：目标 pytest 用例全部通过。
- 次选：至少完成 `compileall`，并把未执行 pytest 的原因写清楚。
- 对公开接口测试，覆盖成功、鉴权失败、权限拒绝、关键校验失败四类场景。

## 输出要求

- 明确说明新增或运行了哪些后端测试。
- 明确说明是否使用了临时库、mock 或 fixture。
- 若未能运行 pytest，必须说明受限点和下一步建议。

## 风险提示

- 仓库启动链路自带 bootstrap 副作用，不适合作为接口测试驱动方式。
- 测试若直接依赖当前开发库，容易与现有未提交业务改动相互污染。

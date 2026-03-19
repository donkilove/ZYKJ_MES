---
name: mes-backend-change-pipeline
description: 在 ZYKJ_MES 仓库中执行 FastAPI 后端模型、Schema、Service、Endpoint、Alembic 联动变更。
---

# mes-backend-change-pipeline

## 何时使用

- 需要修改 `backend/app/models/` 中的业务实体、字段或关联关系。
- 需要同步调整 `backend/app/schemas/`、`backend/app/services/`、`backend/app/api/v1/endpoints/`。
- 需要评估 Alembic 迁移、启动 bootstrap 或公开接口影响面。

## 不适用场景

- 仅修改 Flutter 页面样式或交互。
- 仅做需求审查文档，不改后端实现。
- 仅排查本地启动参数，不涉及后端业务对象。

## 本仓库关键路径

- `backend/app/models/`
- `backend/app/schemas/`
- `backend/app/services/`
- `backend/app/api/v1/endpoints/`
- `backend/app/db/base.py`
- `backend/alembic/versions/`
- `backend/app/bootstrap/startup_bootstrap.py`

## 默认原则

- 先确认单一真实数据模型，再改代码，避免让旧字段和新字段长期并存。
- 默认遵循仓库规则做直接替换，不主动保留向后兼容层，除非用户明确要求。
- 先梳理影响面，再小步修改，避免只改一层造成前后不一致。
- 任何会改数据库状态的动作都要单独判断，不能因为写了迁移就默认执行迁移。

## 执行步骤

1. 明确目标业务对象、现状痛点和最终公开契约。
2. 从 `models` 开始核对 ORM 字段、关联关系与枚举语义。
3. 检查 `backend/app/db/base.py` 是否需要注册新模型。
4. 同步更新 `schemas`，明确输入输出字段并清理废弃字段。
5. 更新 `services` 中的读写逻辑、校验、事务与领域规则。
6. 更新 `endpoints` 的请求参数、响应模型、错误语义与权限依赖。
7. 如涉及表结构变化，新增 Alembic 脚本，并评估 `startup_bootstrap.py` 的启动副作用。
8. 如公开契约变化会影响前端，联动使用 `mes-contract-sync-fastapi-flutter`。
9. 仅在用户明确要求或任务明确要求时执行 `alembic upgrade head`。

## 验证与证据

- 最低验证：`python -m compileall backend/app backend/alembic`
- 如仓库已有或本次新增后端测试，优先运行目标测试而不是笼统全量。
- 若未执行迁移、联调或真实数据验证，必须在交付里写明局限。
- 若存在不兼容变更，必须明确写出“无迁移，直接替换”或给出迁移方案。

## 输出要求

- 明确列出改动涉及的后端层级与关键文件。
- 明确声明是否新增迁移脚本，以及迁移是否已执行。
- 明确声明是否为破坏性替换，以及为何这样做。

## 风险提示

- `start_backend.py` 与应用启动会触发 bootstrap，包含建库、迁移、seed 风险，不能把“写代码”和“执行启动”混为一体。
- Alembic 脚本一旦执行就会改变数据库状态；若用户未明确要求执行，只提交脚本即可。

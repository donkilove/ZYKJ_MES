---
name: mes-contract-sync-fastapi-flutter
description: 在 ZYKJ_MES 仓库中同步 FastAPI 与 Flutter 的公开契约，确保模型、服务、页面与测试同时收敛。
---

# mes-contract-sync-fastapi-flutter

## 何时使用

- 后端请求或响应字段发生变化，需要前端同步收口。
- 出现“后端已改、前端页面或测试仍按旧契约工作”的问题。
- 需求审查指出同一业务对象在后端与前端存在不同语义。

## 不适用场景

- 仅改数据库内部结构，但公开接口不变。
- 仅改页面视觉样式，不改数据结构和接口调用。
- 仅改后端内部实现，不影响前端模型或接口语义。

## 本仓库关键路径

- `backend/app/schemas/`
- `backend/app/api/v1/endpoints/`
- `backend/app/services/`
- `frontend/lib/models/`
- `frontend/lib/services/`
- `frontend/lib/pages/`
- `frontend/test/models/`
- `frontend/test/services/`
- `frontend/test/widgets/`

## 默认原则

- 先定义目标契约，再同时修改两端，不允许只改一侧后留待下次补齐。
- 默认直接移除过时字段，不长期保留旧字段别名或兼容输入。
- 交付时要明确单一真源字段，避免页面、模型、服务各自翻译一套。

## 执行步骤

1. 列出当前契约与目标契约，明确字段名、数据类型、是否必填、默认值和语义变化。
2. 先改后端 `schemas` 与 `endpoints`，确保接口层表达统一。
3. 视需要更新后端 `services`，保证业务逻辑与新契约一致。
4. 同步更新前端 `models`，去掉过时字段并校正序列化反序列化逻辑。
5. 更新前端 `services` 的请求体、查询参数和错误处理。
6. 更新受影响页面，修正显示、输入、校验、筛选与导出逻辑。
7. 同步更新模型测试、服务测试与页面回归测试，避免测试继续锁定旧契约。
8. 检查文档、审查记录与交付说明中的术语，避免沿用旧字段名。

## 验证与证据

- 后端最低验证：`python -m compileall backend/app`
- 前端最低验证：`flutter analyze`
- 优先运行目标回归：例如受影响模块对应的 `frontend/test/models/`、`frontend/test/services/`、`frontend/test/widgets/`
- 若后端联调未执行，必须在结果中说明“仅完成静态校验与单侧测试”。

## 输出要求

- 明确给出旧契约与新契约的差异。
- 明确列出后端、前端、测试分别改了哪些文件。
- 明确声明是否存在破坏性替换，以及调用方需要注意什么。

## 风险提示

- 这个仓库经常出现“业务代码已同步，但测试仍指向旧契约”的问题，必须把测试视为主链路的一部分。
- 若契约变化涉及权限字段、页面 code 或能力码，不要在本技能里独立拍板，应联动 `mes-rbac-page-visibility`。

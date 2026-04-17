# 后端 P95-40 并发 `405/422` 差异清单（production + craft 第一批）

## 1. 适用范围

本文只记录第一批 `production + craft` 场景拆分中发现的 `405/422` 契约差异，目标是支撑：

- `tools/perf/scenarios/production_craft_read_40_scan.json`
- `tools/perf/scenarios/production_craft_detail_40_scan.json`
- `tools/perf/scenarios/production_craft_write_40_scan.json`
- `tools/perf/scenarios/combined_40_scan.json`

## 2. 405 差异清单

| 编号 | 优先级 | 模块 | 场景名 | 请求方法 | 请求路径 | 当前场景定义 | 实际接口定义/观察 | 差异说明 | 修复动作 | 责任人 | 状态 | 复检结果 | 证据 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 405-PC-001 | P0 | craft | `craft-stage-update` | `PUT` | `/api/v1/craft/stages/1` | 写死历史 `id=1` | 需使用当前稳定样本 `stage_id` | 固定 `id` 在环境重置后不可靠，易转成 `404/405` 噪声 | 改为 `/api/v1/craft/stages/{sample:stage_id}` | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |
| 405-PC-002 | P0 | craft | `craft-process-update` | `PUT` | `/api/v1/craft/processes/1` | 写死历史 `id=1` | 需使用当前稳定样本 `process_id` | 固定 `id` 不再适合作为长期基线 | 改为 `/api/v1/craft/processes/{sample:process_id}` | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |
| 405-PC-003 | P0 | craft | `craft-template-detail` / `publish` / `rollback` / `draft` | `GET` / `POST` | `/api/v1/craft/templates/1/*` | 写死历史 `template_id=1` | 需绑定稳定样本 `craft_template_id` | 固定模板 `id` 在不同环境不可复用 | 改为 `{sample:craft_template_id}` 占位符 | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |
| 405-PC-004 | P0 | production | `production-order-detail-18` 等 | `GET` / `PUT` / `POST` | `/api/v1/production/orders/18/*` | 写死历史 `order_id=18` | 需绑定稳定样本 `production_order_id` | 固定订单 `id` 破坏环境可重复性 | 改为 `{sample:production_order_id}` 占位符 | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |

## 3. 422 差异清单

| 编号 | 优先级 | 模块 | 场景名 | 请求方法 | 请求路径 | 最小必需参数/字段 | 当前场景实参 | 实际返回摘要 | 差异说明 | 修复动作 | 责任人 | 状态 | 复检结果 | 证据 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 422-PC-001 | P1 | craft | `craft-stage-create` | `POST` | `/api/v1/craft/stages` | `code`、`name`、`sort_order`、`remark` | 使用旧字段 `stage_code`、`stage_name`、`is_enabled` | 422 | 场景 payload 沿用旧接口字段命名 | 改为当前 schema：`code/name/sort_order/remark` | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |
| 422-PC-002 | P1 | craft | `craft-process-create` | `POST` | `/api/v1/craft/processes` | `code`、`name`、`stage_id`、`remark` | 使用旧字段 `process_code`、`process_name`、`process_order` | 422 | payload 与当前 schema 不一致 | 改为当前 schema：`code/name/stage_id/remark` | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |
| 422-PC-003 | P1 | craft | `craft-template-create` | `POST` | `/api/v1/craft/templates` | `product_id`、`template_name`、`steps[]` | 使用旧字段 `process_code`、`stage_id`、`is_enabled` | 422 | 缺少 `steps`，且字段口径已过期 | 改为 `steps` 数组并使用样本占位符 | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |
| 422-PC-004 | P1 | craft | `craft-template-update` | `PUT` | `/api/v1/craft/templates/{sample:craft_template_id}` | `template_name`、`is_default`、`is_enabled`、`remark`、`steps`、`sync_orders` | 仅传部分标量字段 | 422 | 当前接口强制要求完整 `steps` | 改为完整更新 payload | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |
| 422-PC-005 | P1 | production | `production-order-first-article-templates` / `parameters` | `GET` | `/api/v1/production/orders/{sample:production_order_id}/first-article/*` | `order_process_id` | 写死历史值 `18` | 422 | query 需要真实 `order_process_id` 而不是 `order_id` | 改为 `{sample:order_process_id}` | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |
| 422-PC-006 | P1 | production | `production-order-first-article` | `POST` | `/api/v1/production/orders/{sample:production_order_id}/first-article` | `order_process_id`、`verification_code`、有效模板/工序上下文 | 使用硬编码 `1/18` | 422 | 场景未绑定稳定样本与真实工序上下文 | 改为占位符 + 样本合同 | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |
| 422-PC-007 | P1 | production | `production-assist-authorization-create` | `POST` | `/api/v1/production/orders/{sample:production_order_id}/assist-authorizations` | `order_process_id`、`target_operator_user_id`、`helper_user_id` | 使用硬编码 `1/2/3` | 422 | 当前场景未绑定真实用户与工序上下文 | 改为 `{sample:order_process_id}` 与 `{sample:admin_user_id}` | Codex | 已处理 | 待复跑 | `combined_40_scan.json` |

## 4. 当前结论

- 第一批已先修正最容易形成成批 `405/422` 的核心场景。
- 这些修正的重点不是“让所有 production + craft 路由一次过”，而是先把样本、路径、参数口径与当前实现对齐。
- 下一轮复跑后，应把仍未通过的差异继续登记到本表，而不是重新回退到硬编码 `id` 或旧字段名。

## 5. 迁移说明

- 无迁移，直接替换

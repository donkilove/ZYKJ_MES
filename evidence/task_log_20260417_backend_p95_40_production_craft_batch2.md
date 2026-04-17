# 任务日志：后端 40 并发 P95 第二批收敛（production + craft）

- 日期：2026-04-17
- 执行人：Codex 主 agent
- 当前状态：进行中
- 工作树：`/root/code/ZYKJ_MES/.worktrees/backend-p95-40-production-craft-phase1`
- 分支：`feature/backend-p95-40-production-craft-phase1`

## 1. 输入来源

- 上一批结果：
  - `.tmp_runtime/production_craft_detail_40_20260417_171731.json`
  - `.tmp_runtime/production_craft_write_40_20260417_171834.json`
  - `.tmp_runtime/combined_40_production_craft_roundtrip_20260417_172012.json`
- 用户指令：继续开始下一批
- 目标：继续提升 `production + craft` 的模块级成功率与可解释性

## 2. 当前目标

1. 优先拆清 `detail` 套件中的剩余异常与高延迟点。
2. 优先收敛 `write` 套件中的 `400/404/500` 主噪声来源。
3. 用定向测试和模块级压测复检修复是否生效。

## 3. 当前初始判断

- `read` 套件已过门禁，可暂不作为主要矫正对象。
- `detail` 套件仍存在：
  - `production-order-first-article-parameters` => `500`
  - `production-my-order-context` => `EXC`
  - 多个 detail 场景 `P95` 仍偏高
- `write` 套件仍存在大面积：
  - `400`
  - `404`
  - `500`

## 4. 当前推进结果

- 已确认 `production_admin` 账号池（`ltprd*`）登录本身可用，但初始脚本下发后的 `production/craft` 权限快照为空。
- 已在代码层把 `perf_capacity_permission_service` 从 capability pack 口径切到真实 permission catalog 口径，并补齐对应单测。
- 基于运行期临时权限直铺后，模块级 `read` 套件结果显著改善：
  - `success_rate=98.69%`
  - `p95_ms=476.09`
  - `gate_passed=true`
- `detail` 套件已大幅进入成功路径，但仍暴露：
  - `production-order-first-article-parameters` => `500`
  - `production-my-order-context` => `EXC`
  - 多个 detail 场景 `p95_ms > 700 ms`
- 在继续手工诊断时，后端日志已出现明确的数据库连接池耗尽异常：
  - `sqlalchemy.exc.TimeoutError: QueuePool limit of size 6 overflow 4 reached`
- 当前第二批的下一焦点已收敛为：
  1. 把权限下发修正提交入库，消除运行时手工直铺依赖
  2. 收敛 detail/write 阶段的连接池瓶颈与剩余业务异常

## 5. 迁移说明

- 无迁移，直接替换

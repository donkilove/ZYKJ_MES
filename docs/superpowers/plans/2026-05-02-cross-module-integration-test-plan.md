# 用户/产品/工艺/质量/生产跨模块联调测试计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有“生产主链已跑通”的基础上，系统补齐用户、产品、工艺、质量、生产五个模块的异常流、变更流与边界联动验证，形成可复用、可复测、可留痕的联调测试计划。

**Architecture:** 计划以“真实账号 + 真实 API + 真实数据库状态核对”为主，按模块拆分测试主题，再按跨模块业务链路组织场景。执行顺序遵循“先稳定基础样本，再跑低破坏场景，再跑会改变在制状态的高风险场景”，每个场景同时记录接口结果、数据库事实与 UI/权限口径。

**Tech Stack:** FastAPI/TestClient、真实 HTTP API、PostgreSQL、Docker Compose、`pytest`、项目内 perf 种子脚本、`evidence/` 留痕文档。

---

## 一、计划定位

这不是“补几个接口测试”的计划，而是面向真实业务联动的测试执行蓝图。目标不是追求全模块全接口覆盖，而是优先覆盖以下高风险断点：

1. 用户绑定/角色切换是否会影响在制工单的可见性与可执行性。
2. 产品版本、参数、回滚是否会影响在制工单、模板、首件参数和质量读数。
3. 工艺模板发布/回滚在 `apply_order_sync=true` 时，是否真正影响现有工单路线与影响分析结果。
4. 质量不通过、复判、返修、回流、报废等复杂分支是否与生产状态一致。
5. 生产执行异常分支是否符合口径，尤其是中途换人、代班取消、返修回流、多返工、流水线切换/禁用。

## 二、测试范围

### 1. 用户模块

- 用户创建、编辑、删除/停用
- 角色切换
- 工序绑定/解绑
- 不同角色组合：
  - `system_admin`
  - `production_admin`
  - `quality_admin`
  - `operator`
  - 跨角色组合用户

### 2. 产品模块

- 产品激活/停用
- 参数变更
- 版本发布
- 版本回滚
- impact-analysis

### 3. 工艺模块

- 模板草稿 -> 发布
- 模板回滚
- `apply_order_sync=true`
- 工艺影响分析
- 模板/工序/工段引用校验

### 4. 质量模块

- 首件通过/不通过
- 处置流
- 复判流
- 缺陷 -> 返修 -> 报废/回流
- 统计筛选

### 5. 生产模块

- 正常模式
- 流水线模式
- 代班
- 换人
- 返修回流
- 多返工路径
- 流水线禁用/切换

## 三、测试前置

### Task 1: 环境与样本基线

**Files:**
- Modify: `task_plan.md`
- Modify: `progress.md`
- Modify: `findings.md`
- Test: `backend/scripts/init_perf_capacity_users.py`
- Test: `backend/scripts/init_perf_production_craft_samples.py`

- [ ] **Step 1: 确认后端运行状态**

运行：

```powershell
docker compose ps
```

预期：
- `backend-web`、`backend-worker`、`postgres`、`redis` 均为 `Up`
- `backend-web` 与 `postgres` 为 `healthy`

- [ ] **Step 2: 确认宿主健康检查可用**

运行：

```powershell
try { (Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/health).Content } catch { $_.Exception.Message }
```

预期：

```json
{"status":"ok"}
```

- [ ] **Step 3: 重置 perf 用户权限与密码**

运行：

```powershell
docker exec -i zykj_mes-backend-web-1 python backend/scripts/init_perf_capacity_users.py --password "Perf@20260502!"
```

预期：
- 输出包含 `created=` / `updated=` / `permission_updates=`
- `ltadm1`、`ltprd1`、`ltqua1`、`ltopr1~4` 均可登录

- [ ] **Step 4: 刷新生产/工艺基线样本**

运行：

```powershell
docker exec -i zykj_mes-backend-web-1 python backend/scripts/init_perf_production_craft_samples.py --mode ensure --run-id baseline
```

预期：
- 输出 JSON，包含 `created_count`、`updated_count`
- 稳定样本包含 `PERF-PRODUCT-STD-01`、`PERF-TEMPLATE-STD-01`、`PERF-PROCESS-STD-01/02`

- [ ] **Step 5: 记录基线上下文**

写入：
- 基线产品、模板、工序、供应商、验证码
- 当前测试账号绑定情况
- 当前后端镜像/端口口径

- [ ] **Step 6: 提交留痕更新**

```bash
git add task_plan.md progress.md findings.md
git commit -m "docs: 更新跨模块联调计划前置记录"
```

## 四、测试数据策略

### Task 2: 测试批次与命名规范

**Files:**
- Create: `evidence/2026-05/联调批次命名规范.md`
- Modify: `progress.md`

- [ ] **Step 1: 约定批次命名**

本轮统一使用：

```text
EVAL-USR-<batch>
EVAL-PRD-<batch>
EVAL-CRAFT-<batch>
EVAL-QUAL-<batch>
EVAL-PIPE-<batch>
```

- [ ] **Step 2: 约定订单类型**

定义 5 类工单：
- `normal-complete`：正常模式完整完工
- `quality-failed`：首件失败/返修/报废
- `pipeline-complete`：流水线完整完工
- `sync-impact`：产品/工艺版本变更中的在制工单
- `edge-case`：权限、换人、解绑、禁用等异常流

- [ ] **Step 3: 约定账号用途**

- `ltprd1`：生产管理员操作主账号
- `ltqua1`：质量主账号
- `ltopr1`：首工序操作员
- `ltopr2`：次工序操作员
- `ltopr3`：helper / 代班 / 换人场景账号
- `ltopr4`：未绑定/边界校验账号

- [ ] **Step 4: 记录批次规范**

在 `evidence/2026-05/联调批次命名规范.md` 写入：
- 命名约定
- 工单类型
- 账号用途
- 清理策略

- [ ] **Step 5: 提交批次规范**

```bash
git add evidence/2026-05/联调批次命名规范.md progress.md
git commit -m "docs: 补充联调批次与账号规范"
```

## 五、模块级联调场景

### Task 3: 用户模块联调场景

**Files:**
- Modify: `evidence/2026-05/2026-05-02_模块联动评估.md`
- Test: `backend/tests/test_production_module_integration.py`
- Test: `backend/tests/test_user_module_integration.py`（若不存在则按实际用户模块测试文件补充）

- [ ] **Step 1: 用户新增 + 工序绑定后能看到 own 工单**

执行：
1. 新建操作员
2. 绑定 `PERF-PROCESS-STD-01`
3. 创建对应新工单
4. 校验 `/production/my-orders`

预期：
- 列表非空
- `current_process_code=PERF-PROCESS-STD-01`

- [ ] **Step 2: 用户解绑工序后 own 视图立即失效**

执行：
1. 让操作员对工单已有历史执行记录
2. 移除该用户工序绑定
3. 重新请求 `/production/my-orders`

预期：
- own 视图为空
- `/production/orders/{id}/first-article` / `end-production` 返回权限/口径拦截

- [ ] **Step 3: 存在 in_progress 子工单时，解绑工序应被拒绝**

执行：
1. 首件后进入 `in_progress`
2. 更新用户，移除当前工序绑定

预期：
- 用户更新失败
- 错误提示类似“存在生产中的工序参与，不能移除该用户的工序绑定”

- [ ] **Step 4: 角色切换对生产入口生效**

执行：
1. 将操作员切为无生产权限角色
2. 访问 `/production/my-orders`
3. 恢复角色

预期：
- 降权后返回 `403`
- 恢复后可访问

- [ ] **Step 5: 混合角色组合校验**

组合：
- `operator + quality_admin`
- `operator + production_admin`
- `quality_admin + production_admin`

预期：
- 生产执行、质量查看、工单管理权限口径符合组合预期

- [ ] **Step 6: 代班例外口径回归**

执行：
1. helper 不绑定目标工序
2. 发起 assist
3. helper 通过 assist 视图执行

预期：
- own 视图不可见
- assist 视图可见且可执行

- [ ] **Step 7: 记录用户联调结果**

记录：
- 成功场景
- 拒绝场景
- 角色组合矩阵

- [ ] **Step 8: 提交用户场景留痕**

```bash
git add evidence/2026-05/2026-05-02_模块联动评估.md progress.md findings.md
git commit -m "docs: 补充用户模块联调场景计划"
```

### Task 4: 产品模块联调场景

**Files:**
- Modify: `evidence/2026-05/2026-05-02_模块联动评估.md`
- Test: `backend/tests/test_product_module_integration.py`

- [ ] **Step 1: 在制工单下的生命周期 impact-analysis**

执行：
1. 基于激活产品创建 `pending` 和 `in_progress` 工单
2. 调用 `/products/{id}/impact-analysis?target_status=inactive`

预期：
- 未完工工单全部列出
- `requires_confirmation=true`

- [ ] **Step 2: 产品参数变更后首件参数读取更新**

执行：
1. 调整产品参数
2. 新建工单
3. 查询 `/production/orders/{id}/first-article/parameters`

预期：
- 新工单读取到新参数
- 老工单行为符合当前设计口径（冻结或跟随）

- [ ] **Step 3: 产品版本发布对新旧工单差异**

执行：
1. 创建版本 v2
2. 发布 v2
3. 发布前后分别创建工单

预期：
- 新工单引用新版本
- 老工单保持原版本事实

- [ ] **Step 4: 产品回滚对在制工单联动**

执行：
1. 存在进行中工单
2. 调用 rollback impact-analysis
3. 执行 rollback（若允许）

预期：
- impact-analysis 能准确提示影响
- rollback 后新工单与老工单版本口径清晰

- [ ] **Step 5: 产品停用阻断建单**

执行：
1. 产品 inactive
2. 创建生产工单

预期：
- 建单失败
- 错误文案明确

- [ ] **Step 6: 记录产品联调结果**

- [ ] **Step 7: 提交产品场景留痕**

```bash
git add evidence/2026-05/2026-05-02_模块联动评估.md progress.md findings.md
git commit -m "docs: 补充产品模块联调场景计划"
```

### Task 5: 工艺模块联调场景

**Files:**
- Modify: `evidence/2026-05/2026-05-02_模块联动评估.md`
- Test: `backend/tests/test_craft_module_integration.py`

- [ ] **Step 1: 当前版本 impact-analysis 汇总/明细一致性**

执行：
1. 模板已发布
2. 基于该模板创建工单
3. 查询 `/craft/templates/{id}/impact-analysis`

预期：
- `syncable_orders + blocked_orders == total_orders`
- 汇总与 `items.syncable` 逐条一致

- [ ] **Step 2: 回滚目标版本 impact-analysis**

执行：
1. 模板 v1 发布
2. 草稿切换到新工序，发布 v2
3. 在 v2 下创建并推进工单
4. 分别查询 `target_version=1/2`

预期：
- 回滚到不兼容版本时出现 blocked
- 原因包含 `cannot align`

- [ ] **Step 3: apply_order_sync=true 发布路径**

执行：
1. 创建模板草稿变更
2. `publish(apply_order_sync=true)`
3. 对比订单路线是否真的发生变化

预期：
- 若当前设计是不回写订单，则 impact-analysis 与 publish 返回应明确体现
- 若设计应回写，则订单路线要真实变化

- [ ] **Step 4: apply_order_sync=true 回滚路径**

执行：
1. 模板存在历史版本
2. rollback with `apply_order_sync=true`

预期：
- 订单路线变更或阻断逻辑与 impact-analysis 一致

- [ ] **Step 5: 工段/工序删除与禁用阻断**

执行：
1. 工段/工序被模板、用户、工单引用
2. 尝试 disable/delete

预期：
- 阻断级引用时不能删除/停用

- [ ] **Step 6: 流水线相关模板变更**

执行：
1. 并行模式工单存在
2. 模板路线变更涉及流水线工序

预期：
- impact-analysis 能识别并行工序影响

- [ ] **Step 7: 记录工艺联调结果**

- [ ] **Step 8: 提交工艺场景留痕**

```bash
git add evidence/2026-05/2026-05-02_模块联动评估.md progress.md findings.md
git commit -m "docs: 补充工艺模块联调场景计划"
```

### Task 6: 质量模块联调场景

**Files:**
- Modify: `evidence/2026-05/2026-05-02_模块联动评估.md`
- Test: `backend/tests/test_quality_module_integration.py`
- Test: `backend/tests/test_production_module_integration.py`

- [ ] **Step 1: 首件不通过 -> 处置流**

执行：
1. 提交失败首件
2. 从质量侧查询首件记录
3. 提交 disposition

预期：
- 首件记录可查
- disposition 成功
- 审核/待办/审计有留痕

- [ ] **Step 2: 首件复判流**

执行：
1. 创建失败首件
2. 二次提交复判意见

预期：
- 复判字段完整
- 最终判定与生产后续动作口径一致

- [ ] **Step 3: 返修 -> 报废**

执行：
1. 缺陷自动建返修单
2. 质量侧 complete repair，全部报废

预期：
- scrap 统计更新
- repair detail / scrap detail 互相可追溯

- [ ] **Step 4: 返修 -> 回流**

执行：
1. repair complete 时填写 `return_allocations`
2. 回流到目标工序

预期：
- 目标工序 visible quantity / 子工单状态更新正确

- [ ] **Step 5: 统计筛选口径**

校验：
- 时间范围
- 产品名
- 工序编码
- 操作员
- result

预期：
- `overview / processes / operators / products` 口径一致

- [ ] **Step 6: 首件、返修、报废的导出契约**

执行：
- `first-articles/export`
- `repair-orders/export`
- `scrap-statistics/export`

预期：
- 导出结果与筛选结果一致

- [ ] **Step 7: 记录质量联调结果**

- [ ] **Step 8: 提交质量场景留痕**

```bash
git add evidence/2026-05/2026-05-02_模块联动评估.md progress.md findings.md
git commit -m "docs: 补充质量模块联调场景计划"
```

### Task 7: 生产模块异常流场景

**Files:**
- Modify: `evidence/2026-05/2026-05-02_模块联动评估.md`
- Test: `backend/tests/test_production_module_integration.py`

- [ ] **Step 1: 中途换人**

执行：
1. 操作员 A 首件后进入 `in_progress`
2. 操作员 B 绑定同工序
3. 尝试继续报工

预期：
- 行为符合系统设计：允许接续或必须代班

- [ ] **Step 2: 取消代班**

执行：
1. 创建 assist
2. 在执行前取消
3. helper 再次尝试执行

预期：
- 执行失败
- assist 状态变为 `cancelled`

- [ ] **Step 3: 多次代班与授权消耗**

执行：
1. 同一工单连续多次代班
2. 检查 `first_article_used_at` / `end_production_used_at`

预期：
- 每次授权只消费一次

- [ ] **Step 4: 返修回流到多工序**

执行：
1. repair complete
2. `return_allocations` 同时分配到多工序

预期：
- 多工序放行量与状态一致

- [ ] **Step 5: 多返工路径**

执行：
1. 首工序报工带缺陷
2. 返修回流
3. 再次报工再出缺陷

预期：
- 第二轮返修链路可正确累积

- [ ] **Step 6: 流水线禁用边界**

执行：
1. 并行实例存在且未完工
2. 尝试禁用流水线

预期：
- 应被阻止，并给出明确错误

- [ ] **Step 7: 流水线切换边界**

执行：
1. 已启用并行
2. 变更 `process_codes`

预期：
- 不能在存在活跃实例时随意切换

- [ ] **Step 8: 记录生产异常流结果**

- [ ] **Step 9: 提交生产异常流留痕**

```bash
git add evidence/2026-05/2026-05-02_模块联动评估.md progress.md findings.md
git commit -m "docs: 补充生产异常流联调场景计划"
```

## 六、执行顺序建议

### Task 8: 执行批次建议

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: 第一批执行**

优先级 P0：
- 用户解绑/角色切换
- 产品版本/回滚 impact-analysis
- 工艺 `apply_order_sync=true`
- 质量首件不通过/处置
- 生产换人/取消代班/流水线禁用

- [ ] **Step 2: 第二批执行**

优先级 P1：
- 多角色组合
- 参数变更影响
- 多返工路径
- 质量统计筛选矩阵

- [ ] **Step 3: 第三批执行**

优先级 P2：
- 导出契约
- 低风险引用/禁用边界
- UI 侧补充联调

- [ ] **Step 4: 记录批次顺序**

## 七、完成标准

### Task 9: 出口条件

**Files:**
- Modify: `evidence/2026-05/2026-05-02_模块联动评估.md`
- Modify: `findings.md`

- [ ] **Step 1: 主链完成标准**

必须满足：
- 正常模式完整跑通
- 流水线模式完整跑通
- 首件失败链路完整跑通
- 返修报废/回流至少各一条跑通

- [ ] **Step 2: 变更流完成标准**

必须满足：
- 用户解绑/角色切换至少各 1 条
- 产品版本切换/回滚至少各 1 条
- 工艺 apply_order_sync 发布/回滚至少各 1 条

- [ ] **Step 3: 异常流完成标准**

必须满足：
- 代班取消
- 中途换人
- 流水线禁用/切换阻断

- [ ] **Step 4: 输出标准**

最终输出至少包含：
- 已覆盖场景列表
- 未覆盖场景列表
- 已确认问题
- 残余风险
- 可复测 run_id / order_code / repair_order_code

- [ ] **Step 5: 提交最终收口**

```bash
git add evidence/2026-05/2026-05-02_模块联动评估.md findings.md progress.md
git commit -m "docs: 完成跨模块联调测试计划"
```

## 八、建议的优先执行用例清单

1. 用户解绑工序但存在 `pending/in_progress` 工单时的可见性与执行拦截
2. 用户角色从 `operator` 切到非生产角色后的生产入口变化
3. 产品参数变更后新老工单首件参数差异
4. 产品版本回滚对在制工单 impact-analysis
5. 工艺模板 `apply_order_sync=true` 发布对在制单的真实影响
6. 工艺模板回滚到旧版本后当前工序不在目标路线中的 blocked reason
7. 首件失败后的质量处置流
8. 返修 complete 时纯报废场景
9. 返修 complete 时回流到目标工序场景
10. 代班创建 -> 取消 -> helper 执行失败场景
11. 中途换人后继续报工场景
12. 流水线存在活跃实例时禁用/切换场景

## 九、执行注意事项

- 所有在制状态测试优先新建独立订单，避免串扰历史样本。
- 每个高风险场景都要记录：
  - 请求参数
  - 核心响应
  - 关键数据库事实
  - 对应事件日志
- 遇到“接口返回与数据库事实不一致”时，优先保留现场订单和 run_id，不要立即清理。
- `apply_order_sync=true` 场景要特别注意区分：
  - impact-analysis 的预览结果
  - publish/rollback 的实际订单变更结果
  - 事件日志是否存在

## 十、计划自检

- 已覆盖用户、产品、工艺、质量、生产 5 个模块的剩余高风险联动缺口。
- 已区分主链、变更流、异常流三类测试目标。
- 已给出前置、数据策略、执行顺序、出口条件。
- 已尽量复用当前项目已有账号、稳定样本、现有测试资产与留痕路径。

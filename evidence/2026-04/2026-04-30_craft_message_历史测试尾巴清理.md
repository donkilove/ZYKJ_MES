# 任务日志：craft_kanban 与 message_center 历史测试尾巴清理

- 日期：2026-04-30
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：直接分两批提交，然后单开一轮清 `craft_kanban` 和 `message_center` 的历史测试尾巴

## 1.1 前置说明
- 默认主线工具：`mcp__MCP_DOCKER__.sequentialthinking`、Codex 宿主 shell、`update_plan`、仓库 `evidence/`、`flutter analyze`、`flutter test`
- 缺失工具：按规则可直接派发的子 agent
- 缺失/降级原因：当前开发者约束要求仅在用户显式要求时才可派发 sub-agent
- 替代工具：主 agent 自行做 systematic debugging、最小测试修正与独立命令验证
- 影响范围：无子 agent 验证闭环，改由分阶段命令补偿

## 2. 前置提交结果
| 提交 | 说明 |
| --- | --- |
| `61e869e` | 收口第二批遗留弹窗 |
| `cdcb3d5` | 收口尾巴级弹窗 |

## 3. 根因分析
### 3.1 `craft_kanban_page_test.dart`
- 失败不是业务逻辑问题，而是测试仍断言旧筛选分区文案 `主筛选`
- 当前页面实际使用字段标签型筛选，没有该标题文案

### 3.2 `message_center_page_test.dart`
- 多个失败来自测试与现实现状脱节：
  1. 仍依赖旧 `OutlinedButton / FilledButton` 类型断言
  2. 仍断言旧骨架 `MesDetailPanel`
  3. 有一处直接 `pumpWidget(MessageCenterPage(...))` 未经过已包 `TickerMode` 的测试壳，导致 `pumpAndSettle` 受动画干扰
  4. 局部文案已调整为当前真实显示（如角色名文本间距）

## 4. 实施动作
### 4.1 `craft_kanban_page_test.dart`
- 将旧断言 `主筛选 / 日期范围` 改为当前真实字段断言：
  - `选择产品`
  - `工段筛选`
  - `工序筛选`
  - `开始日期`
  - `结束日期`
- 无产品空态下，改为断言：
  - `选择产品` 不出现
  - `导出数据` 不出现

### 4.2 `message_center_page_test.dart`
- 引入 `MessageCenterPreviewPanel`，移除旧 `MesDetailPanel` 断言
- 给测试壳新增 `refreshTick` 透传，复用统一 `TickerMode(enabled: false)` 包裹
- 将对旧按钮类型的依赖改为当前可稳定定位的 key / 文本交互
- 保留并利用本轮已加的稳定 key：
  - `message-center-mark-all-read-button`
  - `message-center-mark-batch-read-button`
- 对齐当前公告发布角色文本：`系统管理员 (system_admin)`

## 5. 验证留痕
### 5.1 静态检查
```powershell
flutter analyze test/widgets/craft_kanban_page_test.dart test/widgets/message_center_page_test.dart
```
- 结果：通过，`No issues found!`

### 5.2 整文件回归
```powershell
flutter test test/widgets/craft_kanban_page_test.dart -r expanded
flutter test test/widgets/message_center_page_test.dart -r expanded
```
- 结果：
  - `craft_kanban_page_test.dart`：`All tests passed!`
  - `message_center_page_test.dart`：`All tests passed!`

## 6. 最终结论
- 已完成项：
  1. 两批提交已完成
  2. `craft_kanban` 历史测试尾巴已清理
  3. `message_center` 历史测试尾巴已清理
  4. 两份整文件测试已通过
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 7. 迁移说明
- 无迁移，直接替换。

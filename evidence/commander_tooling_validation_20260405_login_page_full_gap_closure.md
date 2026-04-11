# 指挥官工具化验证模板

## 1. 任务基础信息

- 任务名称：登录页及关联功能缺口补齐与最终收口
- 对应主日志：`evidence/commander_execution_20260405_login_page_full_gap_closure.md`
- 执行日期：2026-04-05
- 当前状态：已完成

## 2. 输入基线

- 用户目标：一次性补齐登录页及关联功能缺口。
- 流程基线：`指挥官工作流程.md`
- 工具治理基线：`docs/commander_tooling_governance.md`
- 相关输入路径：
  - `backend/tests/`
  - `frontend/test/`
  - `frontend/integration_test/`（待补）

## 3. 任务分类

| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-02 | CAT-01、CAT-03、CAT-04、CAT-07 | 涉及认证契约、登录页面、前后端联动与 integration_test | G1/G2/G3/G4/G5/G6/G7 |

## 4. 工具触发记录

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | Sequential Thinking | 默认触发 | 明确登录页补缺范围与闭环策略 | 拆解结果与验收边界 | 2026-04-05 |
| 2 | 启动 | TodoWrite | 默认触发 | 维护本轮状态 | 在制项状态 | 2026-04-05 |
| 3 | 启动 | evidence | 默认触发 | 指挥官模式先留痕 | 主日志与工具化日志 | 2026-04-05 |
| 4 | 执行 | Task | 默认触发 | 派发后端、前端、integration_test 执行与复检 | 子 agent 输出与结论 | 2026-04-05 |

## 5. 执行留痕

### 5.1 执行子 agent 操作

| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | Task + Bash + apply_patch | T37 后端认证契约补齐 | 扩充认证/注册契约测试并修复 2 处真实后端问题 | 后端认证定向自测通过 | `task_id=ses_2a19faae0ffeu0whdMgVeQhQw7` |
| 2 | Task + Bash + apply_patch | T38 前端页面测试补齐 | 扩充登录页/注册页/强制改密页/服务测试并修复 1 处真实前端问题 | Flutter 定向自测通过 | `task_id=ses_2a19faad2fferPdJw0e7y5Qa53` |
| 3 | Task + Bash + apply_patch | T39 integration_test 补齐 | 建立 integration_test 基础并落地登录流 4 条用例 | Windows 下 `integration_test` 自测通过 | `task_id=ses_2a19faac3ffeVQ3DwscyEOmG2j` |
| 4 | Task + Bash | T40 综合复测 | 重跑后端、Flutter、integration_test 三条线 | 通过 | `task_id=ses_2a188a250ffe5jnnzmCg0jcVW6` |

## 6. 验证留痕

### 6.1 验证门禁检查

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | LOGIN-E1 | 已归类为登录页补缺任务 |
| G2 | 通过 | 主日志 | 已记录默认触发工具与原因 |
| G3 | 通过 | LOGIN-E2 至 LOGIN-E9 | 已形成执行与独立验证分离 |
| G4 | 通过 | LOGIN-E2 至 LOGIN-E9 | 已完成真实执行与独立终验 |
| G5 | 通过 | 主日志 | 已形成“触发 -> 执行 -> 验证 -> 收口”闭环 |
| G6 | 不适用 | 无 | 当前暂无工具降级 |
| G7 | 通过 | 主日志第 13 节 | 已声明无迁移，直接替换 |

### 6.2 独立验证结果

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| Task + Bash | T37 后端认证契约补齐 | 定向 `pytest` + 最小只读 API 冒烟 | 通过 | `T37 复检通过` |
| Task + Bash | T38 前端页面测试补齐 | `flutter analyze` + 定向 `flutter test` | 通过 | `T38 第二轮复检通过` |
| Task + Bash | T39 integration_test 补齐 | `flutter test -d windows integration_test/login_flow_test.dart` | 通过 | `T39 复检通过` |
| Task + Bash | T41 独立终验 | 再次重跑关键集合并只读核对能力覆盖 | 通过 | `T41 终验通过` |

## 7. 通过判定

- 是否完成“工具触发 -> 执行 -> 验证 -> 重试 -> 收口”闭环：是
- 是否满足主分类门禁：是
- 是否存在残余风险：有，`integration_test` 当前使用假服务替身，仍不覆盖真实后端联调与网络抖动
- 最终判定：通过

## 8. 迁移说明

- 无迁移，直接替换

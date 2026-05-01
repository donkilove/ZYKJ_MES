# 任务日志：后台容量门控扩展

- 日期：2026-04-13
- 执行人：Codex
- 当前状态：进行中
- 指挥模式：单 agent 执行+验证

## 1. 输入来源
- 用户指令：支持场景配置新增 layer 和 sample_contract 字段，扩展单元测试
- 需求基线：用户提供文件范围与字段需求
- 代码范围：tools/perf/write_gate/sample_contract.py、tools/perf/backend_capacity_gate.py、backend/tests/test_backend_capacity_gate_unit.py

## 1.1 前置说明
- 默认主线工具：宿主 shell、文件系统、pytest
- 缺失工具：无
- 缺失/降级原因：无
- 替代工具：无
- 影响范围：无

## 2. 任务目标、范围与非目标
### 任务目标
1. 增加单元测试验证 layer 与 sample_contract.restore_strategy
2. 更新性能容量门控场景配置解析以支持新字段

### 任务范围
1. 编辑上述三文件中的逻辑与测试
2. 关注 backend/tests 中的具体场景输入数据

### 非目标
1. 不触及其他目录，例如 frontend 或 integration_test
2. 不创建新 git commit

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | backend/tests/test_backend_capacity_gate_unit.py | 2026-04-13 | 测试新增 layer + sample_contract 字段 | Codex |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 扩展单元测试 | layer 和 sample_contract 字段可被访问 | Codex | Codex | pytest 后端测试通过 | 进行中 |
| 2 | 更新业务解析逻辑 | 场景配置支持新字段 | Codex | Codex | 运行关联测试通过 | 进行中 |

## 5. 子 agent 输出摘要
- 调研摘要：已读取 AGENTS 规则与用户需求
- 执行摘要：待添加测试与实现
- 验证摘要：待运行 pytest backend/tests/test_backend_capacity_gate_unit.py -k "layer_and_sample_contract" -v

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 无 | 无 | 无 | 无 | 无 | 无 |

## 7. 工具降级、硬阻塞与限制
- 默认主线工具：宿主 shell、文件系统、pytest
- 不可用工具：无
- 降级原因：无
- 替代流程：无
- 影响范围：无
- 补偿措施：无
- 硬阻塞：无

## 8. 交付判断
- 已完成项：日志+计划、读取规则、部分分析
- 未完成项：测试、实现、验证
- 是否满足任务目标：否
- 主 agent 最终结论：进行中

## 9. 迁移说明
- 无迁移，直接替换

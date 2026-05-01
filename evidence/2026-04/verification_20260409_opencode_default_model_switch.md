# 工具化验证日志：OpenCode 默认模型切换

- 执行日期：2026-04-09
- 对应主日志：`evidence/task_log_20260409_opencode_default_model_switch.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | 本地联调与启动 | 需要修改本机 `opencode CLI` 的默认模型与默认变体，并验证桌面端新会话继承效果 | G1、G2、G3、G4、G5、G6、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `Sequential Thinking` | 默认 | 明确目标模型与配置定位策略 | 结构化拆解 | 2026-04-09 |
| 2 | 启动 | `update_plan` | 默认 | 维护步骤与状态 | 计划轨迹 | 2026-04-09 |
| 3 | 调研 | PowerShell | 默认 | 检索本机 `opencode` 配置、帮助输出与桌面状态文件 | 配置落点与会话覆盖关系 | 2026-04-09 |
| 4 | 调研 | 官方 schema / 本地 SDK 类型 | 补充 | 确认默认模型和默认 variant 的合法字段名 | 配置语义证据 | 2026-04-09 |
| 5 | 执行 | `apply_patch` | 默认 | 修改全局默认模型配置 | 配置变更落地 | 2026-04-09 |
| 6 | 验证 | `opencode debug config` / `opencode debug agent` | 默认 | 验证解析结果 | 解析级通过结论 | 2026-04-09 |
| 7 | 验证 | `opencode run` / `opencode export` | 补充 | 验证新会话真实落到目标模型与 variant | 运行级通过结论 | 2026-04-09 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | PowerShell | `opencode --help` / `opencode run --help` / `opencode models openai` | 检查模型参数格式与可选 variant | 确认模型格式为 `provider/model`，variant 需单独指定，且 `openai/gpt-5.4` 支持 `xhigh` | E1 |
| 2 | PowerShell | `opencode debug paths`、`C:\Users\Donki\.config\opencode\opencode.json` | 确认实际全局配置路径 | 配置目录锁定为 `C:\Users\Donki\.config\opencode` | E2 |
| 3 | PowerShell | `C:\Users\Donki\AppData\Roaming\ai.opencode.desktop\*.dat` | 检查桌面端状态文件 | 发现会话级 `workspace:model-selection` 可覆盖既有会话显示 | E3 |
| 4 | `apply_patch` | `C:\Users\Donki\.config\opencode\opencode.json` | 写入默认模型与 agent variant | 已落地 `openai/gpt-5.4` + `xhigh` 默认值 | E4 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已判定为 CAT-05，本机 OpenCode CLI 默认模型配置问题 |
| G2 | 通过 | E1、E2 | 已记录默认触发与补充触发依据 |
| G3 | 通过 | E5 | 未派生子 agent，使用解析级与运行级独立验证作为等效补偿 |
| G4 | 通过 | E5 | 已执行真实命令与新会话运行验证 |
| G5 | 通过 | E1、E2、E3、E4、E5 | 可串起“定位 -> 修改 -> 验证 -> 收口” |
| G6 | 通过 | E5 | 已记录未派生子 agent 的补偿方案与影响 |
| G7 | 通过 | E4 | 已明确“无迁移，直接替换” |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `opencode debug config` | 全局解析配置 | 查看解析后的 `model`、`default_agent`、`agent.build.variant`、`agent.plan.variant` | 通过 | 已正确解析为 `openai/gpt-5.4` 和 `xhigh` |
| `opencode debug agent build` | `build` agent | 查看 `model.providerID`、`model.modelID`、`variant` | 通过 | `build` agent 已解析为 `openai/gpt-5.4` + `xhigh` |
| `opencode debug agent plan` | `plan` agent | 查看 `model.providerID`、`model.modelID`、`variant` | 通过 | `plan` agent 已解析为 `openai/gpt-5.4` + `xhigh` |
| `opencode run --format json "仅回复OK"` | 新建最小会话 | 不显式传入 `--model` 或 `--variant`，直接运行 | 通过 | 新会话成功完成 |
| `opencode export ses_28dee7926ffevVyseV5EzqxlrE` | 新建会话元数据 | 检查 `messages[].info.model` 与 assistant `variant` | 通过 | 新会话实际使用 `providerID=openai`、`modelID=gpt-5.4`、`variant=xhigh` |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 调研 | 初始检查路径偏向 JetBrains 全局模型配置 | 任务对象识别偏差，`OpenCode` 实际指 `opencode CLI` | 切回 `opencode` 配置、schema 与桌面状态文件链路 | `opencode debug config`、`opencode export` | 通过 |

## 6. 降级/阻塞/代记
- 工具降级：未启用子 agent 分离验证，改为单 agent 下的独立命令验证补偿
- 阻塞记录：无
- evidence 代记：否

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 残余风险说明
- 既有 OpenCode 历史会话会继续沿用各自保存的模型选择；如界面仍显示旧值，需要新建会话或重启 OpenCode/JetBrains 插件后再看默认值。

## 9. 迁移说明
- 无迁移，直接替换。

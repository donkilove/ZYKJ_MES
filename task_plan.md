# 本地原生 MCP 安装规划任务计划

## 任务目标
- 为本机整理一套可执行的原生 MCP 安装计划，覆盖 `docker`、`git`、`github`、`sequential thinking`、`playwright`、`openapi`、`memory`、`filesystem`、`fetch`、`postgre`、`context7`、`serena`。
- 明确安装顺序、前置依赖、验证口径、主要难点、降级方案与残余风险。
- 本轮只输出计划，不直接执行安装。
- 新增硬约束：不使用 Docker 作为 MCP 安装承载环境。

## 任务分类
- 主分类：CAT-05 本地接入与启动检查
- 触发依据：用户要求先给出本地安装计划，并体现安装难点与风险

## 阶段计划
| 阶段 | 状态 | 内容 | 验收标准 |
| --- | --- | --- | --- |
| 1 | 已完成 | 读取规则、技能与既有 evidence，确认留痕要求 | 已形成规则边界与降级口径 |
| 2 | 已完成 | 摸底本机 MCP 现状与历史阻塞 | 已确认当前本机客户端 / 历史证据现状 |
| 3 | 进行中 | 输出本地原生安装计划、难点与验证方案 | 形成可执行书面方案 |
| 4 | 待开始 | 收尾留痕并交付用户 | evidence 与进度文件同步完成 |

## 关键约束
- 所有输出使用中文。
- 当前会话未提供 `MCP_DOCKER` 工具入口，必须采用书面拆解与宿主安全命令降级。
- 本轮不执行实际安装，仅做规划与风险评估。
- 用户明确要求：MCP 不安装在 Docker 中。

## 已知风险
| 风险 | 影响 | 当前处理 |
| --- | --- | --- |
| `MCP_DOCKER Sequential Thinking` 不可用 | 无法按规则直接走默认工具链 | 改为书面拆解，并同步写入 `evidence/` |
| `claude` 命令不在 PATH | 无法直接用 Claude CLI 验证 MCP 接入 | 计划中单列客户端安装/修复步骤 |
| 本地原生来源不统一 | 后续升级、排障、迁移会变复杂 | 计划中按 npm / uvx / npx / 可执行文件分类归并 |

## 计划结论摘要
1. 先修“平台层”，再装“工具层”，最后补“认证层”。
2. 分三批推进最稳妥：
   - 第一批：Claude CLI、Node/npm、uv、Git、Python 基础运行时
   - 第二批：`git`、`filesystem`、`fetch`、`memory`、`sequential thinking`
   - 第三批：`github`、`playwright`、`postgre`、`openapi`、`context7`、`serena`
3. 当前最大难点不在安装命令本身，而在：
   - 客户端识别
   - OAuth / Token / 数据库连接串 / 允许目录范围
   - Windows 本地 PATH 与跨工具配置位置不一致

## 迁移说明
- 无迁移，直接替换

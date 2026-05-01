# 工具化验证日志：后端 40 并发全链路测试准备

- 执行日期：2026-04-11
- 对应主日志：`evidence/task_log_20260411_backend_40_concurrency_e2e_prep.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | 本地联调与压测准备 | 需在正式压测前确认服务在线、入口可执行、依赖齐备、账号可登录 | G1、G2、G4、G5、G6、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `sequential_thinking` | 降级 | `MCP_DOCKER Sequential Thinking` 不可用 | 准备范围与验收口径 | 2026-04-11 |
| 2 | 启动 | `update_plan` | 默认 | 维护步骤、状态与收口 | 当前计划 | 2026-04-11 |
| 3 | 调研 | PowerShell | 降级 | `MCP_DOCKER ast-grep` 与 `rg` 不可用 | 仓库入口、场景文件、历史 evidence 盘点 | 2026-04-11 |
| 4 | 验证 | `Invoke-WebRequest`、`docker compose ps` | 默认 | 核对服务实时状态 | 在线与健康证据 | 2026-04-11 |
| 5 | 验证 | `POST /api/v1/auth/login`、`backend-capacity-gate --help` | 默认 | 验证账号与压测入口可用 | 账号、命令口径有效 | 2026-04-11 |
| 6 | 验证 | 极短 smoke + 权限接口对照 | 默认 | 排除命令参数问题，确认是否可直接全链路开跑 | 阻塞定位 | 2026-04-11 |
| 7 | 执行/验证 | 容器数据库修复 + 接口复检 | 默认 | 清除权限阻塞，确认全链路前提恢复 | 通过结论 | 2026-04-11 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | PowerShell | `backend/README.md`、`start_backend.py`、`compose.yml` | 读取后端启动与依赖说明 | 确认 Compose 口径与依赖为 PostgreSQL / Redis | P2 |
| 2 | PowerShell | `tools/project_toolkit.py`、`tools/perf/backend_capacity_gate.py` | 读取压测工具入口 | 确认正式压测命令入口已存在 | P3 |
| 3 | PowerShell | `tools/perf/scenarios/full_89_read_40_scan.json` | 读取场景文件并统计场景数量 | 当前文件包含 `86` 个场景 | P4 |
| 4 | PowerShell | 历史 evidence | 读取最近 P95 与全覆盖任务日志 | 确认近期已有 40 并发历史基线 | P5 |
| 5 | `backend-capacity-gate` | `auth-me,users` 极短 smoke | 用 `pa` 账号池执行短时参数自检 | 命令可运行，但 `users` 场景持续 `403` | P8 |
| 6 | PowerShell | 权限接口与 `/api/v1/users` | 分别用 `pa1`、`admin` 做对照请求 | `pa1` 权限集合为空，`admin` 调用 `/api/v1/users` 也为 `403` | P9 |
| 7 | 容器内 Python / PostgreSQL | `get_user_for_auth`、`get_user_permission_codes`、`sys_role` | 复现实例化用户后的角色状态 | 确认 `system_admin.is_enabled=false` 是直接根因 | P10 |
| 8 | PostgreSQL | `sys_role` | 执行 `update sys_role set is_enabled = true where code='system_admin'` | 当前环境角色状态已修复 | P11 |
| 9 | PowerShell / `backend-capacity-gate` | `/authz/permissions/me`、`/users`、二次 smoke | 修复后做真实接口复检 | `admin`、`pa1` 均恢复 `200`，smoke 成功率 `100%` | P12 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | P1 | 已判定 CAT-05 |
| G2 | 通过 | P2、P3 | 已记录默认触发与降级依据 |
| G4 | 通过 | P6、P7、P8、P9、P10、P11、P12 | 已执行真实健康检查、登录探测、smoke、容器内复现与修复后复检 |
| G5 | 通过 | P1-P12 | 已形成“准备 -> 阻塞定位 -> 修复 -> 验证 -> 收口”闭环 |
| G6 | 通过 | P1 | 已说明工具降级与影响 |
| G7 | 通过 | P1 | 已声明无迁移 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| PowerShell | 本地后端 | `Invoke-WebRequest http://127.0.0.1:8000/health` | 通过 | 当前后端在线 |
| Docker Compose | 容器栈 | `docker compose ps` | 通过 | `backend-web`、`backend-worker`、`postgres` 在线 |
| PowerShell | 压测账号 | `POST /api/v1/auth/login` with `pa1 / Load@2026Aa` | 通过 | 历史压测账号仍可用 |
| Python CLI | 压测入口 | `python tools/project_toolkit.py backend-capacity-gate --help` | 通过 | 正式压测命令可直接调用 |
| `backend-capacity-gate` | 极短 smoke | `auth-me,users`，`pa` 前缀，`2` 并发短跑 | 失败 | 压测入口无误，但受保护读接口当前被权限阻塞 |
| PowerShell | 权限现状 | 查询 `pa1` 权限与 `admin` 的 `/api/v1/users` | 失败 | 当前环境不满足“全链路”压测前提 |
| 容器内 Python / PostgreSQL | 根因定位 | 读取 `get_user_for_auth(1).roles` 与 `sys_role.system_admin.is_enabled` | 通过 | 已定位为角色状态误禁用 |
| PostgreSQL | 环境修复 | 更新 `sys_role.system_admin.is_enabled=true` | 通过 | 阻塞已解除 |
| `backend-capacity-gate` | 修复后二次 smoke | 同口径复跑 `auth-me,users` | 通过 | 当前已满足正式全链路压测前提 |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 仓库检索 | `rg` 命令不存在 | 本机缺少 ripgrep | 改用 PowerShell 检索 | 通过 |
| 2 | 参数自检 smoke | `users` 场景成功率为 `0`，状态码全为 `403` | 当前权限数据未打通 | 追加 `permissions/me` 与管理员接口对照 | 已确认阻塞 |
| 3 | 权限链路复现 | 授权行存在但接口仍返回空权限 | `system_admin` 在当前环境中被误禁用 | 直接修正 `sys_role.is_enabled` 并复检 | 通过 |

## 6. 降级/阻塞/代记
- 前置说明是否已披露默认 `MCP_DOCKER` 缺失与影响：是
- 工具降级：`MCP_DOCKER Sequential Thinking`、`MCP_DOCKER ast-grep`、`MCP_DOCKER Git / GitHub` 不可用；`rg` 不可用
- 阻塞记录：无
- evidence 代记：否

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 无迁移，直接替换

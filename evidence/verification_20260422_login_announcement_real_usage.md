# 工具化验证日志：登录页公告栏真实可用性排查

- 执行日期：2026-04-22
- 对应主日志：`evidence/task_log_20260422_login_announcement_real_usage.md`
- 当前状态：已通过

## 1. 任务分类

| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-03 | CAT-02 | 登录页公告真实可用性涉及 Flutter 页面行为，且可能命中前后端公告契约 | G1、G2、G3、G4、G5、G7 |

## 2. 工具触发记录

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `Sequential Thinking` | 默认 | 拆解公告栏真实可用性的验收标准与执行顺序 | 书面拆解结果 | 2026-04-22 |
| 2 | 启动 | `update_plan` | 默认 | 维护步骤与状态 | 当前计划 | 2026-04-22 |
| 3 | 启动/执行/验证 | 宿主安全命令 | 默认 | 搜索代码、运行测试、联调验证 | 真实排查与验证结果 | 2026-04-22 |

## 3. 执行留痕

| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | `MCP_DOCKER` | 拆解流程 | 执行 `Sequential Thinking` | 已形成验收标准与执行顺序 | 主日志 E1 |
| 2 | 宿主安全命令 | 前后端公告链路 | 搜索登录页、消息服务、后端消息接口 | 已确认原链路仅能静态占位 | 主日志 E2-E3 |
| 3 | 宿主安全命令 | 失败测试 | 执行新增登录页公告回归测试 | 已建立红灯 | 主日志 E4 |
| 4 | 宿主安全命令 | 最小实现 | 修改后端公开公告接口与前端登录页公开加载链路 | 已完成最小修复 | 主日志 E5 |
| 5 | 宿主安全命令 | 自动化验证 | 执行 Flutter、pytest、integration_test、analyze | 自动化验证全部通过 | 主日志 E6-E9 |
| 6 | 宿主安全命令 | 真实接口验证 | 启动本地后端实例，发布并读取全员公告 | 公共接口真实可用 | 主日志 E10 |
| 7 | 宿主安全命令 | 用户当前 Docker 服务 | 读取容器日志、`openapi.json` 并重建 `backend-web`/`backend-worker` | 已修复旧镜像导致的 401 | 主日志 E11-E12 |

## 4. 验证留痕

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已归类 CAT-03/CAT-02 |
| G2 | 通过 | E1 | 已记录工具触发与依据 |
| G3 | 通过 | E1 | 当前会话采用阶段分离补偿 |
| G4 | 通过 | E6-E10 | 已完成真实命令、测试与接口联调验证 |
| G5 | 通过 | E1-E10 | 已形成“触发 -> 排查 -> 红灯 -> 修复 -> 验证 -> 收口”闭环 |
| G7 | 通过 | E10 | 已明确“无迁移，直接替换” |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `flutter test` | 登录页 widget 行为 | `flutter test test/widgets/login_page_test.dart -r expanded` | 通过 | 登录页 13 项用例全部通过 |
| `flutter test` | 消息服务 | `flutter test test/services/message_service_test.dart -r expanded` | 通过 | 公开公告请求与鉴权头校验通过 |
| `pytest` | 后端消息服务 | `python -m pytest backend/tests/test_message_service_unit.py -q` | 通过 | 后端单测 15 项全部通过 |
| `flutter test -d windows` | 登录入口集成行为 | `flutter test integration_test/login_flow_test.dart -d windows --plain-name "登录页未登录时可展示全员公告" -r expanded` | 通过 | 集成测试通过 |
| `flutter analyze` | 前端变更文件 | `flutter analyze ...` | 通过 | 无静态问题 |
| 本地 `uvicorn` 联调 | 公开公告接口 | 发布全员公告后读取 `/api/v1/messages/public-announcements` | 通过 | 返回结果包含本轮验证公告标题 |
| Docker `backend-web` | 用户实际使用的 8000 接口 | 重建前检查 `openapi.json` 与容器日志；重建后再次检查 `/api/v1/messages/public-announcements` | 通过 | 已从旧镜像切到新代码，接口返回 200 |

## 5. 失败重试

| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 现状排查 | 登录页公告只能显示静态文案 | 前端请求依赖登录态，后端缺少公开公告接口 | 新增公开公告接口与登录页未登录加载链路 | `flutter test`、`pytest`、真实联调 | 通过 |
| 2 | 测试执行 | widget test 真实 HTTP 被 Flutter 测试环境拦截 | 不是业务故障，是测试宿主网络限制 | 为登录页增加 `publicAnnouncementLoader` 注入点 | widget / integration test | 通过 |
| 3 | `integration_test` 执行 | 首次运行提示多设备，要求显式指定设备 | 工具层设备选择约束 | 改为 `-d windows` 固定设备执行 | `flutter test -d windows` | 通过 |
| 4 | 用户在线复测 | 页面仍显示“静态公告” | 用户正在使用的 `backend-web` 容器未重建到新代码，公开公告请求实际返回 401 | 重建 Docker `backend-web` 与 `backend-worker` | `openapi.json`、接口抽检、容器日志 | 通过 |

## 6. 降级/阻塞/代记

- 前置说明是否已披露默认工具缺失与影响：是
- 工具降级：无
- 阻塞记录：无
- evidence 代记：无

## 7. 通过判定

- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有，历史全员公告内容若不适合登录前公开，或当前测试公告标题不符合业务口径，需要业务自行清理/重发
- 最终判定：通过

## 8. 迁移说明

- 无迁移，直接替换

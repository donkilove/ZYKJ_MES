# 任务日志：不明确的异常子句修复

- 日期：2026-04-09
- 执行人：OpenCode 主 agent
- 当前状态：已完成
- 指挥模式：主 agent 直接修复并使用 PyCharm 检查收口

## 1. 输入来源
- 用户指令：修不明确的异常子句。
- 需求基线：后端 Python 文件与 `tools/perf/backend_capacity_gate.py`
- 代码范围：`backend/app/`、`tools/perf/`、`evidence/`

## 2. 任务目标、范围与非目标
### 任务目标
1. 将当前项目检查中命中的 `except Exception` 收紧为可从上下文明确判断的异常类型。
2. 保持原有业务语义与降级策略不变。

### 任务范围
1. 鉴权 token 解码类场景改为 `ValueError`。
2. Redis/httpx/WebSocket/SQLAlchemy 等基础设施类场景改为明确异常集合。
3. 事务回滚与后台循环类场景改为数据库或运行时异常集合。

### 非目标
1. 不处理非“异常子句过于宽泛”的其他 Python 告警。
2. 不调整业务成功/失败语义。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `auth.py`、`me.py`、`messages.py`、`api/deps.py` | 2026-04-09 23:50:56 | token 解码与 session 提取场景已收紧为 `ValueError` | OpenCode |
| E2 | `authz_service.py`、`backend_capacity_gate.py`、`message_connection_manager.py` | 2026-04-09 23:50:56 | Redis/httpx/WebSocket 相关宽泛异常已收紧为基础设施异常类型 | OpenCode |
| E3 | `products.py`、`craft.py`、`maintenance_scheduler_service.py`、`message_service.py` | 2026-04-09 23:50:56 | 消息通知与维护循环相关宽泛异常已收紧为 `ValueError`、`SQLAlchemyError`、`RuntimeError` 等组合 | OpenCode |
| E4 | `quality.py`、`session_service.py`、`user_export_task_service.py`、`startup_bootstrap.py` | 2026-04-09 23:50:56 | 事务/启动/清理类宽泛异常已收紧为数据库、启动链路与驱动相关异常 | OpenCode |
| E5 | PyCharm 文件检查结果 | 2026-04-09 23:50:56 | 本轮目标文件中“不明确的异常子句”告警已清零 | OpenCode |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 定位宽泛异常 | 确认命中的 `except Exception` 上下文 | 主 agent | 主 agent | 每处异常块都拿到上下文证据 | 已完成 |
| 2 | 收紧异常类型 | 用最小变更替换为明确异常集合 | 主 agent | 主 agent | 目标文件不再出现该类告警 | 已完成 |
| 3 | IDE 复核 | 确认目标文件的宽泛异常告警清零 | 主 agent | 主 agent | PyCharm 文件检查不再报该问题 | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：无。
- 执行摘要：对鉴权、消息推送、Redis 缓存、后台维护、清理节流、启动 bootstrap、容量门禁等场景的 `except Exception` 改为 `ValueError`、`SQLAlchemyError`、`RedisError`、`OSError`、`httpx.HTTPError`、`RuntimeError`、`WebSocketDisconnect`、`psycopg2.Error`、`CommandError` 等明确异常。
- 验证摘要：PyCharm 对目标文件的“不明确的异常子句”告警已不再出现。

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 精确 patch | 首次跨文件 patch 有一处上下文未命中 | 个别文件导入区实际文本与预期不完全一致 | 分批读取文件头部后重新精确 patch | 已通过 |

## 7. 工具降级、硬阻塞与限制
- 不可用工具：无。
- 降级原因：无。
- 替代流程：无。
- 影响范围：无。
- 补偿措施：无。
- 硬阻塞：无。

## 8. 交付判断
- 已完成项：宽泛异常定位、异常类型收紧、PyCharm 复检、evidence 留痕。
- 未完成项：无。
- 是否满足任务目标：是。
- 主 agent 最终结论：可交付。

## 9. 迁移说明
- 无迁移，直接替换。

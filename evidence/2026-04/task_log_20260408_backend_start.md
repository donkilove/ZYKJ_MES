# 任务日志：后端启动

- 日期：2026-04-08
- 执行人：Codex
- 当前状态：已完成
- 任务目标：启动项目后端，并确认本地健康检查可访问。

## 输入来源

- 用户指令：启动项目后端。
- 启动入口：
  - `start_backend.py`
  - `backend/app/main.py`

## 关键过程

1. 确认仓库存在标准启动脚本 `start_backend.py`，后端入口为 `app.main:app`。
2. 首次后台启动失败，日志显示 Alembic 在执行 `y7z8a9b0c1d2_add_user_export_task_table.py` 时因 `sys_user_export_task` 已存在而报 `DuplicateTable`。
3. 只读核对数据库：
   - `sys_user_export_task` 表已存在。
   - 该表所需索引与约束已存在。
   - `c5d6e7f8a9b0`、`g7b8c9d0e1f2`、`x1y2z3a4b5c6` 分支对应的结构已在数据库中。
   - `alembic_version` 仍停留在 `x1y2z3a4b5c6`，未对齐到当前 head `y7z8a9b0c1d2`。
4. 执行 `alembic stamp y7z8a9b0c1d2` 修复迁移版本记录。
5. 清理占用 8000 端口但未提供服务的旧 `uvicorn` 进程后，重新启动后端。
6. 通过 `http://127.0.0.1:8000/health` 验证服务可用，返回 `{"status":"ok"}`。

## 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `start_backend.py` 内容 | 2026-04-08 20:59 | 仓库存在标准后端启动脚本 | Codex |
| E2 | 首次启动错误日志 | 2026-04-08 21:00 | 启动失败原因为 Alembic 迁移 `DuplicateTable` | Codex |
| E3 | PostgreSQL 只读核对 | 2026-04-08 21:03 | 数据库结构已包含目标迁移内容，但版本记录落后 | Codex |
| E4 | `alembic stamp y7z8a9b0c1d2` 输出 | 2026-04-08 21:05 | 迁移版本已对齐到当前 head | Codex |
| E5 | `/health` 响应 `{\"status\":\"ok\"}` | 2026-04-08 21:08 | 后端已成功启动并可访问 | Codex |

## 执行命令摘要

- 读取启动脚本：`Get-Content .\start_backend.py`
- 首次后台启动：`python start_backend.py --no-reload`
- 只读数据库核对：
  - `select version_num from alembic_version`
  - `select table_name from information_schema.tables where table_name='sys_user_export_task'`
  - 相关列、索引、约束查询
- 修复迁移版本：`python -m alembic stamp y7z8a9b0c1d2`
- 最终启动：`python -m uvicorn app.main:app --host 0.0.0.0 --port 8000`
- 健康检查：`Invoke-WebRequest http://127.0.0.1:8000/health`

## 结果

- 后端当前监听端口：`8000`
- 健康检查结果：通过
- 当前监听进程：`python.exe`（PID 17108）
- 启动日志位置：
  - `.tmp_runtime/backend.stdout.log`
  - `.tmp_runtime/backend.stderr.log`

## 风险与说明

- 本轮未修改业务代码，仅修复了 Alembic 版本记录，使其与数据库现状一致。
- 数据库中原先存在“结构已在库中，但 Alembic 版本未前进”的状态，后续若新增迁移，建议留意是否还存在类似手工变更或半迁移痕迹。

## 迁移说明

- 无迁移，直接替换。

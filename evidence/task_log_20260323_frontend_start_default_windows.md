# 任务日志：前端启动脚本默认平台切回 Windows（2026-03-23）

## 1. 任务信息

- 任务名称：前端启动脚本默认平台切回 Windows
- 执行日期：2026-03-23
- 当前状态：已完成

## 2. 输入来源

- 用户指令：将启动前端的脚本默认平台改为 Windows 平台应用。

## 3. 改动范围

- `start_frontend.py`
- `backend/README.md`

## 4. 处理结果

- 将 `start_frontend.py` 中 `--device` 默认值从 `chrome` 改为 `windows`。
- 同步更新帮助文案，避免启动帮助与真实默认行为不一致。
- 在 `backend/README.md` 补充说明：`start_frontend.py` 默认以 Windows 桌面应用方式启动，可通过 `--device` 覆盖。

## 5. 验证

- 已执行：`python start_frontend.py --help`
- 结果：帮助信息中 `--device` 默认值已显示为 `windows`。

## 6. 迁移说明

- 无迁移，直接替换。

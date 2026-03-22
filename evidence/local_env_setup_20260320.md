# 本地环境配置任务日志

## 1. 任务信息

- 任务名称：安装 Python 3.12.10、Flutter SDK，并配置 `ZYKJ_MES` 项目依赖
- 执行日期：2026-03-20
- 执行方式：当前 Linux 用户空间内安装，尽量不依赖 sudo
- 当前状态：已完成

## 2. 输入来源

- 用户指令：为系统安装 `python3.12.10` 和 Flutter SDK，并配置好项目所需依赖。
- 代码来源：仓库 `backend/`、`frontend/`、根目录启动脚本与现有配置文件。

## 3. 已确认约束

- 当前环境为 Linux，`sudo` 需要密码，不能假定具备管理员权限。
- 仓库后端依赖 PostgreSQL，本地当前未发现 `psql`、`pg_isready` 或容器运行时。
- 前端 `frontend/pubspec.lock` 要求 `flutter >=3.38.0`，项目目录当前仅包含 `windows/` 桌面目标。
- 后端 `backend/requirements.txt` 依赖 FastAPI、SQLAlchemy、Alembic、psycopg2 等 Python 包。

## 4. 计划动作

- 在用户目录安装可用的 Python 3.12.10 工具链。
- 为仓库创建 `.venv` 并安装后端依赖。
- 在用户目录安装 Flutter SDK 并加入 PATH。
- 执行 `flutter pub get`、`flutter doctor` 等基础校验。
- 记录 PostgreSQL 与桌面运行目标的剩余约束。

## 5. 实际执行记录

- 已通过 `uv` 在 `/home/donki/.local/share/uv/python/` 安装 `Python 3.12.10`，并在 `/home/donki/.local/bin/python3.12.10` 暴露命令入口。
- 已在仓库根目录创建 `.venv`，并安装 `backend/requirements.txt` 所需依赖。
- 已额外向 `.venv` 安装 `pip`、`setuptools`、`wheel`，避免后续标准 `pip` 命令不可用。
- 已创建 `.venv/Scripts/python.exe -> .venv/bin/python` 软链接，保证根目录 `start_backend.py` 在当前 Linux 环境下也能识别仓库虚拟环境。
- 已在 `/home/donki/.local/share/flutter` 安装 `Flutter 3.41.5`，满足 `frontend/pubspec.lock` 中 `flutter >=3.38.0` 的要求。
- 已更新 `/home/donki/.bashrc`，为交互 shell 注入 `~/.local/bin` 与 `~/.local/share/flutter/bin` 到 `PATH`。

## 6. 验证结果

- `python3.12.10 --version` => `Python 3.12.10`
- `.venv/bin/python -m pip check` => `No broken requirements found.`
- 后端关键依赖导入校验通过：`fastapi`、`sqlalchemy`、`psycopg2`、`alembic`、`httpx`、`openpyxl`
- `flutter --version` => `Flutter 3.41.5` / `Dart 3.11.3`
- `flutter pub get` 执行成功，前端依赖已拉取
- `flutter analyze` 可执行，但存在 3 条既有信息级提示：
  - `frontend/lib/pages/registration_approval_page.dart:341`
  - `frontend/lib/pages/user_management_page.dart:323`
  - `frontend/lib/pages/user_management_page.dart:577`
- `python3 start_backend.py --help` 与 `python3 start_frontend.py --help` 均可正常执行，说明启动脚本已能识别当前基础环境

## 7. 剩余约束与风险

- 本机当前未发现 `psql`、`pg_isready`、Docker、Podman；仓库后端默认依赖本地 PostgreSQL，且启动会触发建库、迁移、seed，因此本次未直接执行后端启动。
- `flutter doctor -v` 显示当前主机缺少 Android SDK、Chrome，以及 Linux 桌面构建所需 `clang++`、`cmake`、`ninja`、`pkg-config`；这些属于宿主机开发工具链，不影响 `flutter pub get` 与静态检查，但会影响对应平台运行/构建。
- 仓库前端当前仅包含 `windows/` 目录，而当前主机仅检测到 `Linux` 设备；因此 `start_frontend.py` 的默认 `--device windows` 在本机不能直接运行，需要 Windows 主机或后续补 Linux 平台支持。

## 8. 当前状态

- 当前状态：已完成
- 迁移说明：无迁移，直接完成本地开发工具链与项目依赖配置。

## 9. 后续补充：PostgreSQL 与 Flutter Linux 桌面工具链

- 执行日期：2026-03-20（同日追加）
- 由于当前账号无 `sudo` 密码，本次继续采用用户目录安装方案，而非系统级 `apt install`。
- 已安装 `micromamba 2.5.0` 到 `/home/donki/.local/bin/micromamba`。
- 已创建开发环境 `/home/donki/.local/share/micromamba/envs/zykj-dev`，并安装：`postgresql 16.13`、`clang 18.1.8`、`clangxx 18.1.8`、`cmake 4.3.0`、`ninja 1.13.2`、`pkg-config 0.29.2`、`gtk3 3.24.51` 及其所需 `freetype`、`zlib`、`expat` 元数据包。
- 已更新 `/home/donki/.bashrc`，为新 shell 注入 `zykj-dev` 环境的 `PATH`、`LD_LIBRARY_PATH`、`PKG_CONFIG_PATH`、`CMAKE_PREFIX_PATH` 与 `PGDATA`。
- 已初始化 PostgreSQL 数据目录：`/home/donki/.local/share/postgresql/16/data`。
- 已启动 PostgreSQL 16，本地日志文件为 `/home/donki/.local/state/postgresql/postgresql-16.log`。
- 已按 `backend/.env` 的现有连接约束准备好 bootstrap 超级用户与应用角色，且已删除临时密码文件，避免明文残留。

## 10. 补充验证结果

- `pg_isready -h 127.0.0.1 -p 5432` => `accepting connections`
- `psql` 已验证 bootstrap 用户可登录 `postgres` 数据库，应用角色也可通过 TCP 登录
- `flutter doctor -v` 现已通过 `Linux toolchain - develop for Linux desktop`
- 当前 `flutter doctor -v` 仍保留 2 类非本次目标问题：
  - Android SDK 未安装
  - Chrome 未安装
- `eglinfo` 缺失仅表现为 Linux toolchain 下的提示信息，不再阻塞桌面工具链判定通过

## 11. 运行说明

- 新开终端后可直接使用 `pg_ctl`、`psql`、`pg_isready`、`clang++`、`cmake`、`ninja`、`pkg-config`。
- 若需在当前终端立即生效，执行：`source ~/.bashrc`
- PostgreSQL 数据目录：`$PGDATA`
- PostgreSQL 默认监听：`127.0.0.1:5432`

## 12. 后续补充：PostgreSQL 16 切换到 18

- 执行日期：2026-03-20（同日追加）
- 切换原因：为对齐用户 Windows 本地环境，将 PostgreSQL 主版本从 `16` 切换到 `18`。
- 已停止 PostgreSQL 16 进程，并将 `zykj-dev` 环境中的 `postgresql` / `libpq` 升级到 `18.3`。
- 已新建 PostgreSQL 18 数据目录：`/home/donki/.local/share/postgresql/18/data`。
- 已保留 PostgreSQL 16 数据目录：`/home/donki/.local/share/postgresql/16/data`，作为本地备份，不做物理目录混用。
- 已将 `/home/donki/.bashrc` 中的 `PGDATA` 更新为 PostgreSQL 18 路径。
- 已重新初始化 PostgreSQL 18 集群，并恢复项目所需角色：`postgres`（bootstrap 超级用户）、`mes_user`（应用用户）。

## 13. 切换后验证结果

- `postgres --version` => `PostgreSQL 18.3`
- `psql --version` => `PostgreSQL 18.3`
- `pg_ctl -D /home/donki/.local/share/postgresql/18/data status` => 运行中
- `pg_ctl -D /home/donki/.local/share/postgresql/16/data status` => 已停止
- `pg_isready -h 127.0.0.1 -p 5432` => `accepting connections`
- `SELECT current_setting('data_directory')` => `/home/donki/.local/share/postgresql/18/data`

## 14. 迁移说明

- 无迁移，直接替换当前运行版本。
- 保留 PostgreSQL 16 本地数据目录作为回退参考，但当前活动实例仅使用 PostgreSQL 18 数据目录。

## 15. 后续补充：移除 Linux 桌面工具链并评估 Web 方案

- 执行日期：2026-03-20（同日追加）
- 已将 PostgreSQL 从原 `zykj-dev` 混合环境中拆分到独立环境：`/home/donki/.local/share/micromamba/envs/zykj-postgres`。
- 已删除旧的 `zykj-dev` 环境，从而实际移除 `clang++`、`cmake`、`ninja`、`pkg-config`、`gtk3` 等 Linux 桌面工具链与相关依赖。
- 已更新 `/home/donki/.bashrc`，当前仅暴露 PostgreSQL 运行环境，不再暴露 Linux 桌面编译工具链。
- 已执行 `flutter config --enable-web`，为后续 Web 端准备全局 Flutter 开关。

## 16. Web 端现状判断

- 当前 `frontend/` 目录仅包含 `windows/` 平台目录，不包含 `web/` 平台目录。
- 当前 `flutter devices` 未出现 `chrome`、`web-server` 或 Firefox 设备，因此现阶段不能直接把该项目当成已就绪的 Flutter Web 项目运行。
- 系统中已存在 Firefox：`Mozilla Firefox 148.0.2`。
- Firefox 可作为最终访问浏览器使用，但 Flutter CLI 不把 Firefox 作为标准调试设备；更稳妥的链路是补齐 `web/` 平台后使用 `web-server` 或 `chrome` 启动，再在 Firefox 中访问页面做兼容性验证。

## 17. 后续补充：安装 Chrome 作为 Flutter Web 调试浏览器

- 执行日期：2026-03-20（同日追加）
- 已在用户目录安装 `Google Chrome for Testing 146.0.7680.153` 到 `/home/donki/.local/share/chrome/chrome-linux64/`。
- 已创建命令入口：`/home/donki/.local/bin/google-chrome` 与 `/home/donki/.local/bin/google-chrome-stable`。
- 当前无需额外设置 `CHROME_EXECUTABLE`，因为 Flutter 已可通过 `google-chrome` 直接识别浏览器。

## 18. Chrome 安装后验证结果

- `google-chrome --version` => `Google Chrome for Testing 146.0.7680.153`
- `flutter doctor -v` 已通过 `Chrome - develop for the web`
- `flutter devices` 当前可见：`chrome`（Web）与 `linux`（桌面）
- Linux 桌面工具链仍保持移除状态，未被重新引入

## 19. 现阶段建议

- 当前已经具备 Flutter Web 的 Chrome 调试浏览器，但项目目录仍未补齐 `frontend/web/` 平台文件。
- 若要真正以 Web 方式运行并获得热重载调试体验，下一步应为该项目补 Web 平台，并把启动脚本从默认 `windows` 设备扩展为支持 `chrome`。

## 20. 后续补充：实际启动后端与前端

- 执行日期：2026-03-20（同日追加）
- 已通过根目录脚本 `start_backend.py` 在后台启动后端，运行参数：`--host 127.0.0.1 --port 8000 --no-reload`。
- 后端日志文件：`/home/donki/.local/state/zykj_mes/backend.log`
- 后端健康检查：`http://127.0.0.1:8000/health` 返回 `200` 与 `{"status":"ok"}`。
- 为适配当前 Linux 的 Chrome 沙箱限制，按用户确认额外创建了包装命令：`/home/donki/.local/bin/google-chrome-no-sandbox`。
- 已通过 `flutter create --platforms=web .` 为 `frontend/` 补齐 Web 平台文件后，再以 `chrome` 设备启动前端。
- 前端启动命令实际使用 `CHROME_EXECUTABLE=/home/donki/.local/bin/google-chrome-no-sandbox`，并通过根目录脚本 `start_frontend.py` 在后台启动。
- 前端日志文件：`/home/donki/.local/state/zykj_mes/frontend_chrome.log`

## 21. 启动后验证结果

- 后端访问地址：`http://127.0.0.1:8000`
- 前端页面当前监听地址：`http://127.0.0.1:33961`
- Flutter Debug Service：`ws://127.0.0.1:46753/jpR0P2XKEew=/ws`
- Dart VM Service：`http://127.0.0.1:46753/jpR0P2XKEew=`
- 后端日志已出现来自前端页面的接口访问：`GET /api/v1/auth/accounts` 返回 `200`，说明页面已实际连通后端。

## 22. 风险说明

- 当前 Chrome 调试链路依赖 `--no-sandbox` 包装命令，仅建议用于本机开发调试。
- 本次为满足 Web 启动，自动补齐了 `frontend/web/` 及 Flutter 生成的相关项目文件；这属于仓库工作区变更，尚未提交。

## 23. 后续补充：停止前后端并调整前端默认设备

- 执行日期：2026-03-20（同日追加）
- 已按要求停止后端与前端运行进程；当前 `127.0.0.1:8000` 与前端临时 Web 端口均已关闭。
- PostgreSQL 未停止，仍保持 `127.0.0.1:5432` 运行，避免影响后续后端再次启动。
- 已将 `start_frontend.py` 中 `--device` 的默认值从 `windows` 改为 `chrome`，帮助信息也同步更新。

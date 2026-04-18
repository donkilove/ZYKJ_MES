# 后端启动脚本 Docker 编排控制器设计

## 1. 背景

当前仓库已经具备一套可运行的后端容器编排基础：

1. 根 `compose.yml` 已提供：
   - `backend-web`
   - `backend-worker`
   - `postgres`
   - `redis`
2. 根 `Dockerfile` 已提供后端运行镜像。
3. 但当前根 `start_backend.py` 仍然是本地 Python 进程启动器，负责：
   - 本地 `.venv` Python 定位
   - 本地 `uvicorn` / `gunicorn` 进程组装
   - 本地 PostgreSQL 可用性检查与自动拉起

这使项目同时存在两套后端启动思路：

1. 本地 Python 直跑
2. Docker Compose 编排运行

用户已明确确认后续后端将长期通过 Docker 提供服务，因此本轮目标是把根 `start_backend.py` 彻底转为 Docker 编排控制器，并同步收紧数据库/缓存的宿主暴露边界。

## 2. 目标与非目标

### 2.1 目标

1. 将 `start_backend.py` 默认完全切换为 Docker 编排入口。
2. 直接改造根 `compose.yml`，不新增新的后端编排文件。
3. 默认拉起完整后端形态：
   - `backend-web`
   - `backend-worker`
   - `postgres`
   - `redis`
4. 默认采用“后台启动 + 自动打印状态摘要 + 单独参数查看日志”的交互模式。
5. 默认让 PostgreSQL 与 Redis 仅在容器内网络可见，不向宿主暴露。
6. 允许通过显式参数临时开放数据库给宿主机数据库管理软件使用。

### 2.2 非目标

1. 不保留当前本地 `.venv + uvicorn/gunicorn + 本地 PostgreSQL` 作为默认主线。
2. 不把 `start_frontend.py` 改成 Docker 编排脚本。
3. 不为本轮新增第二套 `compose.*.yml` 后端编排文件。
4. 不把 Redis 作为数据库管理软件临时接入目标。

## 3. 方案对比

### 方案 A：`start_backend.py` 改为 Docker 编排控制器，直接驱动根 `compose.yml`

- 优点：
  - 启动入口统一。
  - 文档、脚本、实际运行形态一致。
  - 后续部署与本地运行思路统一。
- 缺点：
  - 属于破坏性切换，需要放弃本地 Python 启动主线。

### 方案 B：在 `start_backend.py` 中保留旧本地模式，同时新增 Docker 为默认模式

- 优点：
  - 表面上兼容旧工作流。
- 缺点：
  - 脚本长期维护两套启动模型，边界会继续分叉。
  - 与“默认完全切 Docker”目标冲突。

### 方案 C：只改 `compose.yml`，让 `start_backend.py` 做极薄的 `docker compose` 透传

- 优点：
  - 脚本改动较少。
- 缺点：
  - 启动摘要、健康等待、日志提示、错误诊断都较弱。
  - 用户体验不足，后续大概率仍需补脚本能力。

### 结论

采用方案 A。

## 4. 设计

### 4.1 总体架构

本轮改造后：

1. `start_backend.py` 不再是“本地进程启动器”。
2. `start_backend.py` 成为唯一的后端 Docker 编排控制器。
3. 根 `compose.yml` 成为唯一后端编排源。
4. `backend/README.md` 切换为 Docker 启动主线文档。

职责切分如下：

- `start_backend.py`
  - 参数解析
  - Docker / Docker Compose 可用性检查
  - `build/up/down/restart/logs/ps` 等命令编排
  - 健康等待与状态摘要输出
  - 临时数据库暴露参数转换
- `compose.yml`
  - 定义服务、环境变量、卷、网络、健康检查和端口暴露
- `Dockerfile`
  - 定义后端运行镜像
- `backend/README.md`
  - 提供统一的后端启动说明

### 4.2 `start_backend.py` 命令形态

#### 默认行为

执行：

```powershell
python start_backend.py
```

默认流程为：

1. 检查 `docker` 与 `docker compose` 是否可用
2. 执行镜像构建
3. 后台拉起完整后端服务集合
4. 等待 `postgres`、`redis` 健康
5. 等待 `backend-web` 可用
6. 输出状态摘要并返回命令行

#### 建议命令集合

脚本统一采用“默认命令 + 显式子动作”模型：

1. 默认 / `up`
   - 构建并后台启动
2. `logs`
   - 查看日志
3. `ps`
   - 查看服务状态摘要
4. `down`
   - 停止并移除容器
5. `restart`
   - 重启完整服务集合
6. `rebuild`
   - 强制重新构建并启动

#### 推荐交互细节

- `logs` 默认查看：
  - `backend-web`
  - `backend-worker`
- 支持仅查看单个服务日志
- 默认成功摘要至少输出：
  - 当前服务状态
  - 后端访问地址
  - 数据库/Redis 默认仅容器内可见的说明
  - 下一步常用命令提示

### 4.3 服务集合

默认拉起的服务固定为：

1. `backend-web`
2. `backend-worker`
3. `postgres`
4. `redis`

原因：

1. 用户已确认后端将长期以 Docker 形态提供服务。
2. 只拉 `backend-web` 会导致后台循环、投递和维护逻辑长期处于非真实运行形态。
3. 从现在开始按完整后端形态运行，更符合后续部署现实。

### 4.4 `compose.yml` 暴露边界

#### `backend-web`

- 保留宿主端口映射。
- 作为唯一默认对宿主暴露的后端服务。

#### `backend-worker`

- 不暴露宿主端口。
- 仅承担后台工作，不提供宿主访问入口。

#### `postgres`

- 默认删除 `ports`。
- 只允许 Docker 内部网络访问。
- 默认不允许宿主机直接通过 `127.0.0.1:5432` 等端口连接。

#### `redis`

- 不暴露宿主端口。
- 只允许 Docker 内部网络访问。

#### 容器内服务发现

后端容器统一通过服务名访问依赖：

- `DB_HOST=postgres`
- `REDIS_HOST=redis`

这样可以让本地与未来部署的 Docker 运行模型保持一致。

### 4.5 临时数据库管理软件接入

用户已明确提出：虽然数据库默认不向宿主暴露，但仍需要保留“临时使用数据库管理软件管理数据库”的入口。

#### 设计原则

1. 默认不暴露 PostgreSQL。
2. 只通过显式参数开启临时宿主映射。
3. 映射范围仅限 PostgreSQL，不扩展到 Redis。
4. 优先映射到 `127.0.0.1` 回环地址，而不是所有网卡。

#### 推荐交互

例如：

```powershell
python start_backend.py --expose-db --db-port 5433
```

该模式下：

1. PostgreSQL 临时对宿主开放 `127.0.0.1:5433 -> 5432`
2. Redis 仍保持仅容器内可见
3. 摘要中明确提示这是“临时数据库管理模式”

#### 推荐实现方式

不把 PostgreSQL 的宿主端口写死在 `compose.yml` 默认配置里，而由 `start_backend.py` 在显式参数触发时为 `docker compose` 注入临时端口变量。

### 4.6 错误处理与提示

脚本需要从“本地进程错误提示”转为“Docker 编排错误提示”：

1. 未安装 Docker / Docker Compose
   - 明确提示先安装 Docker Desktop
2. `build` 失败
   - 明确提示镜像构建失败
3. `up -d` 失败
   - 提示使用 `python start_backend.py logs`
4. 健康检查超时
   - 指明失败服务
   - 输出建议排查命令

### 4.7 文档与 `start_frontend.py` 联动

#### `backend/README.md`

需要切换为 Docker 启动主线：

1. 默认启动命令改为：

```powershell
python start_backend.py
```

2. 本地 `.venv + uvicorn` 只能作为补充或历史说明，不再作为默认主线。

#### `start_frontend.py`

本轮只做最小联动：

1. 不改为 Docker 脚本
2. 不承担后端编排职责
3. 只在文档或提示口径上与新的后端入口对齐

也就是说：

- 启后端：`python start_backend.py`
- 启前端：`python start_frontend.py`

### 4.8 迁移口径

本轮属于破坏性切换：

1. 后端默认启动方式从本地 Python 直跑切换到 Docker
2. PostgreSQL / Redis 默认不再对宿主暴露
3. 宿主机临时进库排查改为：
   - 显式开启 `--expose-db`
   - 或使用 `docker compose exec postgres ...`

统一迁移说明：

- 无迁移，直接替换

## 5. 验证策略

### 5.1 脚本验证

至少验证：

1. 默认 `up` 路径
2. `logs`
3. `ps`
4. `down`
5. `restart`
6. `rebuild`
7. `--expose-db`

### 5.2 Compose 边界验证

至少验证：

1. 默认模式下 `postgres` 无宿主端口映射
2. 默认模式下 `redis` 无宿主端口映射
3. `backend-web` 仍有宿主访问入口

### 5.3 运行态验证

至少验证：

1. `python start_backend.py` 后四个服务均拉起
2. `postgres`、`redis` 健康通过
3. `backend-web` 可访问
4. `python start_backend.py down` 后服务正确停止

### 5.4 临时数据库管理验证

至少验证：

1. 默认启动模式下宿主机无法直接连 PostgreSQL
2. `--expose-db --db-port 5433` 模式下 PostgreSQL 可通过 `127.0.0.1:5433` 访问
3. Redis 在任何模式下均不向宿主暴露

## 6. 风险

1. 这是一次明确的默认行为切换，依赖旧本地启动方式的习惯会被打断。
2. 若团队仍有人长期依赖宿主机直连 PostgreSQL，需要转为显式临时暴露或 `docker compose exec`。
3. `start_backend.py` 逻辑会显著从“进程脚本”转为“编排脚本”，需要配套补齐测试和错误提示。

# Graphify 知识图谱重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 全量重建 ZYKJ_MES 的 Graphify 知识图谱，通过项目记忆标注提升核心模块精度

**架构：** 三阶段流水线 — 摸底重建建立基线 → 编写 7 份 project-memory 标注核心关系 → 最终重建并验证

**技术栈：** Graphify 0.5.6 (AST 提取 + project-memory 语义增强), Python 3.12 venv

---

## Phase 1: 摸底重建

### Task 1: 清理缓存并全量重建

**操作：**
- 删除: `graphify-out/cache/` 全部内容
- 运行: `graphify update .`

- [ ] **Step 1: 确认 graphify 环境可用**

```bash
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify --help
```

预期：打印 help 内容，确认 `update` 子命令存在。

- [ ] **Step 2: 清空缓存目录**

```bash
Remove-Item -Recurse -Force "C:\Users\Donki\Desktop\ZYKJ_MES\graphify-out\cache\*"
```

- [ ] **Step 3: 运行全量 AST 重建**

```bash
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify update C:\Users\Donki\Desktop\ZYKJ_MES
```

预期：生成新的 `graphify-out/graph.json` 和 `GRAPH_REPORT.md`，无错误退出。

- [ ] **Step 4: 记录 Phase 1 基线指标**

从 `graphify-out/GRAPH_REPORT.md` 读取并记录：节点数、边数、推断率、社区数、推断边平均置信度。

---

### Task 2: 抽样验证核心模块精度

- [ ] **Step 5: 测试生产工单实体**

```bash
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "ProductionOrder" --graph graphify-out/graph.json
```

- [ ] **Step 6: 测试工序实体**

```bash
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "Process" --graph graphify-out/graph.json
```

- [ ] **Step 7: 测试质检实体**

```bash
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "Quality" --graph graphify-out/graph.json
```

- [ ] **Step 8: 测试设备实体**

```bash
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "Equipment" --graph graphify-out/graph.json
```

- [ ] **Step 9: 测试权限实体**

```bash
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "Role" --graph graphify-out/graph.json
```

- [ ] **Step 10: 测试核心路径（工单→工序→质检）**

```bash
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify path "ProductionOrder" "QualityInspection" --graph graphify-out/graph.json
```

- [ ] **Step 11: 汇总问题清单**

记录以下发现：
- 哪些实体 `explain` 结果存在明显错误或遗漏
- 哪些路径不可达或不合理
- 哪些社区粒度过细

---

## Phase 2: 编写项目记忆

> **前提：** 所有标注内容必须基于源码验证，不可臆测。编写前先读取对应源码确认。

### Task 3: 架构总览项目记忆

**文件：** `docs/project-memory/architecture-overview.md`

- [ ] **Step 12: 读取后端入口确认架构**

```bash
# 并行读取后端关键文件确认分层
```

读取 `backend/app/main.py`, `backend/app/worker_main.py`, `backend/app/api/v1/api.py` 确认路由汇聚方式。

- [ ] **Step 13: 读取前端入口确认架构**

读取 `frontend/lib/main.dart`, `frontend/lib/core/network/` 目录下的 HTTP 客户端。

- [ ] **Step 14: 编写 architecture-overview.md**

```markdown
# ZYKJ_MES 整体架构

## 系统拓扑
- 后端：FastAPI 单体应用，分层为 API 路由层 → Service 业务层 → Model 数据层
  - Web 进程（backend-app-main）处理 HTTP 请求
  - Worker 进程（backend-worker_main）处理后台异步任务
- 前端：Flutter 桌面应用，分为 core 基础设施层 + features 业务模块层
- 插件系统：Python 嵌入式运行时 + manifest 描述规范
- 基础设施：Docker Compose（PostgreSQL + Redis + backend-web + backend-worker）

## 核心依赖方向
- backend-app-main → backend-app-api-v1-api (API 路由汇聚)
- backend-app-api-v1-api → backend-app-api-v1-endpoints-* (17 个端点模块)
- backend-app-api-v1-endpoints-* → backend-app-services-* (39 个服务)
- backend-app-services-* → backend-app-models-* (58 个 ORM 模型)
- frontend-lib-features-* → frontend-lib-core-network (HTTP API 调用)
- frontend-lib-features-* → backend-app-api-v1-endpoints-* (前后端接口契约)

## 数据流方向
- 前端 features → HTTP API → 后端 endpoints → services → models → PostgreSQL
- 后台 Worker → services → models → PostgreSQL
- Worker 定时任务 → services (maintenance_scheduler, message 投递)
```

---

### Task 4: 后端服务层项目记忆

**文件：** `docs/project-memory/backend-services.md`

- [ ] **Step 15: 列出所有 Service 文件**

```bash
Get-ChildItem "C:\Users\Donki\Desktop\ZYKJ_MES\backend\app\services" -Name
```

- [ ] **Step 16: 读取核心 Service 文件确认依赖关系**

并行读取以下服务文件的关键 import 和类定义：
- `backend/app/services/production_service.py`
- `backend/app/services/quality_service.py`
- `backend/app/services/equipment_service.py`
- `backend/app/services/user_service.py`
- `backend/app/services/product_service.py`

- [ ] **Step 17: 编写 backend-services.md**

标注每个 Service 的：
- 所属模块域（用户权限/产品工艺/生产执行/设备管理/质量管理/消息推送/系统管理）
- 主要职责（1 句话）
- 依赖的其他 Service（有明确的 import/调用关系）
- 使用的 Model（有明确的 import/查询关系）
- 被哪些 Endpoint 调用（有明确的 router 注入关系）

---

### Task 5: 后端数据模型项目记忆

**文件：** `docs/project-memory/backend-models.md`

- [ ] **Step 18: 列出所有 Model 文件**

```bash
Get-ChildItem "C:\Users\Donki\Desktop\ZYKJ_MES\backend\app\models" -Name
```

- [ ] **Step 19: 读取核心 Model 确认外键关系**

并行读取：
- `backend/app/models/order.py`
- `backend/app/models/product.py`
- `backend/app/models/process.py`
- `backend/app/models/production_*.py` (所有 production 相关 model)
- `backend/app/models/equipment*.py`
- `backend/app/models/quality*.py`

- [ ] **Step 20: 编写 backend-models.md**

标注核心实体关系图：
```
Product → Process → CraftTemplate
Product → ProductionOrder → ProductionTask → ProductionLog
ProductionOrder → Equipment → MaintenanceRecord
ProductionOrder → QualityInspection → QualityDefect
User → Role → Permission → Page/API
```

每对关系附说明（1:N / N:M / 通过哪个字段关联）。

---

### Task 6: 前端功能模块项目记忆

**文件：** `docs/project-memory/frontend-features.md`

- [ ] **Step 21: 列出前端 features 目录**

```bash
Get-ChildItem "C:\Users\Donki\Desktop\ZYKJ_MES\frontend\lib\features" -Name
```

- [ ] **Step 22: 读取核心 feature 确认结构**

并行读取每个 feature 的目录结构（确认是否有 models/services/widgets/screens 子目录）。

- [ ] **Step 23: 读取网络层确认 API 调用方式**

读取 `frontend/lib/core/network/` 下的 HTTP 客户端文件，确认 API 基础 URL 构造方式。

- [ ] **Step 24: 编写 frontend-features.md**

标注每个 feature 模块：
- 主要页面/路由
- 调用的后端 API 端点（通过搜索 feature 中的 HTTP 调用字符串确认）
- 使用的 shared state（Provider/Riverpod/其他状态管理）

---

### Task 7: 权限模型项目记忆

**文件：** `docs/project-memory/authz-rbac.md`

- [ ] **Step 25: 读取权限核心源码**

读取：
- `backend/app/core/rbac.py`
- `backend/app/core/authz_catalog.py`
- `backend/app/core/page_catalog.py`
- `backend/app/models/role.py`
- `backend/app/models/authz*.py` (所有 authz 相关 model)

- [ ] **Step 26: 编写 authz-rbac.md**

标注：
- Role → Permission 的 N:M 关系
- Permission 与 Page/API 的映射链
- RBAC 检查流程：请求 → JWT 解析 → Role 查询 → Permission 匹配 → 放行/拒绝
- 前端权限控制：page_catalog 如何驱动前端菜单渲染

---

### Task 8: 核心生产流程项目记忆

**文件：** `docs/project-memory/production-flow.md`

- [ ] **Step 27: 读取生产相关源码**

读取：
- `backend/app/services/production_service.py` 和所有 `production_*.py` services
- `backend/app/models/production_*.py` 所有 production 相关 models
- `backend/app/api/v1/endpoints/production.py`

- [ ] **Step 28: 编写 production-flow.md**

标注核心生产执行数据流：
```
1. 创建工单 (ProductionOrder) → 选择产品/工艺路线
2. 工单下发 → 生成生产任务 (ProductionTask)
3. 任务执行 → 记录生产日志 (ProductionLog)
4. 首件检验 (FirstArticle) → 通过/不通过
5. 工序质检 (QualityInspection) → 缺陷记录 (QualityDefect)
6. 设备维护 (Maintenance) → 维修记录 (Repair)
7. 工单完成 → 统计汇总
```

附每个步骤涉及的关键 Model 和 Service。

---

### Task 9: 插件系统项目记忆

**文件：** `docs/project-memory/plugin-system.md`

- [ ] **Step 29: 读取插件系统源码**

读取：
- `plugins/runtime/python312/` 确认运行时结构
- `plugins/serial_assistant/manifest.json` 确认 manifest 规范
- `plugins/serial_assistant/launcher.py` 确认启动流程
- `plugins/serial_assistant/app/server.py` 确认插件 HTTP 服务模式
- `frontend/lib/features/plugin_host/` 确认前端插件宿主

- [ ] **Step 30: 编写 plugin-system.md**

标注：
- 插件 manifest 规范（id/入口/权限/依赖/生命周期）
- 插件运行时架构（独立 Python 进程 + HTTP 服务 + Web UI 嵌入）
- serial_assistant 作为参考实现的关键模式
- 前端 plugin_host 的嵌入方式（webview / iframe）

---

## Phase 3: 最终重建与验证

### Task 10: 最终全量重建

- [ ] **Step 31: 二次清空缓存**

```bash
Remove-Item -Recurse -Force "C:\Users\Donki\Desktop\ZYKJ_MES\graphify-out\cache\*"
```

- [ ] **Step 32: 运行最终重建**

```bash
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify update C:\Users\Donki\Desktop\ZYKJ_MES
```

预期：project-memory 文件参与提取，生成更精准的图谱。

---

### Task 11: 质量验收

- [ ] **Step 33: 记录 Phase 3 指标**

从 `graphify-out/GRAPH_REPORT.md` 读取并与 Phase 1 对比。

- [ ] **Step 34: 抽样验证核心模块（复用 Step 5-10 命令）**

```bash
# 生产工单
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "ProductionOrder" --graph graphify-out/graph.json

# 工序
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "Process" --graph graphify-out/graph.json

# 质检
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "Quality" --graph graphify-out/graph.json

# 设备
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "Equipment" --graph graphify-out/graph.json

# 权限
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify explain "Role" --graph graphify-out/graph.json

# 核心路径
C:\Users\Donki\Desktop\ZYKJ_MES\.graphify-venv\Scripts\python.exe -m graphify path "ProductionOrder" "QualityInspection" --graph graphify-out/graph.json
```

- [ ] **Step 35: 验收判定**

对照验收标准：
- 核心模块 explain 输出语义是否正确
- 推断边占比是否 < 10%
- 社区数是否在 40-60 范围
- 核心路径是否可达

---

### Task 12: 收尾

- [ ] **Step 36: 提交变更**

```bash
git add docs/project-memory/ docs/superpowers/specs/ docs/superpowers/plans/ graphify-out/
git commit -m "重构 Graphify 知识图谱：全量重建 + 7 份项目记忆标注"
```

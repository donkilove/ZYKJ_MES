# Graphify 知识图谱重构设计

> 日期：2026-05-01 | 状态：待执行

## 1. 背景与目标

### 1.1 当前状态

| 指标 | 值 | 问题 |
|------|-----|------|
| 节点数 | 7614 | 过多，噪声大 |
| 边数 | 15401 | 推断边占比 23%，置信度仅 0.66 |
| 社区数 | 139 | 粒度过细，无法作为导航入口 |
| 生成方式 | AST-only，0 token | 无语义增强 |
| 项目记忆 | 空 | 缺失结构化上下文 |

### 1.2 重构目标

- 核心业务模块（生产/质量/设备/工艺/权限）关系准确，`explain` 输出语义正确
- 推断边占比 < 10%，置信度 > 0.85
- 社区数控制在 40-60，每个社区有可理解的语义边界
- 图谱为 AI 辅助开发提供可用结构上下文

## 2. 总流程：三阶段

```
摸底重建 → 分析 + 编写项目记忆 → 最终重建 + 验证
```

## 3. Phase 1: 摸底重建

### 3.1 步骤

| 步骤 | 操作 |
|------|------|
| 1.1 | 清空 `graphify-out/cache/` |
| 1.2 | 运行 `graphify update .` 全量 AST 重建 |
| 1.3 | 用 `graphify explain` 抽样测试核心实体（工单、工序、质检、设备） |
| 1.4 | 用 `graphify path` 测试关键实体间最短路径 |
| 1.5 | 记录问题清单：断裂关系、孤立节点、不合理社区 |

### 3.2 输出物

- 问题清单（记录在 `evidence/` 或交互中）
- 关键指标快照（节点/边/推断率/社区数）

## 4. Phase 2: 编写项目记忆

在 `docs/project-memory/` 下编写 7 个标注文件：

| 文件 | 内容 |
|------|------|
| `architecture-overview.md` | 整体架构拓扑：后端单体分层 (API→Service→Model)、Flutter 前端 (core+features)、插件系统、Docker 基础设施 |
| `backend-services.md` | 39 个 Service 的职责边界、依赖链、与 API 端点的挂载关系 |
| `backend-models.md` | 58 个 ORM 模型的核心实体关系（产品→工序→工单→设备→质检） |
| `frontend-features.md` | 13 个 feature 模块的页面路由、状态管理、API 调用映射 |
| `authz-rbac.md` | 权限模型：Role → Permission → Page/API 授权链 |
| `production-flow.md` | 核心生产执行流程：从工单创建到质检完成的数据流 |
| `plugin-system.md` | 插件运行时、manifest 规范、serial_assistant 参考实现 |

### 4.1 编写原则

- 中文，Markdown 格式
- 每个实体使用明确的全限定名称（如 `backend.app.services.production_service.ProductionService`）
- 关系用 `A → B` 标注方向，附简要说明
- 基于源码验证，不可臆测

## 5. Phase 3: 最终重建与验证

### 5.1 步骤

| 步骤 | 操作 |
|------|------|
| 3.1 | 再次清空 `graphify-out/cache/` |
| 3.2 | 运行 `graphify update .` 重建（project-memory 参与提取） |
| 3.3 | 质量验收：`graphify query` / `explain` / `path` 抽样测试核心模块 |
| 3.4 | 与 Phase 1 指标对比 |

### 5.2 验收标准

- 核心模块（生产/质量/设备/工艺/权限）的 `explain` 输出语义正确
- 推断边占比从 ~23% 降到 < 10%
- 社区数从 139 降到 40-60，社区命名可理解
- `graphify path` 能在核心实体间找到合理路径

## 6. 风险与回退

- 当前 `graph.json` 为 git 追踪文件，可随时还原
- `.graphifyignore` 已正确配置，不会纳入密钥/缓存/构建产物
- 如 project-memory 标注偏差导致更差结果，可删除对应文件后重新 `update`

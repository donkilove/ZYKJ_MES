# Graphify 图谱质量治理与验收设计

- 日期：2026-05-01
- 主题：Graphify 图谱一致性、降噪、业务语义与导航视图治理
- 状态：待实施

## 1. 背景

仓库已经完成首版 Graphify 接入，现有基础包括：

1. `.graphifyignore` 已建立，敏感文件、缓存、构建产物和任务流水已排除。
2. `graphify-out/GRAPH_REPORT.md` 与 `graphify-out/graph.json` 已生成，可用于结构导航。
3. `tools/enrich_graph.py` 已尝试通过后处理补边、删边和合并社区。
4. `docs/project-memory/` 已作为长期稳定项目事实入口建立。

但当前图谱仍有四类核心问题：

1. 产物一致性弱：报告与 JSON 可能来自不同轮次，统计值不稳定，`edges` 与 `links` 口径混用。
2. 噪音偏高：`build`、`main`、`set`、`ValueError`、`package:flutter/material.dart` 等泛节点占据中心位置。
3. 业务语义不足：社区仍以 `Community 0/1/2` 形式出现，难以直接作为研发导航入口。
4. 可用性不聚焦：当前更像“全量结构图”，缺少面向排障、联调和影响面分析的任务视图。

本轮不是重新讨论“要不要有图谱”，而是把现有图谱从“首版可用”推进到“可稳定交付给 DeepSeek 实施、可由 Codex 验收”的状态。

## 2. 目标

### 2.1 目标

1. 让同一次生成的 `GRAPH_REPORT.md`、`graph.json`、导航视图和指标摘要具备统一元数据，可证明它们来自同一轮构建。
2. 保留原始图谱事实底座，同时产出一份更适合人和 agent 使用的治理后图谱。
3. 压低框架符号、测试基座、迁移标题和注释文本对中心性、社区和报告摘要的干扰。
4. 让主要社区具备业务可读名称，并补齐模块摘要。
5. 补出三类高频任务视图：入口导航、契约链路、影响面分析。
6. 建立一套可重复执行的验收口径，后续由 Codex 做只读复核时不再依赖主观印象。

### 2.2 非目标

1. 本轮不直接修改 Graphify 官方源码或私有安装方式。
2. 本轮不把 `docs/project-memory/` 当成解决一切问题的唯一手段。
3. 本轮不追求一次性消灭所有推断边，只要求把明显错误和明显噪音压下去。
4. 本轮不顺带改仓库主业务代码、接口契约或测试逻辑。
5. 本轮不要求 `graph.html` 必须可生成；超过 Graphify 原生阈值时允许缺席。

## 3. 总体方案

本轮采用“`raw graph` + `curated graph` + `navigation views`”三层结构，优先做仓库内后处理治理，不把优化点全部压到 Graphify 抽取器本体。

### 3.1 核心原则

1. 原始图谱保留：任何删边、降权、重命名都不直接覆盖事实底座。
2. 治理结果单独产出：真正给人和 agent 读取的是治理后的结果，而不是未经筛选的原始全图。
3. 先后处理、后抽取增强：先用最小改动解决一致性、噪音和导航问题，再评估是否需要深入改抽取层。
4. 配置优先：泛节点、路径域名、社区命名和视图规则尽量配置化，而不是全部硬编码在 Python 逻辑里。
5. 验收先于优化炫技：任何治理都必须能回答“这一版比上一版好在哪里，怎么证明”。

### 3.2 推荐产物布局

兼容仓库当前使用习惯，保留 `graphify-out/GRAPH_REPORT.md` 与 `graphify-out/graph.json` 作为默认入口，同时新增原始层和治理层辅助产物：

```text
graphify-out/
  GRAPH_REPORT.md                  # 默认读取入口，治理后报告
  graph.json                       # 默认读取入口，治理后图谱
  manifest.json                    # 本轮构建元数据与统计摘要
  quality/
    metrics.json                   # 各项质量指标与对比结果
  navigation/
    entrypoints.md                 # 入口导航视图
    contract-chains.md             # 契约链路视图
    impact-surfaces.md             # 影响面视图
  raw/
    GRAPH_REPORT.raw.md            # Graphify 原始报告
    graph.raw.json                 # Graphify 原始图谱
```

推荐答案是：

1. `raw/` 只保存原始 Graphify 产物，不做二次改写。
2. 根目录 `GRAPH_REPORT.md` 与 `graph.json` 指向治理后的最终产物，保证仓库默认入口直接可用。
3. `manifest.json` 作为统一元数据中心，所有报告、视图和验收脚本都以它为准。

## 4. 实施边界

### 4.1 可以复用的现有资产

1. `.graphifyignore`
2. `.graphify-venv`
3. `tools/enrich_graph.py`
4. `docs/project-memory/*.md`
5. `docs/superpowers/specs/2026-05-01-graphify-rebuild-design.md`
6. `docs/superpowers/plans/2026-05-01-graphify-rebuild.md`

### 4.2 不建议沿用的做法

`tools/enrich_graph.py` 当前可作为探索性脚本参考，但不建议直接扩写为最终主入口，原因有三点：

1. 规则硬编码严重，核心实体、社区编号和删边条件都写死，难以维护。
2. 当前治理对象过度偏向少数核心模型，对全仓库级视图不够普适。
3. 它直接改写 `graphify-out/graph.json`，不符合 `raw graph` 与 `curated graph` 分层要求。

### 4.3 推荐文件职责

建议 DeepSeek 按以下职责落地，而不是继续堆在单个脚本里：

1. `tools/graphify_pipeline.py`
   - 负责统一构建入口、临时目录、原始产物归档、元数据生成和原子替换。
2. `tools/graphify_curate.py`
   - 负责节点分类、降噪、社区命名、治理后报告和质量指标产出。
3. `tools/graphify_navigation.py`
   - 负责生成入口导航、契约链路和影响面视图。
4. `tools/graphify_rules.json`
   - 负责泛节点、框架导入、测试基座、路径域名和命名模板配置。
5. `tools/enrich_graph.py`
   - 保留为兼容入口或迁移期 wrapper，最终只做转发或废弃说明，不再承担主治理逻辑。

如果 DeepSeek 更偏好目录形式，也可以改成 `tools/graphify/` 包结构，但职责切分不要变。

## 5. 分阶段设计

### 5.1 P0：一致性治理

这一阶段只解决“是不是同一轮产物”和“默认入口能不能稳定被消费”的问题。

#### 实施要求

1. 每轮构建生成唯一 `run_id`。
2. 所有产物统一记录以下字段：
   - `run_id`
   - `generated_at`
   - `source_commit`
   - `corpus_hash`
   - `ignore_hash`
   - `graphify_version`
   - `curation_version`
3. Graphify 原始输出先进临时目录，再复制到 `graphify-out/raw/`。
4. 治理后产物统一从同一份内存数据或同一份中间 JSON 渲染，禁止“先出报告、后改 JSON”。
5. 统一图数据契约：
   - `graph.json` 中以 `links` 作为真实边字段。
   - `manifest.json` 与 `metrics.json` 中统一使用 `edge_count` 表示边数量。
   - 如需兼容历史口径，可额外给出 `legacy_report_edge_label = "links"`，但不要再让文档正文混写。

#### 验收标准

1. `graphify-out/manifest.json` 存在，且 `run_id`、`corpus_hash`、`ignore_hash` 非空。
2. `GRAPH_REPORT.md`、`graph.json`、`metrics.json` 的 `run_id` 一致。
3. 报告中的节点数、边数、社区数与 `graph.json`、`metrics.json` 对得上。
4. 新一轮构建若失败，不覆盖上一轮正式产物。

### 5.2 P1：降噪治理

这一阶段解决“图谱全是框架公共符号、测试基座和迁移标题”的问题。

#### 实施要求

1. 建立四类节点处理方式，而不是只有“保留/删除”两档：
   - `keep`：完全参与治理和排名
   - `downweight`：保留关系，但降低中心性和社区命名权重
   - `hide_from_rank`：保留在图中，但不参与 God Nodes、Top N、社区摘要
   - `drop_from_curated`：只保留在 raw 中，不进入 curated
2. 第一批泛节点种子至少包含以下对象：
   - `build`
   - `main`
   - `initState`
   - `dispose`
   - `set`
   - `ValueError`
   - `BaseModel`
   - `package:flutter/material.dart`
   - `package:flutter_test/flutter_test.dart`
3. 第一批文本噪音种子至少覆盖：
   - Alembic revision 标题
   - 长 docstring 片段
   - 纯注释说明文本
   - `setUp` / `tearDown` / `MaterialApp` / `SizedBox` 等测试基座或 UI 框架节点
4. 框架公共导入允许存在，但不能主导：
   - God Nodes
   - 社区摘要
   - 建议问题
5. 降噪规则必须配置化，不能散落在多个脚本里各写一份。

#### 验收标准

1. 治理后 Top 20 高连接节点中，业务节点占比至少达到 60%。
2. `build`、`main`、`set`、`ValueError` 不再进入 Top 10。
3. Alembic revision 标题类节点不再出现在主报告的 `Knowledge Gaps` 前列。
4. `raw/graph.raw.json` 保留原始节点和边，未被破坏。

### 5.3 P2：业务语义治理

这一阶段解决“社区编号不可读”和“图谱虽大但不懂业务域”的问题。

#### 实施要求

1. 先按路径规则给节点打 `domain_tag`，至少覆盖：
   - `user`
   - `authz`
   - `product`
   - `craft`
   - `production`
   - `quality`
   - `equipment`
   - `message`
   - `plugin`
   - `frontend-core`
   - `backend-core`
   - `tests`
   - `migrations`
2. 社区命名采用“主域 + 主实体 + 主动作/子域”的模板，不再直接保留 `Community N`。
3. 社区摘要至少说明：
   - 主要目录或模块
   - 主要实体
   - 主要入口文件或页面
   - 主要测试覆盖点
4. `docs/project-memory/` 继续作为补充增强来源，但不承担唯一语义来源角色。
5. 治理后报告中保留一个“原社区编号 -> 新社区名称”的映射区，便于回溯。

#### 验收标准

1. 前 20 个社区中，至少 80% 拥有业务可读名称。
2. 至少能清晰命名出以下领域社区：
   - 用户权限
   - 产品
   - 工艺
   - 生产
   - 质量
   - 设备
3. `EquipmentLedgerItem`、`ProductionOrder`、`Role` 这类核心对象所在社区的命名和摘要具备明显业务语义。

### 5.4 P3：导航视图治理

这一阶段解决“全图难读，落不到具体研发任务”的问题。

#### 实施要求

生成以下三类治理后导航视图：

1. `entrypoints.md`
   - 后端入口：`main.py`、`worker_main.py`、各 endpoint 模块
   - 前端入口：`frontend/lib/main.dart`、主要 feature page
   - 脚本入口：`start_backend.py`、`start_frontend.py`、关键工具脚本
   - 测试入口：关键 integration test / widget test / backend integration test
2. `contract-chains.md`
   - 至少输出若干条“后端 schema -> endpoint -> frontend model -> service -> page -> test”的链路
   - 第一批必须覆盖：
     - `EquipmentLedgerItem`
     - `MaintenanceItemEntry`
     - `ProductionOrder`
     - `Role` / 权限目录相关对象
3. `impact-surfaces.md`
   - 以核心对象为中心，列出上下游 1 到 2 跳的文件和模块
   - 第一批至少覆盖：
     - `ProductionOrder`
     - `Equipment`
     - `Role`
     - `AppSession`

#### 验收标准

1. 研发看到 `entrypoints.md` 后，能直接定位主要后端、前端、脚本和测试入口。
2. `contract-chains.md` 中至少 3 条链路可与源码真实对应。
3. `impact-surfaces.md` 中至少 3 个对象的上下游文件能被 `rg` 或源码阅读复核。

## 6. 推荐实施顺序

DeepSeek 实施时，建议严格按以下顺序推进：

1. 先做 P0，一次性解决 `run_id`、原子替换、`manifest.json` 和字段口径。
2. 再做 P1，把 stoplist、文本噪音和测试基座噪音规则落稳。
3. 再做 P2，让社区命名和领域标签可读。
4. 最后做 P3，补导航视图。
5. 只有当前四段完成后，才评估是否继续深入 Graphify 抽取层或 LLM 语义层。

这一顺序的原因是：

1. 没有 P0，后面的所有比较都缺少可靠基线。
2. 没有 P1，P2 的社区命名和 P3 的视图摘要会持续被噪音污染。
3. 没有 P2，P3 只能产出“结构路径”，很难产出业务导航。

## 7. 给 DeepSeek 的实施注意事项

1. 不要直接删除现有 `docs/superpowers/specs/2026-05-01-graphify-rebuild-design.md` 与 `docs/superpowers/plans/2026-05-01-graphify-rebuild.md`，新方案应作为补充或替代实现，不做历史清洗。
2. 不要直接覆盖 `graphify-out/raw/` 中的原始产物。
3. 不要把业务事实硬编码成只适配少数核心实体的脚本；优先做规则引擎或配置文件。
4. 不要把 `.env`、`.tmp_runtime`、`.claude`、`graphify-out/cache` 等路径重新纳入图谱输入。
5. 不要让 `docs/project-memory/` 里的未验证文字直接转化为高置信业务边，必须保留事实来源标记。
6. 如果沿用 `tools/enrich_graph.py` 的部分逻辑，必须先拆出纯函数和配置，再决定保留或下线该脚本。

## 8. 给 Codex 的验收口径

Codex 后续只读验收时，按以下口径执行：

### 8.1 一致性验收

1. 读取 `graphify-out/manifest.json`，确认 `run_id`、`source_commit`、`corpus_hash`、`ignore_hash` 存在。
2. 读取 `graphify-out/graph.json` 与 `graphify-out/quality/metrics.json`，确认统计一致。
3. 抽查 `GRAPH_REPORT.md` 头部摘要，确认与 `metrics.json` 一致。

### 8.2 降噪验收

1. 查看治理后 Top N 节点，确认泛节点和框架节点显著下降。
2. 搜索 `graph.json` 中 Alembic revision 标题是否已只保留在 raw 或不再主导报告。
3. 检查 `metrics.json` 中是否有泛节点占比、文本噪音占比或等效健康指标。

### 8.3 语义验收

1. 查看社区命名结果，确认不再以 `Community N` 为主。
2. 抽查 `equipment`、`production`、`authz` 等模块社区摘要是否具备业务语义。

### 8.4 视图验收

1. 打开 `navigation/entrypoints.md`，确认后端、前端、脚本和测试入口齐全。
2. 打开 `navigation/contract-chains.md`，抽查至少 3 条链路回到源码。
3. 打开 `navigation/impact-surfaces.md`，确认影响面列出的文件可被源码检索复核。

### 8.5 安全边界验收

1. 搜索治理后产物，确认未重新纳入 `.env`、`.tmp_runtime`、`settings.local.json`、`graphify-out/cache` 等敏感或噪音路径。
2. 确认 `.graphifyignore` 未被回退。

## 9. 风险与回退

1. 若治理规则过重，可能把有用关系一并压掉。
   - 回退方式：保留 raw，不覆盖根入口，先只输出 metrics 与对比报告。
2. 若社区命名规则过于依赖路径，可能在跨域节点上命名失真。
   - 回退方式：先保留“原社区编号 + 候选业务名”双列输出。
3. 若导航视图一次产出过多，可能变成新的噪音源。
   - 回退方式：只保留首批 3 类视图，不继续扩展更多专项视图。
4. 若 DeepSeek 直接在单脚本里堆规则，后续维护成本会迅速变高。
   - 回退方式：在验收时要求其把规则抽出到配置文件后再通过。

## 10. 验收通过定义

满足以下条件时，可认为本轮治理完成并可交由 Codex 正式验收：

1. 根目录正式产物和 `raw/` 原始产物同时存在，且元数据一致。
2. God Nodes 与社区摘要不再被泛节点和框架节点主导。
3. 主要社区拥有业务可读命名。
4. 三类导航视图已生成且可回到源码复核。
5. 治理流程可重复执行，失败时不会污染上一轮正式结果。

## 11. 当前推荐结论

当前推荐 DeepSeek 的落地策略不是“继续重建更多 project-memory 文档”，而是：

1. 以现有 Graphify 结果为原始底座；
2. 先补一层统一构建与后处理治理；
3. 用配置化规则解决一致性、降噪和社区命名；
4. 最后再把成果沉淀为面向研发任务的导航视图。

这样收益最快，风险最可控，也最适合后续由 Codex 做只读验收。

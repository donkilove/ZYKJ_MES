# 前端模块 UI 收敛改造剧本

## 适用对象

- 任意尚未对齐 `core/ui/patterns` 的 feature 模块。
- 用法：先按"前置检查清单"梳理本模块差距，再按"改造步骤"分页执行，每页一次 commit。

## 视觉基线

- 视觉锚点：`frontend/lib/features/user/presentation/user_management_page.dart`
- 公共件来源：
  - `frontend/lib/core/ui/foundation/`
  - `frontend/lib/core/ui/primitives/`
  - `frontend/lib/core/ui/patterns/`
- 设计 token：`MesTokens` 经 `ThemeExtension` 注入，统一颜色/间距/圆角/字体层级。

## 八维基线

| 维度 | 标准件 | 备注 |
|------|--------|------|
| 页面头部 | `MesPageHeader(title, subtitle, actions)` | 必有标题 + 动作层；旧 wrapper `CrudPageHeader` 已转发到 `MesPageHeader`，本轮兼容保留 |
| 筛选区 | `MesFilterBar` | 单行控件 + 查询/重置；必要时换行 |
| 操作条 | `MesToolbar` | 主操作右置，次级操作左置或收起 |
| 内容容器 | `MesSectionCard` 或 `MesCrudPageScaffold` | 统一外边距与圆角 |
| 列表与分页 | `CrudListTableSection` + `MesPaginationBar` | 严禁继续使用 `SimplePaginationBar` |
| 状态反馈 | `MesInlineBanner`、`MesEmptyState`、`MesErrorState` | 错误以 banner 表达时优先于覆盖整表 ErrorState |
| 浮层 | `showMesLockedFormDialog` 或 `AlertDialog` 或 `MesDetailPanel` | 表单弹窗必须用 `showMesLockedFormDialog` 保护 `barrierDismissible:false` 行为 |
| 响应式与密度 | `LayoutBuilder` 断点 | 宽屏双栏 ≥ 1200px；中宽切单栏；工具条按需换行 |

## 重要约定

### 关于 `showMesLockedFormDialog`

**不要**把它替换成裸 `AlertDialog`。它内部封装了 `barrierDismissible:false` + `PopScope(canPop:false)`，是**有意保留**的表单保护行为，防止用户填表中途误关闭丢数据。

- 文件位置：`frontend/lib/core/ui/patterns/mes_locked_form_dialog.dart`
- 原 `core/widgets/locked_form_dialog.dart` 已删除
- 全站调用必须使用 `showMesLockedFormDialog<T>(...)`

### 关于 `CrudPageHeader`、`CrudListTableSection`、`UnifiedListTableHeaderStyle`、`AdaptiveTableContainer`

这些是 `core/widgets/` 下尚存的旧件，但内部已转发到 `core/ui/patterns/`。本剧本下：

- **新引用**：禁止再 import 这些旧件，改用 `core/ui/patterns/` 直件。
- **现有引用**：本轮不强制全删；当某模块所有 page 都迁移到新件后，再做物理清退。
- 例外：`UserDataTable` 内部仍用 `CrudListTableSection`，因为分页/空态/卡片 wrapper 行为完整、且转发链已对齐 `MesEmptyState`，本轮不动。

### 关于加载态

裸 `CircularProgressIndicator` 在大量 page 仍在使用。本剧本下：

- **不强制**在第一轮迁移时统一加载态。
- 等 patterns 层提供统一 `MesLoadingState` 之后，再做全站对齐（属于 patterns 自身扩展工作，先于 page 迁移）。

## 前置检查清单（每模块开始前必跑）

```bash
MODULE=<模块名>  # auth/craft/equipment/...

# 1. 旧件 import 盘点
grep -rln "core/widgets/" frontend/lib/features/$MODULE 2>&1 | head -20

# 2. SimplePaginationBar 残留
grep -rn "SimplePaginationBar" frontend/lib/features/$MODULE 2>&1 | head -10

# 3. CrudPageHeader 残留（可保留但应记录）
grep -rn "CrudPageHeader" frontend/lib/features/$MODULE 2>&1 | head -10

# 4. inline 样式（手写 BoxDecoration / EdgeInsets）数量
grep -rln "BoxDecoration\|EdgeInsets\." frontend/lib/features/$MODULE/presentation 2>&1 | wc -l

# 5. 浮层调用类型
grep -rn "showDialog\|showLockedFormDialog\|showMesLockedFormDialog" frontend/lib/features/$MODULE 2>&1 | head -20

# 6. 模块壳层与页头是否齐备
ls frontend/lib/features/$MODULE/presentation/widgets/ 2>&1 | grep -E "_page_shell|_page_header"
```

把结果记录到 `evidence/task_log_<日期>_<模块>_ui_convergence.md` 的"前置盘点"小节。

## 改造步骤（每页执行一次完整循环）

按以下顺序，**每完成一项就跑 analyze + 该页 widget test**，避免错误堆积。

1. **替换分页条**：`SimplePaginationBar` → `MesPaginationBar`（参数完全兼容，零适配成本）
2. **替换浮层**：`showLockedFormDialog` → `showMesLockedFormDialog`（仅改命名）；inline `showDialog + AlertDialog` 形式按需保留
3. **反馈横幅**：手写 `Container` + 错误文本 → `MesInlineBanner.error/warning/info/success`
4. **空数据占位**：手写 Center Text → `MesEmptyState(title, description)`
5. **错误态占位**：替换为 `MesErrorState(title, description, onRetry)`，但**仅当**错误确实需要覆盖整个内容区时；如果错误是"在已有数据上叠加"性质，应继续用 `MesInlineBanner`
6. **页头**：旧 `CrudPageHeader` 保持现状，新页头直接用 `MesPageHeader(title, subtitle, actions)`
7. **筛选区**：手写 Row/Wrap + TextField/Dropdown → `MesFilterBar(children:[...])`
8. **操作条**：手写按钮组 → `MesToolbar(primary, secondary, overflow)`
9. **内容容器**：手写 `Padding + Column + Card` → `MesCrudPageScaffold` 或 `MesSectionCard`
10. **响应式**：`MediaQuery.of(context).size.width` → `LayoutBuilder` 断点

每完成一页提交一个 commit，commit 信息格式：`<模块>/<页面> 对齐用户管理基线（<具体改了什么>）`。

## 验证（每页）

```bash
cd frontend
flutter analyze lib/features/<模块>
flutter test test/widgets/<相关测试文件>.dart -r compact
```

模块所有 page 完成后，跑一次集成测试：

```bash
flutter test integration_test/<模块>_flow_test.dart -d windows
```

## 禁止事项

- **不得**在 `core/ui/patterns/` 中增加业务相关参数。
- **不得**为单个模块新建独立设计 token；颜色/间距全用 `MesTokens`。
- **不得**为追求统一抹掉业务确实需要的差异；保留差异必须在本任务日志的"保留差异"小节记录原因。
- **不得**在本剧本之外的范围内提交修改（不动业务逻辑、不动数据流、不动权限判定、不动后端 API）。
- **不得**用 `git add -A` 或 `git add .`；始终按文件名显式 stage，避免误带其他 agent 的工作树脏文件。
- **不得**跳过分析（`flutter analyze`）和模块测试就提交。

## 留痕要求

每完成一个模块，在 `evidence/task_log_20260427_frontend_ui_global_convergence.md`（或本轮任务的对应 verification_*.md）追加一节：

```markdown
### 阶段 4 / <模块>

- 前置盘点结果：
  - core/widgets 残留：N 处
  - SimplePaginationBar 残留：N 处
  - CrudPageHeader 残留：N 处
- 改造路径：
  - <page1>：<改了什么 + commit SHA>
  - <page2>：...
- 保留差异：
  - <page>: <差异点>，<原因>
- 验证：
  - flutter analyze lib/features/<模块>: 通过
  - flutter test test/widgets/<...>: 通过
  - 集成测试：通过/跳过（说明）
```

## 模块剩余清单（推荐执行顺序）

按"成熟度低→改动收益大"优先：

1. **product**（成熟度高，剩余 SimplePaginationBar 等少量残留，作为剧本验证起步首选）
2. **equipment**（成熟度低，全模块结构重组，工作量大但模式重复）
3. **production**（成熟度最低，16 个 page，最大批量；按子页分批提交）
4. **quality**（混合态，先收 data/defect_analysis/supplier 三页）
5. **craft**（混合态，先收 process_management/process_configuration）
6. **message**（已基本对齐，仅 announcement 浮层需收口）
7. **misc**（5 个独立页：login/force_change_password/register 不收 CRUD 模式，daily_first_article/first_article_disposition 按 CRUD 模式收）
8. **settings + plugin_host**（settings 已对齐，plugin_host 是特殊 Row 布局，仅检查不动）
9. **shell.home**（已对齐，仅检查）
10. **auth + time_sync**（无 page，仅 import 检查）

## 模块特别注意

- **生产模块**：
  - `production_first_article_page` 与 `first_article_scan_review_mobile_page` 涉及移动端布局差异，保留差异需在剧本备注中记录
  - `first_article_scan_review_mobile_page` 是独立 `MaterialApp` 入口，不适用 MES 标准外壳
- **misc.login_page**：已有专门的"登录页公告"设计（`docs/superpowers/specs/2026-04-22-login-page-announcement-design.md`），收敛时**不要破坏**其公告区结构
- **shell.home_page**：仪表盘类布局，收敛策略以"页头 + 容器 + 状态反馈"为主，不强求与 CRUD 页同构
- **plugin_host_page**：自定义 Row(Sidebar + Workspace) 结构，**保留差异**

## 集成测试基线

阶段 1+2 完成后，已知 `login_flow_test.dart` 中两个用例预先存在失败：

- `登录后进入消息中心并完成详情查看、单条已读与跳转到账户设置`（line 312）
- `登录后进入工艺总页并切换关键页签完成关键动作`（line 611）

这两个失败在 `main` 分支同样存在，与本轮 UI 收敛改动无关。后续模块改造时，**只关注本轮新引入的失败**，已知失败按预先存在处理。

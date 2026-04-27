# UI 全局收敛工作交接文档

## 1. 背景
本轮工作围绕 Flutter 前端的全局 UI 一致性收敛展开，目标是把分散的原生 `Card` / 简单 `Center(Text(...))` / 零散提示区逐步迁移到现有 pattern 层，优先复用：

- `MesSectionCard`
- `MesInlineBanner`
- `MesEmptyState`
- `MesErrorState`
- `MesLoadingState`
- 已完成的 `MesCrudPageScaffold` / `MesPageHeader` / `MesDialog` 系列

你后续会在其他 IDE 中继续接手，所以这里重点记录：
1. 已完成到什么程度
2. 当前代码处于什么中间状态
3. 还剩哪些批次/文件没收口
4. 下一位接手时应怎么继续

---

## 2. 原始批次定义
用户确认过的批次划分如下：

### 第 1 轮：设置页 / shell 级公共可见界面
- 软件设置页骨架
- shell 的错误页、无权限页、入口级空态/提示区

### 第 2 轮：剩余 detail / panel / drawer 型页面
- 各类详情页、panel、drawer 页面进一步吃到统一 pattern

### 第 3 轮：零散 loading / empty / banner / section spacing 扫尾
- 通常是 grep 驱动的小修小补

### 第 4 轮（可能不需要）：最终一致性打磨
- 只在前 3 轮后仍有明显风格断点时再做

---

## 3. 已完成内容

### 3.1 第 1 轮：已完成
以下内容已经完成收敛：

#### shell 级公共界面
- `frontend/lib/features/shell/presentation/widgets/main_shell_scaffold.dart`
  - 错误页改为 `MesSectionCard + MesErrorState`
  - 无权限页改为 `MesSectionCard + MesEmptyState`
  - shell 顶部消息提示改为 `MesInlineBanner.info`

#### 设置页骨架
- `frontend/lib/features/settings/presentation/software_settings_page.dart`
- `frontend/lib/features/settings/presentation/widgets/software_time_sync_section.dart`
- `frontend/lib/features/settings/presentation/widgets/software_settings_content_sections.dart`
- `frontend/lib/features/settings/presentation/widgets/software_settings_page_header.dart`

说明：
- 设置页整体已经具备分区导航 + 分区内容的骨架
- 时间同步区已使用 `MesSectionCard`
- 内容区大体已接入统一 section pattern
- `software_settings_page.dart` 里的 `_SectionNavigation` 仍是原生 `Card`，属于后续可继续收口的小尾巴

### 3.2 插件中心面板：已完成一轮收敛
- `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_sidebar.dart`
  - 已改为 `MesSectionCard`
  - 空态改为 `MesEmptyState`
- `frontend/lib/features/plugin_host/presentation/widgets/plugin_host_workspace.dart`
  - 启动失败 / 未选择插件 / 已选择未运行 / 非全屏运行中面板，已统一到 `MesSectionCard`

### 3.3 设备详情相关页面：已完成一部分
以下文件已做过结构性收敛：

- `frontend/lib/features/equipment/presentation/maintenance_execution_detail_page.dart`
  - 已把简单详情页从裸 `ListView` 改为 `MesSectionCard`
  - 加载失败态改为 `MesEmptyState`

- `frontend/lib/features/equipment/presentation/maintenance_record_detail_page.dart`
  - 已把简单详情页从裸 `ListView` 改为 `MesSectionCard`
  - 加载失败态改为 `MesEmptyState`

- `frontend/lib/features/equipment/presentation/equipment_detail_page.dart`
  - 已新增以下拆分函数：
    - `_buildSummaryCard`
    - `_buildPlansCard`
    - `_buildWorkOrdersCard`
    - `_buildRecordsCard`
  - 设备概览 / 关联计划 / 未完成工单 / 最近保养记录这几段，已经开始切到 `MesSectionCard`
  - 详情加载失败态改为 `MesEmptyState`
  - 页面内消息区已准备使用 `MesInlineBanner.warning`

### 3.4 账号中心：只完成了一部分
- `frontend/lib/features/user/presentation/account_settings_page.dart`
  - `_buildProfileCard()` 已从原生 `Card` 改为 `MesSectionCard`

---

## 4. 当前未完成 / 半完成状态
以下是最关键的交接信息。

### 4.1 当前正改到一半的文件
#### `frontend/lib/features/user/presentation/account_settings_page.dart`
当前状态：
- `_buildProfileCard()` 已迁移到 `MesSectionCard`
- 但下面这些还没迁：
  - `_buildSessionCard()` 仍是原生 `Card`
  - `_buildPasswordCard()` 仍是原生 `Card`
  - `_buildOverviewCard()` 仍是自定义渐变 `Container`，是否保留需要人工判断
  - 页面级 `_message` 仍是手写错误容器，还没改成 `MesInlineBanner`

建议：
- `_buildSessionCard()` 直接迁到 `MesSectionCard`
- `_buildPasswordCard()` 保留高亮逻辑，但外层壳子改成 `MesSectionCard` 或兼容 highlighted 状态的 pattern 壳层
- 页面顶部 `_message` 改成 `MesInlineBanner.error` 或 `MesInlineBanner.warning`
- `_buildOverviewCard()` 不一定要强行改；它承担的是 hero/summary 视觉角色，不是普通 section，可保留，只要整体 spacing 协调即可

#### `frontend/lib/features/equipment/presentation/equipment_detail_page.dart`
当前状态：
- 已完成函数拆分并接入多个 `MesSectionCard`
- 但 `_buildRiskOverview()` 仍是原生 `Card` + 自定义浅橙风险块
- 该文件需要重新运行 analyze 确认没有因为中途编辑引入重复 key / 无用 import / 结构问题

建议：
- 判断 `_buildRiskOverview()` 是否保留为“强调型自定义风险卡片”
- 如果要继续统一，可把外层 `Card` 改为 `MesSectionCard`，内部保留风险配色块即可

### 4.2 尚未继续处理、但 grep 已明确暴露的典型文件
这些文件仍明显属于第 2/3 轮范围：

#### 详情 / panel / drawer / detail 类
- `frontend/lib/features/production/presentation/production_repair_order_detail_page.dart`
  - 仍是 `MesLoadingState + Center(Text) + 裸 ListView`
- `frontend/lib/features/production/presentation/production_scrap_statistics_detail_page.dart`
  - 同上，且关联维修工单列表仍用原生 `Card`
- `frontend/lib/features/misc/presentation/first_article_disposition_page.dart`
  - 详情主体仍是两个大 `Card`
  - 失败态仍是 `Center(Text)`
- `frontend/lib/features/equipment/presentation/equipment_detail_page.dart`
  - 风险卡仍是原生 `Card`

#### 仍有原生 Card 的用户/权限页面
- `frontend/lib/features/user/presentation/function_permission_config_page.dart`
- `frontend/lib/features/user/presentation/account_settings_page.dart`

#### 仍有原生 Card 的产品/工艺/质量/生产页面
- `frontend/lib/features/product/presentation/widgets/product_selector_panel.dart`
- `frontend/lib/features/product/presentation/widgets/product_parameter_editor_table.dart`
- `frontend/lib/features/craft/presentation/craft_reference_analysis_page.dart`
- `frontend/lib/features/craft/presentation/craft_kanban_page.dart`
- `frontend/lib/features/craft/presentation/process_configuration_page.dart`
- `frontend/lib/features/quality/presentation/quality_trend_page.dart`
- `frontend/lib/features/quality/presentation/quality_data_page.dart`
- `frontend/lib/features/production/presentation/production_pipeline_instances_page.dart`
- `frontend/lib/features/production/presentation/production_first_article_page.dart`
- `frontend/lib/features/production/presentation/production_data_page.dart`

#### 认证 / 登录注册 / 强制改密页
这类也仍残留大量原生 `Card`：
- `frontend/lib/features/misc/presentation/login_page.dart`
- `frontend/lib/features/misc/presentation/register_page.dart`
- `frontend/lib/features/misc/presentation/force_change_password_page.dart`

这批通常属于“最终是否需要完全统一”的范围，是否改动取决于你想保持多强的一致性。

---

## 5. 已做过的搜索结论
之前已经用 grep 扫出过一批残留点，核心结论如下：

### 5.1 仍残留原生 `Card` 的代表位置
曾扫到的典型结果包括：
- `account_settings_page.dart`
- `equipment_detail_page.dart`
- `production_repair_order_detail_page.dart`
- `production_scrap_statistics_detail_page.dart`
- `first_article_disposition_page.dart`
- `software_settings_page.dart`（导航卡）
- 以及 craft / production / quality / misc 多个页面

### 5.2 仍残留 `Center(child: Text(...))` 失败态的代表位置
曾扫到：
- `equipment_detail_page.dart`
- `maintenance_record_detail_page.dart`
- `maintenance_execution_detail_page.dart`
- `first_article_disposition_page.dart`
- `production_repair_order_detail_page.dart`
- `production_scrap_statistics_detail_page.dart`

其中只有设备三页已经开始被改掉。

---

## 6. 建议的接手顺序
如果你准备在其他 IDE 继续，建议按下面顺序，不要再大范围乱扫：

### 步骤 A：先把当前半完成文件收口
优先处理：
1. `frontend/lib/features/user/presentation/account_settings_page.dart`
2. `frontend/lib/features/equipment/presentation/equipment_detail_page.dart`

原因：
- 这两个文件已经处于编辑过一半的状态
- 继续接着做，最省上下文切换成本

### 步骤 B：补完剩余 detail 页面
建议依次处理：
1. `frontend/lib/features/production/presentation/production_repair_order_detail_page.dart`
2. `frontend/lib/features/production/presentation/production_scrap_statistics_detail_page.dart`
3. `frontend/lib/features/misc/presentation/first_article_disposition_page.dart`

目标：
- 把“加载失败态”统一为 `MesEmptyState` 或 `MesErrorState`
- 把主体详情段改为 `MesSectionCard`
- 保留业务结构，不做过度重构

### 步骤 C：做 grep 驱动扫尾
建议用以下关键词继续扫：
- `return Card(`
- `child: Card(`
- `Center(child: Text(`
- `MesLoadingState(`
- `Container(` + 人工识别是否其实是 banner / fake card

原则：
- 不要机械替换所有 Card
- 只替换那些本质上是“section 壳层 / 空态 / 错误态 / 普通信息卡”的地方
- 像 hero 区、渐变 summary、业务专用可视化卡片，不一定要强行换成 `MesSectionCard`

---

## 7. 建议的判定标准
后续是否算“所有批次完成”，建议按这个口径：

### 第 1 轮完成标准
- shell 公共态统一
- 设置页骨架统一

> 这一轮已经完成。

### 第 2 轮完成标准
- 所有典型 detail / panel / drawer 页面，不再是“裸 ListView + 原生 Card + Center(Text失败态)”组合
- 至少吃到 `MesSectionCard / MesEmptyState / MesErrorState` 之一

> 当前未完成。

### 第 3 轮完成标准
- 主要模块内的 loading / empty / banner / spacing 无明显断点
- grep 扫出的明显旧式可见壳层已处理到可接受程度

> 当前未完成。

### 第 4 轮完成标准
- 只剩少数刻意保留的特殊视觉组件
- 不再存在一眼可见的“老页面 / 新页面风格断裂”

> 当前未完成。

---

## 8. 继续接手时的注意事项
1. **不要过度抽象**
   - 用户明确偏好：只做当前任务需要的收敛，不要为了“未来可能复用”再造一层 helper

2. **优先复用既有 pattern**
   - `MesSectionCard`
   - `MesInlineBanner`
   - `MesEmptyState`
   - `MesErrorState`
   - `MesLoadingState`

3. **避免把所有自定义视觉都硬改成同一种卡片**
   - 如账号中心 overview hero、设备风险提示等，可能保留业务特化视觉更合适

4. **每改完一批就跑 analyze**
   - 当前会话里已经出现过多次“先加 import，再因尚未真正落地使用而触发 unused import warning”的情况
   - 所以每次做完一小批都要及时 `flutter analyze` 兜底

---

## 9. 建议你接手后先执行的命令
建议在项目根目录执行：

```bash
flutter analyze \
  frontend/lib/features/user/presentation/account_settings_page.dart \
  frontend/lib/features/equipment/presentation/equipment_detail_page.dart \
  frontend/lib/features/equipment/presentation/maintenance_execution_detail_page.dart \
  frontend/lib/features/equipment/presentation/maintenance_record_detail_page.dart
```

然后再继续处理：

```bash
flutter analyze \
  frontend/lib/features/production/presentation/production_repair_order_detail_page.dart \
  frontend/lib/features/production/presentation/production_scrap_statistics_detail_page.dart \
  frontend/lib/features/misc/presentation/first_article_disposition_page.dart
```

最后做一次 grep 扫尾。

---

## 10. 一句话总结
目前：**第 1 轮完成；第 2 轮做了一半；第 3、4 轮还没正式收口。**

最重要的接手点：
- 先收 `account_settings_page.dart`
- 再收 `equipment_detail_page.dart`
- 然后补 production 两个 detail 页 + 首件处置页
- 最后再做一轮 grep 驱动扫尾

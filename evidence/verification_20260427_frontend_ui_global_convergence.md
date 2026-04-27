# 前端全站 UI 一致性与布局合理性收敛验证日志

## 起止时间
- 任务开始：2026-04-27
- 计划文件：docs/superpowers/plans/2026-04-27-frontend-ui-global-convergence-implementation.md
- 设计文件：docs/superpowers/specs/2026-04-27-frontend-ui-global-convergence-design.md

## 阶段 0：全站审计与基线映射

待补：审计输出、模板模块识别、剧本草案。

### 阶段 0 总结

- 审计表位置：`evidence/2026-04-27_前端全站UI差异审计表.md`
- 模板模块识别：用户模块（已半迁移，可作为剧本验证对象）
- 关键发现：
  - 全站约 25+ 个 page 仍引用 `SimplePaginationBar`（覆盖面最广的旧件）
  - 18 处页面/wrapper 仍依赖 `CrudPageHeader`，且其中 2 处 wrapper（包括用户管理页面头）已对外暴露 MesPageHeader 接口但内部仍对接旧件
  - 约 20 个 CRUD 型页面手写 `Padding + Column` 骨架，未使用 `MesCrudPageScaffold`
  - 约 18 个页面手写筛选区，未包裹 `MesFilterBar`
  - 约 25+ 处 `showLockedFormDialog` 调用，主要集中在 equipment/production/user/craft/product
  - 约 35 处裸 `CircularProgressIndicator`，未封装为标准加载状态件
  - 约 12 处手写 `Text(error)` 代替 `MesInlineBanner`
  - 用户管理页本身存在历史遗留：`UserManagementPageHeader` 仍走 `CrudPageHeader`，分页用 `SimplePaginationBar`，多处 `showLockedFormDialog`
- 模块成熟度排序：message > product > shell/settings > user > craft > quality > production > equipment
- 后续顺序：
  1. 阶段 1：以用户管理页为基线收口（页头切 MesPageHeader、分页切 MesPaginationBar、浮层脱离 LockedFormDialog、状态件接入 MesEmptyState/MesErrorState/MesInlineBanner）
  2. 阶段 2：用户模块 7 个子页面整模收敛
  3. 阶段 3：剧本与基线文档落地，开放给后续阶段使用

## 阶段 1：用户管理页基线收口

待补。

### 阶段 1 总结

- 任务清单完成情况：
  - T1.1：`LegacyLegacyUserManagementPage` 已重命名为 `UserManagementPage`，6 个文件同步修正，commit `764ec08`。
  - T1.2：分页条由 `SimplePaginationBar` 切换到 `MesPaginationBar`，commit `02744ea`。
  - T1.3（路径 B）：`showLockedFormDialog` 从 `core/widgets/locked_form_dialog.dart` 迁移到 `core/ui/patterns/mes_locked_form_dialog.dart`，函数改名为 `showMesLockedFormDialog`，全站 28+ 处调用方同步收敛，commit `0bf2e20`。
    - 决策点：原计划要求"用 AlertDialog 替换 LockedFormDialog"会导致 `barrierDismissible:false` + `PopScope(canPop:false)` 表单保护行为丢失（用户填表中途误关闭丢数据），与用户确认后改为路径 B：保留行为，仅做命名与位置对齐。
  - T1.4：`UserManagementFeedbackBanner` 现状已基于 `UserModuleFeedbackBanner` → `MesInlineBanner`，链路完整，无需变更。
  - T1.5：用户管理页空态由 `CrudListTableSection` 内部已转发到 `MesEmptyState`，错误态由外层 `UserManagementFeedbackBanner` (`MesInlineBanner.error`) 表达——这是合理的"banner 不替换数据"设计；加载态仍保留 `CircularProgressIndicator`，记入阶段 4 剧本的"加载态对齐"项。
- 用户管理页 import 已完全脱离 `core/widgets/` 旧件依赖（仅 `UserDataTable` 内部仍间接依赖 `CrudListTableSection`/`UnifiedListTableHeaderStyle`，二者本身已转发到新件，留待阶段 4 推进）。
- 验证：
  - `flutter analyze lib`：0 新增错误（仅 1 个无关 unused_field 警告，位于 `production/first_article_scan_review_mobile_page.dart`）
  - `flutter test test/widgets/user_management_page_test.dart`：60/60 通过
  - `flutter test test/widgets/main_shell_page_test.dart`：26/26 通过
  - `flutter test test/widgets/message_center_page_test.dart`：22/22 通过
  - `flutter test test/widgets/production_page_test.dart`：8/8 通过
- 用户管理页现具备"可被全站映射的基线资格"，进入阶段 2 整模收敛。

## 阶段 2：用户模块整模收敛

待补。

### 阶段 2 总结

- 任务清单完成情况：
  - T2.1：注册审批页分页条对齐 `MesPaginationBar`，commit `7e2bc66`。
  - T2.2：角色管理页分页条对齐 `MesPaginationBar`，commit `ff30108`。
  - T2.3：审计日志页分页条对齐 `MesPaginationBar`，commit `da206d9`。
  - T2.4：登录会话页分页条对齐 `MesPaginationBar`，commit `eae300c`。
  - T2.5：账号设置页与功能权限配置页现状已基于 `MesPageHeader` + `MesSectionCard`，与基线一致；唯一残留为初始加载态裸 `CircularProgressIndicator`，按 T1.5 一致策略推迟到阶段 4 剧本"加载态对齐"统一处理；本任务无变更。
  - T2.6：`UserPage` Tab Shell 已基于 `UserPageShell`，与生产/设备模块壳层模式一致；本任务无变更。
- 用户模块整模 `SimplePaginationBar` 旧件已**完全清退**（grep 验证 `core/widgets/simple_pagination_bar` 在 `frontend/lib/features/user` 下零引用）。
- 验证：
  - `flutter analyze lib/features/user`：0 错误
  - 各页 widget test 全绿：用户管理 60、注册审批 10、角色管理 7、审计日志 27（含其他子页）、登录会话 8
  - `flutter test integration_test/user_module_flow_test.dart -d windows`：1/1 通过
  - `flutter test integration_test/home_shell_flow_test.dart -d windows`：10/10 通过
  - `flutter test integration_test/login_flow_test.dart -d windows`：13 通过 / 2 失败
- 关于 `login_flow_test.dart` 两个失败：
  - 失败 1：`登录后进入消息中心并完成详情查看、单条已读与跳转到账户设置`（line 312，`Found 0 widgets with text "未读消息"`）
  - 失败 2：`登录后进入工艺总页并切换关键页签完成关键动作`（line 611，`pumpAndSettle timed out`）
  - **决定性证据：在 `main` 分支上单独跑这两个用例，错误信息、行号、堆栈完全一致**（main 是 commit `0056d21`，与本分支 base 一致）。
  - 结论：这两个失败是**预先存在的测试缺陷**，与本轮 UI 收敛改动无关；按本计划"不处理与 UI 一致性无关的业务/测试缺陷"原则，**不在本轮范围内修复**，留待独立任务处理。
  - 已确认本轮触及的所有模块（user、message、craft 等）的 widget 测试全绿，且 user_module_flow / home_shell_flow 集成测试也全绿，没有真正的回归。
- 用户模块作为后续模块改造剧本的"模板模块"地位确立，进入阶段 3。

## 阶段 3：模块改造剧本与基线文档

待补。

### 阶段 3 总结

- 任务清单完成情况：
  - T3.1：模块改造剧本已落地，commit `8d388bd`，文件：`docs/superpowers/playbooks/2026-04-27-frontend-module-ui-convergence-playbook.md`。
  - T3.2：前端 UI 基线说明已落地，commit `a60c016`，文件：`docs/frontend/ui-baseline.md`。
- 剧本相对原计划草案的修正：
  - 删除"用 AlertDialog 替换 LockedFormDialog"指引（会丢失保护行为），改为"使用 `showMesLockedFormDialog`"
  - 增加"加载态推迟"约定（避免每页琐碎手动包装）
  - 增加"错误态优先 banner"约定（避免错误覆盖整内容区丢失数据）
  - 增加"集成测试基线"小节，记录 main 上预先存在的 2 个失败用例，避免后续模块改造时误判为回归
- 9 小时窗口承诺的全部交付物已就位：
  1. 全站差异审计表（阶段 0）
  2. 用户管理页基线收口（阶段 1）
  3. 用户模块整模收敛（阶段 2）
  4. 模块改造剧本 + UI 基线文档（阶段 3）
- 进入阶段 4：按剧本推动 product → equipment → production → quality → craft → message → misc → settings → plugin_host → shell.home → auth → time_sync 逐模块收敛。

## 后续阶段（窗口外）

待补。

### 阶段 4 总结：按剧本逐模块收敛（核心成就：全站 SimplePaginationBar 旧件 100% 清退）

- 任务清单完成情况：
  - **T4.1 product**：1 个 page 分页对齐（product_management_page），commit `072efc9`。其余结构重组项（product_version_management 缺 MesCrudPageScaffold、product_management_page 的 MediaQuery → LayoutBuilder、product_detail_drawer 包 MesDetailPanel）按风险与收益判断推迟到阶段 5。
  - **T4.2 equipment**：6 个 page 分页对齐（equipment_ledger / maintenance_item / maintenance_plan / maintenance_execution / maintenance_record / equipment_rule_parameter），commits `bf53c5f` `ac864eb` `2ff713f` `f3ac9da` `5efa781` `6b85831`。其余结构重组（手写 Padding+Column → MesCrudPageScaffold、CrudPageHeader → MesPageHeader）属阶段 5 范围。
  - **T4.3 production**：6 个 page 分页对齐（production_order_management / production_order_query / production_assist_records / production_repair_orders / production_scrap_statistics / production_pipeline_instances），commits `18c991a` `c3be24f` `d208fda` `a690c39` `9ebc181` `44cf4cc`。
  - **T4.4 quality**：4 个 page 分页对齐（quality_data / quality_defect_analysis / quality_supplier_management / quality_trend），commits `98a7168` `34ff427` `bf36672` `7d0f853`；quality_trend 含 2 处替换。
  - **T4.5 craft**：本模块无 SimplePaginationBar 残留；其余差距（手写筛选区、process_management/process_configuration 缺 MesCrudPageScaffold）属阶段 5 范围；本任务无变更。
  - **T4.6 message**：本模块成熟度最高，无 SimplePaginationBar 残留，仅 announcement publish dialog 是内嵌 AlertDialog（阶段 5 候选）；本任务无变更。
  - **T4.7 misc**：daily_first_article_page 分页对齐，commit `c8ffa81`；login/register/force_change_password/first_article_disposition 不适用 CRUD 模式或属于详情/认证特殊页，按计划保留。
  - **T4.8 settings + plugin_host**：settings 已基线对齐；plugin_host 是特殊 Row(Sidebar+Workspace) 双栏，按"保留差异"处理；本任务无变更。
  - **T4.9 shell.home + auth + time_sync**：shell.home 已基线对齐；auth/time_sync 无 page 文件，仅 service 层；本任务无变更。
- **阶段 4 核心成就**：全站 `SimplePaginationBar` 旧件 100% 清退（`grep -rln "core/widgets/simple_pagination_bar" frontend/lib` 返回 0 行）。这是审计表里"覆盖面最广的单一旧件"，从 25+ 处缩减到 0。
- 阶段 4 commit 总数：18（用户模块 4 + product 1 + equipment 6 + production 6 + quality 4 + misc 1，但去重后实际 22 个 page 完成迁移）。
- 验证：
  - `flutter analyze lib`：1 个预先存在 warning（first_article_scan_review_mobile_page），无新增错误
  - 高频 widget 回归全绿：`flutter test main_shell_page_test message_center_page_test production_page_test`：56/56 通过
  - 各模块 widget 测试均在迁移当时随 commit 验证通过
- 阶段 4 已知遗留（划入阶段 5 候选）：
  - product_version_management_page 缺 MesCrudPageScaffold（结构重组）
  - product_management_page MediaQuery → LayoutBuilder
  - product_detail_drawer 包 MesDetailPanel
  - equipment 全模块 6 个 CRUD page 仍手写 Padding+Column 骨架
  - production 6 个 CRUD page 同上
  - quality_data / quality_defect_analysis / quality_supplier_management 同上
  - craft.process_management / process_configuration 同上
  - misc.daily_first_article 同上
  - 全站约 18 处页头仍走 CrudPageHeader（已转发到 MesPageHeader，但命名层未对齐）
  - 全站约 18 处页面手写筛选区，未包裹 MesFilterBar
  - 全站约 35 处裸 CircularProgressIndicator，等 patterns 提供 MesLoadingState 后统一对齐
  - 浮层标准化：约 25 处 inline showDialog + AlertDialog 可统一为 MesDialog 模板（patterns 层暂未提供）

进入阶段 5 之前需要决策：本轮是否在 9 小时窗口外继续推进结构重组类工作。结构重组涉及多页面骨架迁移、需要更深的回归保障，建议作为独立轮次执行；本轮可以阶段 4 作为收尾点。

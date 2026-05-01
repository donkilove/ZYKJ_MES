# 任务日志：生产数据页功能裁剪

## 基本信息
- 日期：2026-04-04
- 任务：按用户要求裁剪生产数据相关页面
- 目标：
  1. 删除“手动筛选”页
  2. 将“今日实时产量”独立为生产模块顶部页签
  3. 保留“工序统计”为主页
  4. 将“人员统计”独立为生产模块顶部页签
  5. 删除统计卡“订单总数”“计划总量”
  6. 移除“未完工进度”

## 前置假设
- A1：用户要求的“独立为一页”以生产模块顶部独立页签实现即可，无需新增侧边栏模块。
- A2：为避免影响现有角色可见性，本次优先复用现有 `production_data_query` 可见权限，在前端派生新增顶部页签，不新增后端权限模型。

## 执行记录
- R1：已定位前端主文件 `frontend/lib/pages/production_page.dart` 与 `frontend/lib/pages/production_data_page.dart`。
- R2：确认当前“生产数据”页内部仍有二级 `TabBar`，包含“今日实时产量 / 未完工进度 / 手动筛选 / 工序统计 / 人员统计”。
- R3：确认生产模块顶部页签来自 `ProductionPage`，可通过前端本地扩展现有 `production_data_query` 页签实现新拆分结构。
- R4：已将 `production_data_query` 重定义为“工序统计”，并在生产模块顶部页签中派生“今日实时产量”“人员统计”两个独立入口。
- R5：已重写 `frontend/lib/pages/production_data_page.dart`，删除“手动筛选”“未完工进度”页面主体，仅保留工序统计、今日实时产量、人员统计三个独立视图。
- R6：已删除统计卡“订单总数”“计划总量”，当前仅保留“待生产 / 生产中 / 生产完成 / 完成总量”。
- R7：已补充并更新 Flutter 组件测试，覆盖裁剪后的单页渲染与顶部页签展开逻辑。

## 证据
- E1：`frontend/lib/pages/production_data_page.dart` 中现有内部页签与统计卡配置。
- E2：`frontend/lib/pages/production_page.dart` 中现有生产模块顶部页签组装逻辑。
- E3：`frontend/test/widgets/production_data_page_test.dart` 已验证三个独立视图的单页渲染。
- E4：`frontend/test/widgets/production_page_test.dart` 已验证生产模块会将原“生产数据”入口展开为三个顶部页签。

## 验证命令与结果
- V1：`dart format "frontend/lib/pages/production_data_page.dart" "frontend/lib/pages/production_page.dart" "frontend/test/widgets/production_data_page_test.dart" "frontend/test/widgets/production_page_test.dart"`
  结果：通过。
- V2：`flutter test test/widgets/production_data_page_test.dart test/widgets/production_page_test.dart`
  结果：通过，`All tests passed!`。

## 最终结论
- C1：已按用户要求完成生产数据页功能裁剪。
- C2：本次未新增后端权限与页面目录编码，改为复用现有 `production_data_query` 可见权限，在前端派生两个独立顶部页签，以降低对现网角色配置的影响。
- C3：无迁移，直接替换。

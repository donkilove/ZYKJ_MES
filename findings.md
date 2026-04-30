# 发现记录：核实 DeepSeek V4 PRO 项目检查结果

## 记录规则

- 只记录当前仓库中的真实证据。
- 外部报告仅作为待验证假设，不直接作为结论。
- 结论类型：成立、部分成立、误报、未核足。

## 当前发现

- 模块文件存在：用户、产品、工艺、品质、生产、设备模块均在 `frontend/lib/features/` 下有对应 service/model/presentation 文件。
- 报告点名的疑似死代码文件存在：`user_management_action_bar.dart`、`craft_page_header.dart`、`equipment_page_header.dart`、`product_parameter_editor_table.dart`、`product_parameter_editor_row_model.dart`。
- 测试文件存在性与报告有出入：当前仓库已有 `production_order_form_page_test.dart`、`production_order_detail_page_test.dart` 等生产模块 widget 测试；报告中“缺少 production_order_form_page.dart 测试”需复核，可能是误报或旧版本结论。

## 用户模块

- 成立：`user_service.dart` 中大量 `http.*` 调用直接 `await ...timeout(...)`，服务层仅做响应状态处理，没有统一包裹网络异常。
- 成立：`approveRegistrationRequest`、`createUser`、`updateUser` 返回 `Future<void>`。
- 部分成立：`listAllRoles`、`listProcesses` 用 `pageSize = 200` 循环拉全量，不是“无分页参数”，但确实对调用方表现为全量拉取。
- 成立：`user_management_action_bar.dart` 在 `frontend/lib` 中只有自身定义，无业务引用。
- 成立：报告列出的 `catch (_)` 在用户模块存在，但 `account_settings_page.dart` 当前额外还有 206 行一处空 catch。
- 成立：角色码在多个文件中硬编码，包括 `system_admin`、`operator`、`maintenance_staff`。
- 成立：审计日志 before/after 通过 `entries.map(...).join(', ')` 展示，无详情展开。
- 部分成立：密码重置有客户端校验，但强度很弱，仅校验非空、长度 6、连续 4 位相同字符。
- 成立：`UserDataTable` 不接收父组件传入的 `_roleLabelForUser` / `_stageLabelForUser`，直接使用 `user.roleName`/`user.stageName`。

## 产品模块

- 成立：`createProduct` 与 `deleteProductVersion` 返回 `Future<void>`。
- 成立：三个导出方法返回 `Future<List<int>>`，即 `response.bodyBytes`。
- 成立：`listProductParameters` 未指定 `version` 且 `effectiveOnly=false` 时抛 `ArgumentError`。
- 成立：`ProductParameterItem` 当前没有 `id` 字段。
- 成立：`product_page.dart:439` 与 `product_version_management_page.dart:110` 存在静默 `catch (_)`。
- 误报：`ProductParameterEditorTable` 和 `ProductParameterEditorRowModel` 不是死代码，`product_parameter_management_page.dart` 正在使用。
- 成立：产品列表版本显示使用 `V1.${product.currentVersion - 1}`，未直接用 `product.currentVersionLabel`。
- 部分成立：删除版本有确认对话框，但不要求输入密码；删除产品要求密码。
- 成立：产品分类选项在多处硬编码，不止两处。
- 未复现：报告中的 `_filteredVersionRows` / `_filteredProducts` getter 在当前仓库未检出，疑似旧版本结论。

## 工艺模块

- 成立：`craft_models.dart` 有多处 `DateTime.parse(json[...] as String)`，空值会抛异常。
- 成立：`craft_service.dart` 的 `_decodeBody` 捕获 JSON 异常后返回 `{'detail': response.body}`。
- 成立：`template_form_dialog.dart` 与 `system_master_template_form_dialog.dart` 在 `build()` 的 itemBuilder 中直接修改 `step.processId`。
- 成立：`template_version_dialog.dart` 使用 `(step as dynamic)` 访问属性。
- 成立：工段/工序启停直接调用更新接口，没有确认对话框。
- 成立：归档/取消归档/回滚 service 方法存在，presentation 未检出调用。
- 成立：版本弹窗映射 `steps: const []`，历史版本步骤不展示。
- 成立：删除前引用加载失败只处理未授权，其余异常吞掉后继续弹删除确认。
- 成立：多处 `pageSize: 500` 和 `Duration(seconds: 30)` 硬编码。
- 部分成立：`craft_page_header.dart` 在 `frontend/lib` 无引用，但测试中直接渲染。

## 品质模块

- 成立：`quality_data_page.dart:144` 存在静默吞 JSON 解析错误。
- 部分成立：`quality_trend_page.dart` 用 `Future.wait<Object>` 后强转 5 个结果；正常 Future 失败会进入 catch，不会因“任一失败”直接 TypeError，但返回类型漂移会 TypeError。
- 成立：供应商 service 支持 keyword/enabled，但页面调用 `listSuppliers()`，无分页参数、无搜索/筛选 UI。
- 误报：`quality_models.dart` 当前使用 `_parseDateTimeOrNull`，不是“所有 DateTime.parse 无空安全”。
- 成立：品质数据页 5 个统计 API 串行 await。
- 成立：`submitDisposition` 的 `operator_` 参数未使用。
- 成立：模型存在 fallback 链和 `DateTime(1970, 1, 1)` 哨兵值。
- 成立：缺陷分析页错误横幅和 `_result == null` 时“暂无数据”可同时出现。
- 成立：趋势图数据点少于 2 时返回 `SizedBox.shrink()`；缺陷标签超过 6 字符截断。

## 生产模块

- 成立：生产模块当前检出 9 处 `catch (_)`，与报告数量一致。
- 成立：`production_order_query_page.dart:176` 使用 `item.userCompletedQuantity ?? item.processCompletedQuantity`；若业务语义要求 `0` 代表未填或无效，则确实会错误显示 0。若 `0` 是有效完成量，则这是业务争议项。
- 部分成立：`production_models.dart` 同时有 `_parseDateOrNull` 和多处 `DateTime.parse`；“公开顶级函数但未导出”的说法不准确，Dart 下划线顶级函数本来就是库私有，不属于公开 API。
- 部分成立：`createOrder/updateOrder` 当前约 13/12 个命名参数，不是报告的 20+，但确实参数偏多，适合收敛成 payload 对象。
- 成立：`_fieldLabelForValidation` 中存在英文标签，如 `Order Process`、`Pipeline Instance`、`Target Operator`。
- 成立：大量 timeout、pageSize、DatePicker 范围硬编码存在。
- 成立：`production_order_form_page.dart` 使用 `ReorderableListView.builder + shrinkWrap: true + NeverScrollableScrollPhysics()`。
- 成立：`_DefectRowDraft` 在 `production_end_production_dialog.dart` 和 `production_manual_repair_dialog.dart` 重复定义。
- 误报/旧版本：当前已有 `production_order_form_page_test.dart`；没有单独的 `production_repair_order_detail_page_test.dart` 和 `production_scrap_statistics_detail_page_test.dart`，但存在覆盖维修/报废页的 `production_repair_scrap_pages_test.dart`。
- 成立：导出按钮直接执行导出，未见确认对话框。
- 成立：`production_data_page.dart` 由 `ProductionDataSection` 三枚举分支驱动，扩展需要改 enum/switch。

## 设备模块

- 成立：设备模块当前检出 6 处 `catch (_)`，与报告数量一致。
- 成立：`createEquipmentRule` 与 `createRuntimeParameter` 是 POST 创建，但校验 `response.statusCode != 200`，报告所称 200/201 风险成立。
- 成立：`equipment_models.dart` 有 30+ 处 `DateTime.parse(json[...] as String)`。
- 成立：设备服务中大量增删改操作返回 `Future<void>`。
- 成立：`equipment_service.dart` 存在英文错误消息 `Request failed ($statusCode)`。
- 部分成立：规则/参数/计划启停和开始执行缺少确认；设备台账启停、保养项目启停已有确认。
- 成立：规则/参数 toggle 用 PATCH，设备/保养项目/计划 toggle 用 POST，HTTP 方法不一致。
- 成立：保养计划页无关键词搜索，只有多个下拉筛选。
- 成立：保养计划筛选下拉只 setState，不触发 `_loadAll(page: 1)`；需要点“查询”。
- 部分成立：`equipment_page_header.dart` 在 `frontend/lib` 无引用，但测试中直接渲染。
- 成立：保养分类在表单与页面筛选中硬编码。
- 成立：`maintenance_plan_form_dialog.dart` 对空 options 使用 `.first`，空列表会崩溃。
- 成立：保养执行详情页和保养记录详情页加载失败时用 `MesEmptyState`，无重试按钮。
- 成立：`maintenance_record_page.dart` 串行加载设备列表和负责人。
- 成立：`_applyRuleScopeAfterFrame` 最多重试 5 次后静默停止。

## 跨模块统计与修正

- 成立：跨模块 `catch (_)` 问题显著存在；当前六模块检出 26 处（含 craft presentation 2 处和 service 1 处）。
- 成立：`DateTime.parse` 空安全风险集中在产品、工艺、生产、设备模型；品质模型当前已改为 `_parseDateTimeOrNull`，报告把品质列为严重空安全问题属于误报或旧版本结论。
- 成立：硬编码超时、pageSize、选项值普遍存在。
- 成立：网络层普遍没有统一 try-catch/异常归一封装，主要靠 HTTP 状态码处理。
- 误报：产品参数编辑表格/行模型不是死代码；生产订单表单测试并不缺失；产品 `_filtered*` getter 当前不存在。
- 失败重试：曾使用 Bash 风格 `{user,product}` 路径展开，PowerShell 报 `Missing argument in parameter list`；已改为显式路径重跑成功。

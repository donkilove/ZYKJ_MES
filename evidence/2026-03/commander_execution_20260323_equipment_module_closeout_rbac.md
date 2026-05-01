# 指挥官任务日志：设备模块补齐收口 RBAC 回归修复（2026-03-23）

## 1. 任务信息

- 任务名称：设备模块补齐收口，修复 owners 候选权限回归
- 执行身份：执行子 agent
- 执行时间：2026-03-23
- 当前状态：已完成代码修改与最低验证
- 工具降级：当前会话无 `Sequential Thinking`、`update_plan`，改为书面拆解 + `evidence/` 留痕；补偿措施为在日志中记录拆解、改动与验证结论

## 2. 书面拆解

1. 先确认 `/equipment/owners` 当前依赖的 action 权限、父页面归属与 capability 绑定关系。
2. 再将计划默认执行人与记录执行人筛选拆成各自受控的候选权限，避免继续绑定到台账页。
3. 同步后端依赖、前端权限常量与页面回归测试，确保接口与页面加载链路一致。
4. 最后执行设备相关后端 unittest、前端 tests、`flutter analyze` 与 `compileall`。

## 3. 关键改动

- 后端新增 `equipment.plan_owner_options.list` 与 `equipment.record_executor_options.list`，分别挂到 `maintenance_plan` 与 `maintenance_record` 页面。
- `/equipment/owners` 改为接受“台账负责人选项 / 计划默认执行人候选 / 记录执行人筛选候选”三类权限之一，不再只认台账管理权限。
- `feature.equipment.plans.manage` 与 `feature.equipment.records.view` 分别联动新的 action 权限，保持最小授权边界。
- 前端补充设备权限常量，并在 widget 测试中校验计划页会主动拉取候选、记录页在有候选时展示执行人筛选器。

## 4. 验证记录

- `./.venv/Scripts/python.exe -m unittest backend.tests.test_equipment_module_integration`
  - 结果：失败
  - 关键观察：本地数据库缺少 `mes_maintenance_record.source_execution_process_code` 列，且自动生成审计历史存在脏数据，导致既有 4 个设备集成用例失败；本次新增 RBAC 用例不受影响。
- `./.venv/Scripts/python.exe -m unittest backend.tests.test_equipment_module_integration.EquipmentModuleIntegrationTest.test_owner_option_permissions_follow_plan_and_record_features`
  - 结果：通过，`Ran 1 test ... OK`
- `flutter test frontend/test/services/equipment_service_test.dart frontend/test/widgets/equipment_module_pages_test.dart frontend/test/widgets/maintenance_record_page_test.dart`
  - 结果：通过，`All tests passed!`
- `flutter analyze`
  - 结果：失败
  - 关键观察：仓库现有 `frontend/lib/pages/craft_reference_analysis_page.dart` 存在 4 个未定义 getter 报错，另有 `frontend/lib/pages/process_configuration_page.dart` 1 个已有 info；与本次设备 RBAC 变更无直接关联。
- `flutter analyze lib/models/authz_models.dart test/widgets/equipment_module_pages_test.dart test/widgets/maintenance_record_page_test.dart`
  - 结果：通过，`No issues found!`
- `./.venv/Scripts/python.exe -m compileall backend/app`
  - 结果：通过

## 5. 风险与结论

- 当前修复采用新增最小 action 权限 + 多权限准入，不会把 owners 候选接口无限开放给无关角色。
- 若历史角色曾被直接授予旧的 `equipment.admin_owners.list`，原行为保持兼容；新配置建议改用计划/记录对应 capability。

# 入口导航

> 自动生成，基于治理后图谱

## 后端入口

- `lifespan()` — `backend\app\main.py` — 域:`backend-core`
- `health()` — `backend\app\main.py` — 域:`backend-core`
- `run_worker()` — `backend\app\worker_main.py` — 域:`backend-core`
- `main()` — `backend\app\worker_main.py` — 域:`backend-core`
- `_backend_root()` — `backend\app\bootstrap\startup_bootstrap.py` — 域:`backend-core`

## 前端入口

- `MesClientApp` — `frontend\lib\main.dart` — 域:`frontend-core`
- `AppBootstrapPage` — `frontend\lib\main.dart` — 域:`frontend-core`
- `_AppBootstrapPageState` — `frontend\lib\main.dart` — 域:`frontend-core`
- `bootstrapSoftwareSettingsController` — `frontend\lib\main.dart` — 域:`frontend-core`
- `ListenableBuilder` — `frontend\lib\main.dart` — 域:`frontend-core`

## 脚本入口

- `load_env_file()` — `start_backend.py` — 域:`unknown`
- `build_compose_env()` — `start_backend.py` — 域:`unknown`
- `normalize_setting_value()` — `start_backend.py` — 域:`unknown`
- `resolve_sensitive_env_value()` — `start_backend.py` — 域:`unknown`
- `ensure_compose_sensitive_env_secure()` — `start_backend.py` — 域:`unknown`
- `resolve_flutter()` — `start_frontend.py` — 域:`unknown`
- `SmokeContext` — `tools\docker_backend_smoke.py` — 域:`infrastructure`
- `add_edge()` — `tools\enrich_graph.py` — 域:`infrastructure`
- `_load_json()` — `tools\graphify_curate.py` — 域:`infrastructure`
- `_load_json()` — `tools\graphify_navigation.py` — 域:`infrastructure`
- `_ensure_staging_dirs()` — `tools\graphify_pipeline.py` — 域:`infrastructure`
- `_print_error()` — `tools\project_toolkit.py` — 域:`infrastructure`
- `check()` — `tools\verify_governance.py` — 域:`infrastructure`
- `ScenarioSpec` — `tools\perf\backend_capacity_gate.py` — 域:`infrastructure`
- `Performance tooling helpers.` — `tools\perf\__init__.py` — 域:`infrastructure`
- `ScenarioResult` — `tools\perf\write_gate\result_summary.py` — 域:`infrastructure`
- `load_sample_context()` — `tools\perf\write_gate\sample_context.py` — 域:`infrastructure`
- `SampleContract` — `tools\perf\write_gate\sample_contract.py` — 域:`infrastructure`
- `_ensure_backend_import_path()` — `tools\perf\write_gate\sample_registry.py` — 域:`infrastructure`
- `SampleHandler` — `tools\perf\write_gate\sample_runtime.py` — 域:`infrastructure`

## 测试入口

- `ApiDepsUnitTest` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.setUp()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.tearDown()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.test_get_current_user_skips_commit_when_session_not_touched()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.test_get_current_user_rejects_invalid_session_before_loading_user()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `AppStartupWorkerSplitUnitTest` — `backend\tests\test_app_startup_worker_split.py` — 域:`tests`
- `AuthzCatalogUnitTest` — `backend\tests\test_authz_catalog_unit.py` — 域:`tests`
- `AuthzEndpointUnitTest` — `backend\tests\test_authz_endpoint_unit.py` — 域:`tests`
- `_FakeScalarResult` — `backend\tests\test_authz_service_unit.py` — 域:`tests`
- `_FakeScalarResult` — `backend\tests\test_authz_split_unit.py` — 域:`tests`
- `AuthEndpointUnitTest` — `backend\tests\test_auth_endpoint_unit.py` — 域:`tests`
- `BackendCapacityGateUnitTest` — `backend\tests\test_backend_capacity_gate_unit.py` — 域:`tests`
- `_FakeScalarResult` — `backend\tests\test_bootstrap_seed_service_unit.py` — 域:`tests`
- `CombinedAuthScenarioSuiteUnitTest` — `backend\tests\test_combined_auth_scenarios_unit.py` — 域:`tests`
- `CombinedEquipmentScenarioSuiteUnitTest` — `backend\tests\test_combined_equipment_scenarios_unit.py` — 域:`tests`
- `CombinedManagementScenarioSuiteUnitTest` — `backend\tests\test_combined_management_scenarios_unit.py` — 域:`tests`
- `CombinedProductsScenarioSuiteUnitTest` — `backend\tests\test_combined_products_scenarios_unit.py` — 域:`tests`
- `CombinedQualityScenarioSuiteUnitTest` — `backend\tests\test_combined_quality_scenarios_unit.py` — 域:`tests`
- `load_perf_sample_context()` — `backend\tests\test_craft_module_integration.py` — 域:`tests`
- `DbSessionConfigUnitTest` — `backend\tests\test_db_session_config_unit.py` — 域:`tests`

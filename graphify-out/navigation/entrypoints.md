# 入口导航

> 自动生成，基于治理后图谱

## 后端入口

- `main.py` — `backend\app\main.py` — 域:`backend-core`
- `lifespan()` — `backend\app\main.py` — 域:`backend-core`
- `health()` — `backend\app\main.py` — 域:`backend-core`
- `worker_main.py` — `backend\app\worker_main.py` — 域:`backend-core`
- `run_worker()` — `backend\app\worker_main.py` — 域:`backend-core`
- `main()` — `backend\app\worker_main.py` — 域:`backend-core`
- `api.py` — `backend\app\api\v1\api.py` — 域:`backend-core`
- `startup_bootstrap.py` — `backend\app\bootstrap\startup_bootstrap.py` — 域:`backend-core`
- `_backend_root()` — `backend\app\bootstrap\startup_bootstrap.py` — 域:`backend-core`
- `ensure_database_exists()` — `backend\app\bootstrap\startup_bootstrap.py` — 域:`backend-core`
- `run_alembic_upgrade()` — `backend\app\bootstrap\startup_bootstrap.py` — 域:`backend-core`
- `seed_startup_data()` — `backend\app\bootstrap\startup_bootstrap.py` — 域:`backend-core`
- `run_startup_bootstrap()` — `backend\app\bootstrap\startup_bootstrap.py` — 域:`backend-core`
- `__init__.py` — `backend\app\bootstrap\__init__.py` — 域:`backend-core`
- `Application startup bootstrap helpers.` — `backend\app\bootstrap\__init__.py` — 域:`backend-core`

## 前端入口

- `package:mes_client/features/misc/presentation/force_change_password_page.dart` — `frontend\lib\main.dart` — 域:`frontend-core`
- `main.dart` — `frontend\lib\main.dart` — 域:`frontend-core`
- `MesClientApp` — `frontend\lib\main.dart` — 域:`frontend-core`
- `AppBootstrapPage` — `frontend\lib\main.dart` — 域:`frontend-core`
- `_AppBootstrapPageState` — `frontend\lib\main.dart` — 域:`frontend-core`
- `bootstrapSoftwareSettingsController` — `frontend\lib\main.dart` — 域:`frontend-core`
- `ListenableBuilder` — `frontend\lib\main.dart` — 域:`frontend-core`
- `_startTokenMonitor` — `frontend\lib\main.dart` — 域:`frontend-core`
- `_stopTokenMonitor` — `frontend\lib\main.dart` — 域:`frontend-core`
- `_handleLoginSuccess` — `frontend\lib\main.dart` — 域:`frontend-core`
- `_handleTimeSyncChanged` — `frontend\lib\main.dart` — 域:`frontend-core`
- `LoginPage` — `frontend\lib\main.dart` — 域:`frontend-core`
- `ForceChangePasswordPage` — `frontend\lib\main.dart` — 域:`frontend-core`
- `MainShellPage` — `frontend\lib\main.dart` — 域:`frontend-core`
- `package:mes_client/features/auth/presentation/token_renewal_dialog.dart` — `frontend\lib\main.dart` — 域:`frontend-core`

## 脚本入口

- `start_backend.py` — `start_backend.py` — 域:`unknown`
- `load_env_file()` — `start_backend.py` — 域:`unknown`
- `build_compose_env()` — `start_backend.py` — 域:`unknown`
- `normalize_setting_value()` — `start_backend.py` — 域:`unknown`
- `resolve_sensitive_env_value()` — `start_backend.py` — 域:`unknown`
- `ensure_compose_sensitive_env_secure()` — `start_backend.py` — 域:`unknown`
- `parse_args()` — `start_backend.py` — 域:`unknown`
- `build_db_expose_override()` — `start_backend.py` — 域:`unknown`
- `write_db_expose_override()` — `start_backend.py` — 域:`unknown`
- `build_compose_command()` — `start_backend.py` — 域:`unknown`
- `require_docker()` — `start_backend.py` — 域:`unknown`
- `run_compose()` — `start_backend.py` — 域:`unknown`
- `can_connect()` — `start_backend.py` — 域:`unknown`
- `wait_for_port()` — `start_backend.py` — 域:`unknown`
- `print_start_summary()` — `start_backend.py` — 域:`unknown`
- `resolve_backend_http_port()` — `start_backend.py` — 域:`unknown`
- `print_compose_result()` — `start_backend.py` — 域:`unknown`
- `resolve_compose_files()` — `start_backend.py` — 域:`unknown`
- `run_simple_action()` — `start_backend.py` — 域:`unknown`
- `run_up_action()` — `start_backend.py` — 域:`unknown`

## 测试入口

- `test_api_deps_unit.py` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `ApiDepsUnitTest` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.setUp()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.tearDown()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.test_get_current_user_skips_commit_when_session_not_touched()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.test_get_current_user_rejects_invalid_session_before_loading_user()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.test_require_permission_fast_reuses_session_permission_decision_cache()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.test_allow_auth_user_cache_allows_generic_gets_but_excludes_equipment()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `.test_sync_permission_decision_caches_with_generation_clears_local_entries()` — `backend\tests\test_api_deps_unit.py` — 域:`tests`
- `test_app_startup_worker_split.py` — `backend\tests\test_app_startup_worker_split.py` — 域:`tests`
- `AppStartupWorkerSplitUnitTest` — `backend\tests\test_app_startup_worker_split.py` — 域:`tests`
- `.test_web_lifespan_rejects_insecure_runtime_settings()` — `backend\tests\test_app_startup_worker_split.py` — 域:`tests`
- `.test_web_lifespan_skips_bootstrap_and_background_loops_when_disabled()` — `backend\tests\test_app_startup_worker_split.py` — 域:`tests`
- `.test_worker_runs_bootstrap_and_background_loops_when_enabled()` — `backend\tests\test_app_startup_worker_split.py` — 域:`tests`
- `test_authz_catalog_unit.py` — `backend\tests\test_authz_catalog_unit.py` — 域:`tests`
- `AuthzCatalogUnitTest` — `backend\tests\test_authz_catalog_unit.py` — 域:`tests`
- `.test_quality_features_cover_trend_and_supplier_read_paths()` — `backend\tests\test_authz_catalog_unit.py` — 域:`tests`
- `.test_first_article_scan_review_permission_is_in_quality_catalog()` — `backend\tests\test_authz_catalog_unit.py` — 域:`tests`
- `test_authz_endpoint_unit.py` — `backend\tests\test_authz_endpoint_unit.py` — 域:`tests`
- `AuthzEndpointUnitTest` — `backend\tests\test_authz_endpoint_unit.py` — 域:`tests`

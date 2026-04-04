from app.core.authz_catalog import (
    PAGE_PERMISSION_BY_PAGE_CODE,
    PERM_PAGE_PRODUCTION_ASSIST_RECORDS_VIEW,
    PRODUCTION_PAGE_PERMISSION_BY_PAGE_CODE,
)
from app.core.authz_hierarchy_catalog import FEATURE_BY_PERMISSION_CODE
from app.core.page_catalog import (
    DEFAULT_VISIBLE_PAGES_BY_ROLE,
    PAGE_PRODUCTION_ASSIST_RECORDS,
)
from app.core.rbac import ROLE_PRODUCTION_ADMIN, ROLE_SYSTEM_ADMIN


def test_production_assist_records_catalogs_use_new_code() -> None:
    assert PAGE_PRODUCTION_ASSIST_RECORDS == "production_assist_records"
    assert (
        PAGE_PERMISSION_BY_PAGE_CODE[PAGE_PRODUCTION_ASSIST_RECORDS]
        == "page.production_assist_records.view"
    )
    assert (
        PRODUCTION_PAGE_PERMISSION_BY_PAGE_CODE[PAGE_PRODUCTION_ASSIST_RECORDS]
        == PERM_PAGE_PRODUCTION_ASSIST_RECORDS_VIEW
    )
    assert (
        FEATURE_BY_PERMISSION_CODE["feature.production.assist.records.view"].page_code
        == PAGE_PRODUCTION_ASSIST_RECORDS
    )


def test_production_assist_records_visible_for_system_and_production_admin() -> None:
    assert (
        PAGE_PRODUCTION_ASSIST_RECORDS
        in DEFAULT_VISIBLE_PAGES_BY_ROLE[ROLE_SYSTEM_ADMIN]
    )
    assert (
        PAGE_PRODUCTION_ASSIST_RECORDS
        in DEFAULT_VISIBLE_PAGES_BY_ROLE[ROLE_PRODUCTION_ADMIN]
    )

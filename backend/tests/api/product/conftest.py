from __future__ import annotations

import pytest
from sqlalchemy.orm import Session

from app.services import authz_service


@pytest.fixture(autouse=True)
def _ensure_product_authz_defaults(db_session: Session) -> None:
    authz_service.invalidate_permission_cache()
    authz_service._AUTHZ_DEFAULTS_READY = False
    authz_service.ensure_authz_defaults(db_session)
    db_session.commit()
    yield
    authz_service.invalidate_permission_cache()
    authz_service._AUTHZ_DEFAULTS_READY = False

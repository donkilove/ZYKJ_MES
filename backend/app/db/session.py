from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings


def _build_engine():
    database_url = settings.database_url
    engine_kwargs = {
        "pool_pre_ping": True,
        "future": True,
    }

    if make_url(database_url).get_backend_name() != "sqlite":
        engine_kwargs.update(
            pool_size=max(1, settings.db_pool_size),
            max_overflow=max(0, settings.db_max_overflow),
            pool_timeout=max(1, settings.db_pool_timeout_seconds),
            pool_recycle=max(1, settings.db_pool_recycle_seconds),
        )

    return create_engine(database_url, **engine_kwargs)


engine = _build_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine, expire_on_commit=False)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

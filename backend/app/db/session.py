from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings


engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
    pool_size=max(1, settings.db_pool_size),
    max_overflow=max(0, settings.db_max_overflow),
    pool_timeout=max(1, settings.db_pool_timeout_seconds),
    pool_recycle=max(1, settings.db_pool_recycle_seconds),
    future=True,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine, expire_on_commit=False)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

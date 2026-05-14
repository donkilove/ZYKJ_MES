from __future__ import annotations

import logging
from pathlib import Path

import psycopg2
from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from psycopg2 import sql
from psycopg2.errors import DuplicateDatabase

from app.core.config import ensure_runtime_settings_secure, settings
from app.db.session import SessionLocal
from app.services.bootstrap_seed_service import seed_initial_data


logger = logging.getLogger(__name__)


def _backend_root() -> Path:
    return Path(__file__).resolve().parents[2]


def ensure_database_exists() -> None:
    logger.info("[BOOTSTRAP] Checking database '%s'.", settings.db_name)
    connection = psycopg2.connect(
        host=settings.db_bootstrap_host,
        port=settings.db_bootstrap_port,
        user=settings.db_bootstrap_user,
        password=settings.db_bootstrap_password,
        dbname=settings.db_bootstrap_maintenance_db,
    )
    connection.autocommit = True
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (settings.db_user,))
            if cursor.fetchone() is None:
                raise RuntimeError(f"[BOOTSTRAP] Database role '{settings.db_user}' does not exist.")

            cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (settings.db_name,))
            if cursor.fetchone() is not None:
                logger.info("[BOOTSTRAP] Database '%s' already exists.", settings.db_name)
                return

            try:
                cursor.execute(
                    sql.SQL("CREATE DATABASE {} OWNER {} ENCODING 'UTF8' TEMPLATE template0").format(
                        sql.Identifier(settings.db_name),
                        sql.Identifier(settings.db_user),
                    )
                )
                logger.info("[BOOTSTRAP] Database '%s' created.", settings.db_name)
            except DuplicateDatabase:
                # Concurrent startup may create the database first.
                logger.info("[BOOTSTRAP] Database '%s' was created by another process.", settings.db_name)
    finally:
        connection.close()


def run_alembic_upgrade() -> None:
    backend_root = _backend_root()
    alembic_ini = backend_root / "alembic.ini"
    if not alembic_ini.exists():
        raise RuntimeError(f"[BOOTSTRAP] alembic.ini not found: {alembic_ini}")

    logger.info("[BOOTSTRAP] Running alembic upgrade heads.")
    config = Config(str(alembic_ini))
    config.set_main_option("script_location", str(backend_root / "alembic"))
    config.set_main_option("sqlalchemy.url", settings.database_url)
    # 禁止 alembic 重置日志配置（避免在 uvicorn lifespan 中吞掉异常）
    config.config_file_name = None
    heads = _validate_alembic_graph(config)
    command.upgrade(config, "heads")
    logger.info("[BOOTSTRAP] Alembic migration completed. heads=%s", ", ".join(heads))


def _validate_alembic_graph(config: Config) -> tuple[str, ...]:
    try:
        script = ScriptDirectory.from_config(config)
        heads = tuple(script.get_heads())
    except Exception as exc:
        raise RuntimeError(
            "[BOOTSTRAP] Alembic 迁移图损坏，可能存在重复 revision、循环依赖或无法解析的 heads。"
            f" 详细信息：{exc}"
        ) from exc

    if not heads:
        raise RuntimeError("[BOOTSTRAP] Alembic 迁移图损坏：未解析到任何 head。")

    logger.info("[BOOTSTRAP] Alembic graph validated. heads=%s", ", ".join(heads))
    return heads


def seed_startup_data() -> None:
    db = SessionLocal()
    try:
        result = seed_initial_data(
            db,
            admin_username=settings.bootstrap_admin_username,
            admin_password=settings.bootstrap_admin_password,
        )
    finally:
        db.close()

    logger.info(
        "[BOOTSTRAP] Seed completed. admin=%s, created=%s, role_repaired=%s",
        result.admin_username,
        result.admin_created,
        result.role_repaired,
    )


def run_startup_bootstrap() -> None:
    if not settings.bootstrap_on_startup:
        logger.info("[BOOTSTRAP] Startup bootstrap disabled by BOOTSTRAP_ON_STARTUP=false.")
        return

    logger.info("[BOOTSTRAP] Startup bootstrap begin.")
    try:
        ensure_runtime_settings_secure(require_bootstrap_password=True)
        ensure_database_exists()
        run_alembic_upgrade()
        seed_startup_data()
    except Exception:
        logger.exception("[BOOTSTRAP] Startup bootstrap failed.")
        raise
    logger.info("[BOOTSTRAP] Startup bootstrap done.")

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


INSECURE_JWT_SECRET_KEYS = frozenset({"", "replace_with_a_strong_secret"})
INSECURE_BOOTSTRAP_ADMIN_PASSWORDS = frozenset({"", "Admin@123456"})
INSECURE_PRODUCTION_DEFAULT_VERIFICATION_CODES = frozenset({"", "123456"})
DEFAULT_ENV_FILE = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    app_name: str = "ZYKJ MES API"
    app_env: str = "dev"
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    public_base_url: str = ""
    api_v1_prefix: str = "/api/v1"

    db_host: str = "127.0.0.1"
    db_port: int = 5432
    db_name: str = "mes_db"
    db_user: str = "mes_user"
    db_password: str = "mes_password"
    db_pool_size: int = 6
    db_max_overflow: int = 4
    db_pool_timeout_seconds: int = 5
    db_pool_recycle_seconds: int = 1800

    redis_host: str = "127.0.0.1"
    redis_port: int = 6379
    redis_db: int = 0
    redis_password: str = ""
    redis_ssl: bool = False
    redis_socket_timeout_seconds: float = 0.2
    redis_connect_timeout_seconds: float = 0.2
    authz_permission_cache_redis_enabled: bool = True
    authz_permission_cache_prefix: str = "authz:permission:v1"
    authz_permission_cache_ttl_seconds: int = 60

    bootstrap_on_startup: bool = True
    web_run_bootstrap: bool = True
    web_run_background_loops: bool = True
    worker_run_bootstrap: bool = True
    worker_run_background_loops: bool = True
    db_bootstrap_host: str = "127.0.0.1"
    db_bootstrap_port: int = 5432
    db_bootstrap_user: str = "postgres"
    db_bootstrap_password: str = ""
    db_bootstrap_maintenance_db: str = "postgres"

    bootstrap_admin_username: str = "admin"
    bootstrap_admin_password: str = "Admin@123456"
    online_status_ttl_seconds: int = 90
    session_touch_min_interval_seconds: int = 30
    session_max_seconds: int = 3600
    login_log_retention_days: int = 30
    maintenance_auto_generate_enabled: bool = True
    maintenance_auto_generate_time: str = "00:05"
    maintenance_auto_generate_timezone: str = "Asia/Shanghai"
    message_delivery_maintenance_enabled: bool = True
    message_delivery_maintenance_interval_seconds: int = 15
    message_delivery_pending_grace_seconds: int = 5
    production_default_verification_code: str = "123456"
    craft_auto_bind_default_template_enabled: bool = True

    jwt_secret_key: str = "replace_with_a_strong_secret"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 120

    model_config = SettingsConfigDict(
        env_file=str(DEFAULT_ENV_FILE),
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()


def _normalized_setting_value(value: str | None) -> str:
    return (value or "").strip()


def jwt_secret_is_secure() -> bool:
    return _normalized_setting_value(settings.jwt_secret_key) not in INSECURE_JWT_SECRET_KEYS


def bootstrap_admin_password_is_secure() -> bool:
    return (
        _normalized_setting_value(settings.bootstrap_admin_password)
        not in INSECURE_BOOTSTRAP_ADMIN_PASSWORDS
    )


def production_default_verification_code_is_secure() -> bool:
    return (
        _normalized_setting_value(settings.production_default_verification_code)
        not in INSECURE_PRODUCTION_DEFAULT_VERIFICATION_CODES
    )


def ensure_runtime_settings_secure(
    *,
    require_bootstrap_password: bool = False,
    require_verification_code: bool = False,
) -> None:
    errors: list[str] = []
    if not jwt_secret_is_secure():
        errors.append("JWT 密钥配置不安全，请显式设置 jwt_secret_key。")
    if require_bootstrap_password and not bootstrap_admin_password_is_secure():
        errors.append("管理员初始化口令配置不安全，请显式设置 bootstrap_admin_password。")
    if require_verification_code and not production_default_verification_code_is_secure():
        errors.append(
            "首件验证码默认值配置不安全，请显式设置 production_default_verification_code。"
        )
    if errors:
        raise ValueError("；".join(errors))

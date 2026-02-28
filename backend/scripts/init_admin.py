from app.core.config import settings
from app.db.session import SessionLocal
from app.services.bootstrap_seed_service import seed_initial_data


def main() -> None:
    db = SessionLocal()
    try:
        result = seed_initial_data(
            db,
            admin_username=settings.bootstrap_admin_username,
            admin_password=settings.bootstrap_admin_password,
        )
        print(
            "Initialized roles/processes/admin. "
            f"username={result.admin_username}, created={result.admin_created}, role_repaired={result.role_repaired}"
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()

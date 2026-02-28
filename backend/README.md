# MES Backend

## Quick Start

```powershell
cd backend
..\.venv\Scripts\python.exe -m pip install -r requirements.txt
..\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Backend startup now performs bootstrap automatically:

- ensure database exists (create if missing)
- run `alembic upgrade head`
- seed roles/processes/admin user

Manual seed command remains available:

```powershell
..\.venv\Scripts\python.exe -m scripts.init_admin
```

## Default Admin

- username: `admin`
- password: `Admin@123456`

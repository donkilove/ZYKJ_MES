# MES Backend

## Quick Start

```powershell
cd backend
..\.venv\Scripts\python.exe -m pip install -r requirements.txt
..\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

On Windows, from the repo root you can also use:

```powershell
.\start_backend.bat
.\start_frontend.bat
.\start_all.bat
```

Backend startup now performs bootstrap automatically:

- ensure database exists (create if missing)
- run `alembic upgrade head`
- seed roles/processes/admin user

## Local Proxy Note

If your environment sets `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`, local
requests to `127.0.0.1` may be forwarded to the proxy and fail with `502`.

The root startup entrypoints (`start_backend.py`, `start_frontend.py`,
`start_backend.bat`, `start_frontend.bat`) now auto-merge:

`NO_PROXY` and `no_proxy` => `localhost,127.0.0.1,::1`

for spawned subprocesses so localhost traffic bypasses the proxy. If you start
services manually, set `NO_PROXY` yourself.

Manual seed command remains available:

```powershell
..\.venv\Scripts\python.exe -m scripts.init_admin
```

## Default Admin

- username: `admin`
- password: `Admin@123456`

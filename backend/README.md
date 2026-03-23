# MES Backend

## Quick Start

```powershell
cd backend
..\.venv\Scripts\python.exe -m pip install -r requirements.txt
..\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

在仓库根目录也可以直接执行：

```powershell
.\.venv\Scripts\python.exe .\start_backend.py
.\.venv\Scripts\python.exe .\start_frontend.py
```

`start_frontend.py` 默认以 Windows 桌面应用方式启动；如需切换设备，可额外传入 `--device <id>`。

Backend startup now performs bootstrap automatically:

- ensure database exists (create if missing)
- run `alembic upgrade head`
- seed roles/processes/admin user

## Local Proxy Note

If your environment sets `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`, local
requests to `127.0.0.1` may be forwarded to the proxy and fail with `502`.

根目录启动入口 `start_backend.py`、`start_frontend.py` 会自动合并：

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

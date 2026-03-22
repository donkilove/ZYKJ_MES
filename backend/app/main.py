import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.api import api_router
from app.bootstrap import run_startup_bootstrap
from app.core.config import settings
from app.services.maintenance_scheduler_service import run_maintenance_auto_generate_loop
from app.services.message_service import run_message_delivery_maintenance_loop


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    scheduler_task: asyncio.Task[None] | None = None
    message_maintenance_task: asyncio.Task[None] | None = None
    run_startup_bootstrap()
    if settings.maintenance_auto_generate_enabled:
        scheduler_task = asyncio.create_task(run_maintenance_auto_generate_loop())
    if settings.message_delivery_maintenance_enabled:
        message_maintenance_task = asyncio.create_task(
            run_message_delivery_maintenance_loop()
        )
    yield
    if message_maintenance_task:
        message_maintenance_task.cancel()
        try:
            await message_maintenance_task
        except asyncio.CancelledError:
            pass
    if scheduler_task:
        scheduler_task.cancel()
        try:
            await scheduler_task
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


app.include_router(api_router, prefix=settings.api_v1_prefix)

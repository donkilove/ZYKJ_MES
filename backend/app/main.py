import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.v1.api import api_router
from app.bootstrap import run_startup_bootstrap
from app.core.config import ensure_runtime_settings_secure, settings
from app.core.user_facing_errors import localize_user_facing_detail
from app.services.maintenance_scheduler_service import run_maintenance_auto_generate_loop
from app.services.message_service import run_message_delivery_maintenance_loop
from app.web import first_article_review_router


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    scheduler_task: asyncio.Task[None] | None = None
    message_maintenance_task: asyncio.Task[None] | None = None
    ensure_runtime_settings_secure()
    if settings.web_run_bootstrap:
        run_startup_bootstrap()
    if settings.web_run_background_loops and settings.maintenance_auto_generate_enabled:
        scheduler_task = asyncio.create_task(run_maintenance_auto_generate_loop())
    if settings.web_run_background_loops and settings.message_delivery_maintenance_enabled:
        message_maintenance_task = asyncio.create_task(run_message_delivery_maintenance_loop())
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


@app.exception_handler(StarletteHTTPException)
async def handle_http_exception(
    _: Request, exc: StarletteHTTPException
) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": localize_user_facing_detail(exc.detail)},
        headers=exc.headers,
    )


@app.exception_handler(RequestValidationError)
async def handle_validation_exception(
    _: Request, exc: RequestValidationError
) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"detail": localize_user_facing_detail(exc.errors())},
    )


app.include_router(first_article_review_router)
app.include_router(api_router, prefix=settings.api_v1_prefix)

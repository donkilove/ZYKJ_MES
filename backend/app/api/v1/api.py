from fastapi import APIRouter

from app.api.v1.endpoints import (
    audits,
    auth,
    authz,
    craft,
    equipment,
    me,
    messages,
    processes,
    production,
    products,
    quality,
    roles,
    sessions,
    system,
    ui,
    users,
)


api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(authz.router, prefix="/authz", tags=["Authz"])
api_router.include_router(me.router, prefix="/me", tags=["Me"])
api_router.include_router(users.router, prefix="/users", tags=["Users"])
api_router.include_router(roles.router, prefix="/roles", tags=["Roles"])
api_router.include_router(audits.router, prefix="/audits", tags=["Audits"])
api_router.include_router(sessions.router, prefix="/sessions", tags=["Sessions"])
api_router.include_router(processes.router, prefix="/processes", tags=["Processes"])
api_router.include_router(products.router, prefix="/products", tags=["Products"])
api_router.include_router(craft.router, prefix="/craft", tags=["Craft"])
api_router.include_router(production.router, prefix="/production", tags=["Production"])
api_router.include_router(quality.router, prefix="/quality", tags=["Quality"])
api_router.include_router(equipment.router, prefix="/equipment", tags=["Equipment"])
api_router.include_router(ui.router, prefix="/ui", tags=["UI"])
api_router.include_router(messages.router, prefix="/messages", tags=["Messages"])
api_router.include_router(system.router, prefix="/system", tags=["System"])

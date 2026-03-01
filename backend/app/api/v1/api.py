from fastapi import APIRouter

from app.api.v1.endpoints import equipment, auth, processes, products, roles, ui, users


api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(users.router, prefix="/users", tags=["Users"])
api_router.include_router(roles.router, prefix="/roles", tags=["Roles"])
api_router.include_router(processes.router, prefix="/processes", tags=["Processes"])
api_router.include_router(products.router, prefix="/products", tags=["Products"])
api_router.include_router(equipment.router, prefix="/equipment", tags=["Equipment"])
api_router.include_router(ui.router, prefix="/ui", tags=["UI"])

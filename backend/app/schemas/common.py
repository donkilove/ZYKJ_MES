from typing import Generic, TypeVar

from pydantic import BaseModel


T = TypeVar("T")


class ApiResponse(BaseModel, Generic[T]):
    code: int = 0
    message: str = "ok"
    data: T


def success_response(data: T, message: str = "ok") -> ApiResponse[T]:
    return ApiResponse(code=0, message=message, data=data)


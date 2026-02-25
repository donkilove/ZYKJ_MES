from pydantic import BaseModel
from pydantic import Field


class TokenPayload(BaseModel):
    sub: str


class LoginResult(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class RegisterRequest(BaseModel):
    account: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=6, max_length=128)


class RegisterResult(BaseModel):
    id: int
    username: str
    full_name: str


class CurrentUserResult(BaseModel):
    id: int
    username: str
    full_name: str | None
    role_codes: list[str]
    role_names: list[str]
    process_codes: list[str]
    process_names: list[str]
    permission_codes: list[str]

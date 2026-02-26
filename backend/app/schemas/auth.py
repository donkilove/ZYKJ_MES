from datetime import datetime

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
    account: str
    status: str


class CurrentUserResult(BaseModel):
    id: int
    username: str
    full_name: str | None
    role_codes: list[str]
    role_names: list[str]
    process_codes: list[str]
    process_names: list[str]


class BootstrapAdminResult(BaseModel):
    username: str
    created: bool
    role_repaired: bool
    normalized_users_count: int = 0


class AccountListResult(BaseModel):
    accounts: list[str]


class RegistrationRequestItem(BaseModel):
    id: int
    account: str
    created_at: datetime


class RegistrationRequestListResult(BaseModel):
    total: int
    items: list[RegistrationRequestItem]


class ApproveRegistrationRequest(BaseModel):
    account: str = Field(min_length=3, max_length=64)
    role_codes: list[str] = Field(default_factory=list)
    process_codes: list[str] = Field(default_factory=list)


class RegistrationActionResult(BaseModel):
    request_id: int
    account: str
    final_account: str | None = None
    approved: bool
    user_id: int | None = None
    role_codes: list[str] = Field(default_factory=list)
    process_codes: list[str] = Field(default_factory=list)

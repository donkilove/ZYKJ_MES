from datetime import datetime

from pydantic import BaseModel
from pydantic import Field


class TokenPayload(BaseModel):
    sub: str


class LoginResult(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    must_change_password: bool = False


class RegisterRequest(BaseModel):
    account: str = Field(min_length=2, max_length=10)
    password: str = Field(min_length=6, max_length=128)


class RegisterResult(BaseModel):
    account: str
    status: str


class CurrentUserResult(BaseModel):
    id: int
    username: str
    full_name: str | None
    role_code: str | None = None
    role_name: str | None = None
    stage_id: int | None = None
    stage_name: str | None = None


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
    status: str
    rejected_reason: str | None = None
    reviewed_by_user_id: int | None = None
    reviewed_at: datetime | None = None
    created_at: datetime


class RegistrationRequestListResult(BaseModel):
    total: int
    items: list[RegistrationRequestItem]


class ApproveRegistrationRequest(BaseModel):
    account: str = Field(min_length=2, max_length=10)
    password: str = Field(min_length=6, max_length=128)
    role_code: str = Field(min_length=2, max_length=64)
    stage_id: int | None = Field(default=None, gt=0)


class RegistrationActionResult(BaseModel):
    request_id: int
    account: str
    status: str
    rejected_reason: str | None = None
    final_account: str | None = None
    approved: bool
    user_id: int | None = None
    role_code: str | None = None


class RejectRegistrationRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=500)


class RenewTokenRequest(BaseModel):
    password: str = Field(min_length=6, max_length=128)


class RenewTokenResult(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int

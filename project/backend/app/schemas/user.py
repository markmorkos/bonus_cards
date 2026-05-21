import uuid

from pydantic import BaseModel, EmailStr


class UserRegister(BaseModel):
    email: EmailStr
    password: str
    full_name: str | None = None
    phone: str | None = None


class UserOut(BaseModel):
    id: uuid.UUID
    email: EmailStr
    full_name: str | None
    phone: str | None
    is_active: bool

    class Config:
        from_attributes = True


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class RegisterResponse(TokenOut):
    user_id: uuid.UUID
    email: EmailStr
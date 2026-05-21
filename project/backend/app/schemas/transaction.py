import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel

class TransactionOut(BaseModel):
    id: uuid.UUID
    type: str
    amount: Decimal
    balance_after: Decimal
    created_at: datetime
    description: str | None = None

    class Config:
        from_attributes = True
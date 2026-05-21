import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel

class CardOut(BaseModel):
    id: uuid.UUID
    card_number: str
    qr_code_data: str
    balance: Decimal
    cashback_rate: Decimal
    transactions_count: int
    status: str
    level: str
    created_at: datetime

    class Config:
        from_attributes = True
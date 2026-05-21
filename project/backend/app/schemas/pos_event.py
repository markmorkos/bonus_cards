from decimal import Decimal

from pydantic import BaseModel

class PosWebhookIn(BaseModel):
    terminal_id: str
    event_type: str
    card_identifier: str
    purchase_amount: Decimal
    idempotency_key: str

class PosSpendIn(BaseModel):
    terminal_id: str
    card_identifier: str
    bonus_amount: Decimal
    purchase_amount: Decimal
    idempotency_key: str

class PosResult(BaseModel):
    success: bool
    transaction_id: str | None = None
    bonus_earned: Decimal | None = None
    bonus_spent: Decimal | None = None
    new_balance: Decimal | None = None
    cashback_rate: Decimal | None = None
    message: str | None = None

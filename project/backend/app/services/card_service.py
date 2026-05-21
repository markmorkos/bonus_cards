import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.card import BonusCard

def generate_card_number() -> str:
    return f"CARD_{uuid.uuid4().hex[:10].upper()}"

def generate_qr_data(card_number: str) -> str:
    return f"BONUS:{card_number}:{uuid.uuid4()}"

async def get_user_card(db: AsyncSession, user_id: uuid.UUID) -> BonusCard | None:
    return (await db.execute(select(BonusCard).where(BonusCard.user_id == user_id))).scalar_one_or_none()

async def create_card(db: AsyncSession, user_id: uuid.UUID) -> BonusCard:
    card_number = generate_card_number()
    card = BonusCard(
        user_id=user_id,
        card_number=card_number,
        qr_code_data=generate_qr_data(card_number),
    )
    db.add(card)
    await db.commit()
    await db.refresh(card)
    return card
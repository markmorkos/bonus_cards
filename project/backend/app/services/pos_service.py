from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.card import BonusCard

async def find_card_by_identifier(db: AsyncSession, identifier: str) -> BonusCard | None:
    return (
        await db.execute(
            select(BonusCard).where(
                or_(
                    BonusCard.card_number == identifier,
                    BonusCard.qr_code_data == identifier,
                )
            )
        )
    ).scalar_one_or_none()
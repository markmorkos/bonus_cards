import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.transaction import BonusTransaction
from app.models.user import User
from app.schemas.card import CardOut
from app.schemas.transaction import TransactionOut
from app.services.card_service import create_card, get_user_card

router = APIRouter(prefix="/cards", tags=["cards"])

@router.get("/my", response_model=CardOut)
async def my_card(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    card = await get_user_card(db, current_user.id)
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")
    return card

@router.post("/create", response_model=CardOut)
async def create(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    card = await get_user_card(db, current_user.id)
    if card:
        return card
    return await create_card(db, current_user.id)

@router.get("/{card_id}/transactions", response_model=list[TransactionOut])
async def card_transactions(
    card_id: uuid.UUID,
    limit: int = Query(default=20, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    card = await get_user_card(db, current_user.id)
    if not card or card.id != card_id:
        raise HTTPException(status_code=403, detail="Access denied")

    rows = (
        await db.execute(
            select(BonusTransaction)
            .where(BonusTransaction.card_id == card_id)
            .order_by(BonusTransaction.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
    ).scalars().all()
    return rows
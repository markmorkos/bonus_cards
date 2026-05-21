from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, verify_pos_api_key
from app.schemas.pos_event import PosResult, PosSpendIn, PosWebhookIn
from app.services.bonus_service import earn_bonus, spend_bonus
from app.services.pos_service import find_card_by_identifier

router = APIRouter(prefix="/pos", tags=["pos"])


@router.post("/webhook", response_model=PosResult, dependencies=[Depends(verify_pos_api_key)])
async def webhook(payload: PosWebhookIn, db: AsyncSession = Depends(get_db)):
    card = await find_card_by_identifier(db, payload.card_identifier)
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")

    tx = await earn_bonus(
        db=db,
        card=card,
        purchase_amount=payload.purchase_amount,
        terminal_id=payload.terminal_id,
        idempotency_key=payload.idempotency_key,
    )
    return PosResult(
        success=True,
        transaction_id=str(tx.id),
        bonus_earned=tx.amount,
        new_balance=tx.balance_after,
        cashback_rate=card.cashback_rate,
        message=tx.description,
    )


@router.post("/spend", response_model=PosResult, dependencies=[Depends(verify_pos_api_key)])
async def spend(payload: PosSpendIn, db: AsyncSession = Depends(get_db)):
    card = await find_card_by_identifier(db, payload.card_identifier)
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")

    try:
        tx = await spend_bonus(
            db=db,
            card=card,
            amount=payload.bonus_amount,
            purchase_amount=payload.purchase_amount,
            terminal_id=payload.terminal_id,
            idempotency_key=payload.idempotency_key,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    return PosResult(
        success=True,
        transaction_id=str(tx.id),
        bonus_spent=tx.amount,
        new_balance=tx.balance_after,
    )
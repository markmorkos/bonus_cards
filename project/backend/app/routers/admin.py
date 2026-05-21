import uuid
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db
from app.models.rule import BonusRule

router = APIRouter(prefix="/admin/rules", tags=["admin"])

class RuleIn(BaseModel):
    name: str
    type: str
    value: Decimal
    min_purchase: Decimal = Decimal("0.00")
    max_bonus: Decimal | None = None
    is_active: bool = True

@router.get("")
async def get_rules(db: AsyncSession = Depends(get_db)):
    return (await db.execute(select(BonusRule).order_by(BonusRule.created_at.desc()))).scalars().all()

@router.post("")
async def create_rule(payload: RuleIn, db: AsyncSession = Depends(get_db)):
    rule = BonusRule(**payload.model_dump())
    db.add(rule)
    await db.commit()
    await db.refresh(rule)
    return rule

@router.put("/{rule_id}")
async def update_rule(rule_id: uuid.UUID, payload: RuleIn, db: AsyncSession = Depends(get_db)):
    rule = (await db.execute(select(BonusRule).where(BonusRule.id == rule_id))).scalar_one_or_none()
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")

    for key, value in payload.model_dump().items():
        setattr(rule, key, value)

    await db.commit()
    await db.refresh(rule)
    return rule

@router.delete("/{rule_id}")
async def deactivate_rule(rule_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    rule = (await db.execute(select(BonusRule).where(BonusRule.id == rule_id))).scalar_one_or_none()
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")

    rule.is_active = False
    await db.commit()
    return {"success": True}
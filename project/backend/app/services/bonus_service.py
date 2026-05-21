from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.card import BonusCard
from app.models.transaction import BonusTransaction
from app.redis_client import redis_client

# Cashback progression constants
CASHBACK_MIN = Decimal("3.00")
CASHBACK_MAX = Decimal("12.00")
CASHBACK_STEP = Decimal("1.00")
SPEND_MAX_RATIO = Decimal("0.50")  # max 50% of purchase amount


def _get_cashback_rate(card: BonusCard) -> Decimal:
    """Returns current cashback rate for a card (3% base, +1% per transaction, max 12%)."""
    rate = CASHBACK_MIN + CASHBACK_STEP * card.transactions_count
    return min(rate, CASHBACK_MAX)


def _advance_cashback_rate(card: BonusCard) -> None:
    """Increments transaction count and updates cashback_rate on the card."""
    card.transactions_count += 1
    card.cashback_rate = min(
        CASHBACK_MIN + CASHBACK_STEP * card.transactions_count,
        CASHBACK_MAX,
    )


async def earn_bonus(
    db: AsyncSession,
    card: BonusCard,
    purchase_amount: Decimal,
    terminal_id: str,
    idempotency_key: str,
) -> BonusTransaction:
    existing = (
        await db.execute(select(BonusTransaction).where(BonusTransaction.idempotency_key == idempotency_key))
    ).scalar_one_or_none()
    if existing:
        return existing

    rate = _get_cashback_rate(card)
    earned = (purchase_amount * rate / Decimal("100")).quantize(Decimal("0.01"))

    balance_before = Decimal(card.balance)
    balance_after = balance_before + earned
    card.balance = balance_after

    # Advance cashback rate for next transaction
    _advance_cashback_rate(card)

    tx = BonusTransaction(
        card_id=card.id,
        type="earn",
        amount=earned,
        balance_before=balance_before,
        balance_after=balance_after,
        pos_terminal_id=terminal_id,
        purchase_amount=purchase_amount,
        description=f"Нараховано {earned} бонусів ({rate}% від {purchase_amount} грн). Наступна ставка: {card.cashback_rate}%",
        idempotency_key=idempotency_key,
    )
    db.add(tx)
    await db.commit()
    await db.refresh(tx)

    await redis_client.set(f"card:{card.id}:balance", str(balance_after), ex=settings.BONUS_CACHE_TTL)
    await redis_client.set(f"card:{card.id}:cashback_rate", str(card.cashback_rate), ex=settings.BONUS_CACHE_TTL)
    return tx


async def spend_bonus(
    db: AsyncSession,
    card: BonusCard,
    amount: Decimal,
    purchase_amount: Decimal,
    terminal_id: str,
    idempotency_key: str,
) -> BonusTransaction:
    existing = (
        await db.execute(select(BonusTransaction).where(BonusTransaction.idempotency_key == idempotency_key))
    ).scalar_one_or_none()
    if existing:
        return existing

    # Validate: cannot spend more than 50% of purchase amount
    max_spendable = (purchase_amount * SPEND_MAX_RATIO).quantize(Decimal("0.01"))
    if amount > max_spendable:
        raise ValueError(
            f"Можна списати максимум 50% від суми рахунку ({max_spendable} грн)"
        )

    balance_before = Decimal(card.balance)
    if balance_before < amount:
        raise ValueError("Недостатньо бонусів на балансі")

    balance_after = balance_before - amount
    card.balance = balance_after

    tx = BonusTransaction(
        card_id=card.id,
        type="spend",
        amount=amount,
        balance_before=balance_before,
        balance_after=balance_after,
        pos_terminal_id=terminal_id,
        purchase_amount=purchase_amount,
        description=f"Списано {amount} бонусів (рахунок {purchase_amount} грн, ліміт 50%)",
        idempotency_key=idempotency_key,
    )
    db.add(tx)
    await db.commit()
    await db.refresh(tx)

    await redis_client.set(f"card:{card.id}:balance", str(balance_after), ex=settings.BONUS_CACHE_TTL)
    return tx
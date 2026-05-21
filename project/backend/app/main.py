from fastapi import FastAPI

from app.database import Base, engine
from app.models import card, pos_event, rule, transaction, user  # noqa: F401
from app.routers import admin, auth, cards, pos, transactions

app = FastAPI(title="Bonus Cards API", version="1.0.0")

app.include_router(auth.router)
app.include_router(cards.router)
app.include_router(transactions.router)
app.include_router(pos.router)
app.include_router(admin.router)
@app.on_event("startup")
async def on_startup() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}

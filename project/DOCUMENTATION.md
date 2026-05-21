# Технічна документація: Система цифрових бонусних карток


## Зміст

1. [Загальна архітектура](#1-загальна-архітектура)
2. [Конфігурація та змінні середовища](#2-конфігурація-та-змінні-середовища)
3. [База даних — моделі](#3-база-даних--моделі)
4. [Авторизація (JWT)](#4-авторизація-jwt)
5. [Бонусні картки](#5-бонусні-картки)
6. [Бізнес-логіка нарахування бонусів](#6-бізнес-логіка-нарахування-бонусів)
7. [POS-інтеграція](#7-pos-інтеграція)
8. [Адміністрування правил](#8-адміністрування-правил)
9. [Мобільний застосунок (Flutter)](#9-мобільний-застосунок-flutter)
10. [Міграції бази даних](#10-міграції-бази-даних)
11. [Тестування](#11-тестування)
12. [Покроковий сценарій ручного тестування](#12-покроковий-сценарій-ручного-тестування)

---

## 1. Загальна архітектура

```
┌─────────────────┐        HTTP/JSON         ┌──────────────────────┐
│  Flutter Mobile │  ──── JWT Bearer ────►  │                      │
│   (клієнт)      │                          │   FastAPI Backend     │
└─────────────────┘                          │   (Python 3.12)      │
                                             │                      │
┌─────────────────┐        HTTP/JSON         │   /auth/*            │
│  POS Термінал   │  ── X-POS-API-Key ──►  │   /cards/*           │
│  (симулюється   │                          │   /pos/*             │
│   curl/Postman) │                          │   /admin/rules/*     │
└─────────────────┘                          └──────┬───────────────┘
                                                    │
                                          ┌─────────┴─────────┐
                                          │   PostgreSQL 16    │
                                          │   Redis 7          │
                                          └───────────────────┘
```

**Два типи клієнтів з різною авторизацією:**

| Клієнт | Метод авторизації | Ендпоінти |
|---|---|---|
| Мобільний додаток | `Authorization: Bearer <JWT>` | `/auth/*`, `/cards/*` |
| POS-термінал | `X-POS-API-Key: <ключ>` | `/pos/*` |

---

## 2. Конфігурація та змінні середовища

Файл: `project/backend/.env`

```env
DATABASE_URL=postgresql+asyncpg://bonuscard_user:bonuscard_pass@db:5432/bonuscard_db
REDIS_URL=redis://redis:6379
SECRET_KEY=super-secret-jwt-key-change-in-production-2026
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
POS_API_KEY=pos-api-key-12345
BONUS_CACHE_TTL=300
```

Файл: `project/backend/app/config.py`

```python
class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://..."
    REDIS_URL: str = "redis://redis:6379"
    SECRET_KEY: str = "your-secret-key-here"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    POS_API_KEY: str = "pos-api-key-12345"
    BONUS_CACHE_TTL: int = 300  # секунд кешування балансу в Redis

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
```

**Значення за замовчуванням для локального тестування:**
- `POS_API_KEY` = `pos-api-key-12345`
- `SECRET_KEY` = береться з `.env`, JWT токен живе 60 хвилин

---

## 3. База даних — моделі

### User — користувач
```
id (UUID)
email (унікальний)
hashed_password (bcrypt)
full_name
phone
is_active
created_at
```

### BonusCard — бонусна картка
```
id (UUID)
user_id → User
card_number (унікальний, генерується автоматично)
qr_code_data (дані для QR-коду)
balance (Decimal, поточний баланс бонусів)
cashback_rate (Decimal, поточна ставка кешбеку %, default=3.00)
transactions_count (Integer, кількість закритих рахунків, default=0)
status (str: "active")
level (str: "standard", "silver", "gold")
created_at
updated_at
```

> **Прогресія:** `cashback_rate = min(3 + transactions_count, 12)`  
> З кожним новим нарахуванням `transactions_count` збільшується на 1, `cashback_rate` оновлюється автоматично.

### BonusTransaction — транзакція
```
id (UUID)
card_id → BonusCard
type ("earn" або "spend")
amount (Decimal, сума бонусів)
balance_before (Decimal)
balance_after (Decimal)
purchase_amount (Decimal, сума рахунку — для earn і spend)
pos_terminal_id (str)
rule_id → BonusRule (не використовується в поточній логіці прогресії)
idempotency_key (унікальний ключ для захисту від дублів)
description
created_at
```

### BonusRule — правило нарахування (legacy)
```
id (UUID)
name (str)
type ("percentage" | "fixed" | "multiplier")
value (Decimal)
min_purchase (Decimal)
max_bonus (Decimal | None)
is_active (bool)
created_at
```

> ⚠️ Модель `BonusRule` залишена для сумісності, але поточна логіка нарахування **не використовує** глобальні правила — ставка per-card і розраховується автоматично.

---

## 4. Авторизація (JWT)

### Реєстрація

**POST** `/auth/register`

```json
{
  "email": "user@example.com",
  "password": "mypassword",
  "full_name": "Іван Петренко",
  "phone": "+380671234567"
}
```

Відповідь:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user_id": "uuid-here",
  "email": "user@example.com"
}
```

### Вхід

**POST** `/auth/login`

```json
{
  "email": "user@example.com",
  "password": "mypassword"
}
```

Відповідь:
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

### Код генерації JWT токену

```python
# app/services/auth_service.py
def create_access_token(subject: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"sub": subject, "exp": expire}
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
```

`subject` = UUID користувача. Заголовок: `Authorization: Bearer <токен>`

---

## 5. Бонусні картки

### Отримати свою картку

**GET** `/cards/my` — заголовок: `Authorization: Bearer <токен>`

Відповідь:
```json
{
  "id": "uuid",
  "card_number": "CARD_2C53F730B5",
  "qr_code_data": "BONUS:CARD_2C53F730B5:uuid",
  "balance": "150.00",
  "cashback_rate": "5.00",
  "transactions_count": 2,
  "status": "active",
  "level": "standard",
  "created_at": "2026-05-14T07:00:00Z"
}
```

### Створити картку

**POST** `/cards/create` — якщо картка вже є — повертає існуючу (ідемпотентно).

### Транзакції картки

**GET** `/cards/{card_id}/transactions?limit=20&offset=0`

---

## 6. Бізнес-логіка нарахування бонусів

Файл: `project/backend/app/services/bonus_service.py`

### Прогресивна ставка кешбеку (per-card)

```python
CASHBACK_MIN = Decimal("3.00")   # стартова ставка
CASHBACK_MAX = Decimal("12.00")  # максимальна ставка
CASHBACK_STEP = Decimal("1.00")  # крок підвищення за рахунок

def _get_cashback_rate(card: BonusCard) -> Decimal:
    rate = CASHBACK_MIN + CASHBACK_STEP * card.transactions_count
    return min(rate, CASHBACK_MAX)

def _advance_cashback_rate(card: BonusCard) -> None:
    card.transactions_count += 1
    card.cashback_rate = min(
        CASHBACK_MIN + CASHBACK_STEP * card.transactions_count,
        CASHBACK_MAX,
    )
```

**Таблиця прогресії:**

| `transactions_count` | `cashback_rate` |
|---|---|
| 0 (нова картка) | 3% |
| 1 | 4% |
| 2 | 5% |
| ... | ... |
| 9+ | 12% |

### Нарахування бонусів (`earn_bonus`)

```python
async def earn_bonus(db, card, purchase_amount, terminal_id, idempotency_key):
    # 1. Захист від дублікатів
    existing = await db.execute(
        select(BonusTransaction).where(BonusTransaction.idempotency_key == idempotency_key)
    )
    if existing: return existing

    # 2. Розрахунок за поточною ставкою картки
    rate = _get_cashback_rate(card)
    earned = (purchase_amount * rate / Decimal("100")).quantize(Decimal("0.01"))

    # 3. Оновлення балансу
    card.balance += earned

    # 4. Підвищення ставки для наступного рахунку
    _advance_cashback_rate(card)

    # 5. Збереження транзакції + кеш Redis
    ...
```

### Списання бонусів (`spend_bonus`) — ліміт 50%

```python
SPEND_MAX_RATIO = Decimal("0.50")

async def spend_bonus(db, card, amount, purchase_amount, terminal_id, idempotency_key):
    # Перевірка: не більше 50% від суми рахунку
    max_spendable = (purchase_amount * SPEND_MAX_RATIO).quantize(Decimal("0.01"))
    if amount > max_spendable:
        raise ValueError(f"Можна списати максимум 50% від суми рахунку ({max_spendable} грн)")

    # Перевірка балансу
    if card.balance < amount:
        raise ValueError("Недостатньо бонусів на балансі")

    card.balance -= amount
    ...
```

### Кешування балансу в Redis

```python
# після операції — зберігаємо в Redis на BONUS_CACHE_TTL секунд
await redis_client.set(f"card:{card.id}:balance", str(balance_after), ex=settings.BONUS_CACHE_TTL)
await redis_client.set(f"card:{card.id}:cashback_rate", str(card.cashback_rate), ex=settings.BONUS_CACHE_TTL)
```

---

## 7. POS-інтеграція

### Авторизація POS-терміналу

```
X-POS-API-Key: pos-api-key-12345
```

### Нарахування бонусів (покупка)

**POST** `/pos/webhook`

```json
{
  "terminal_id": "TERM_001",
  "event_type": "purchase",
  "card_identifier": "CARD_2C53F730B5",
  "purchase_amount": 1000.00,
  "idempotency_key": "order-20260514-001"
}
```

Відповідь:
```json
{
  "success": true,
  "transaction_id": "uuid",
  "bonus_earned": "30.00",
  "new_balance": "30.00",
  "cashback_rate": "4.00",
  "message": "Нараховано 30.00 бонусів (3% від 1000.00 грн). Наступна ставка: 4%"
}
```

> `cashback_rate` у відповіді — це **нова** ставка, яка буде застосована до **наступного** рахунку.

### Списання бонусів

**POST** `/pos/spend`

```json
{
  "terminal_id": "TERM_001",
  "card_identifier": "CARD_2C53F730B5",
  "bonus_amount": 200.00,
  "purchase_amount": 1000.00,
  "idempotency_key": "spend-20260514-001"
}
```

> ⚠️ **Обов'язково вказувати `purchase_amount`** — для перевірки ліміту 50%.  
> Якщо `bonus_amount > purchase_amount * 0.5` — HTTP 400.

Відповідь:
```json
{
  "success": true,
  "transaction_id": "uuid",
  "bonus_spent": "200.00",
  "new_balance": "0.00"
}
```

Помилки:
```json
{"detail": "Можна списати максимум 50% від суми рахунку (500.00 грн)"}
{"detail": "Недостатньо бонусів на балансі"}
```

---

## 8. Адміністрування правил

> ℹ️ Ендпоінти `/admin/rules` залишені для сумісності. Поточна логіка нарахування **не залежить** від глобальних правил — ставка розраховується per-card автоматично.

### Переглянути всі правила

**GET** `/admin/rules`

### Створити правило

**POST** `/admin/rules`

```json
{
  "name": "Базове правило",
  "type": "percentage",
  "value": 10,
  "min_purchase": 0,
  "is_active": true
}
```

---

## 9. Мобільний застосунок (Flutter)

### Запуск застосунку

```bash
cd project/mobile
flutter pub get
flutter run
```

### Ключові файли

| Файл | Призначення |
|---|---|
| `lib/app.dart` | Кореневий роутер: перевіряє токен → LoginScreen або CardScreen |
| `lib/core/api_client.dart` | Dio HTTP клієнт, базовий URL |
| `lib/core/secure_storage.dart` | Зберігання JWT токену (flutter_secure_storage) |
| `lib/features/auth/data/auth_repository.dart` | Login, register, logout, getToken |
| `lib/features/card/data/card_repository.dart` | getMyCard, createCard |
| `lib/features/history/data/transaction_repository.dart` | getTransactions |
| `lib/features/card/presentation/card_screen.dart` | Головний екран: QR, кешбек, прогрес-бар, 50% інфо |

### Потік авторизації

```
app.dart (_StartupGate)
 └── getToken() з secure_storage
      ├── токен є → CardScreen(token)
      └── токен нема → LoginScreen
           ├── login() → зберігає токен → CardScreen(token)
           └── кнопка "Реєстрація" → RegisterScreen → LoginScreen
```

### Потік картки

```
CardScreen.initState()
 └── cardRepository.getMyCard(token)
      ├── успіх → показати картку (cashback_rate, transactions_count, balance)
      └── 404 → cardRepository.createCard(token) → показати нову картку (3% кешбек)
```

### UI-елементи картки (`card_screen.dart`)

| Елемент | Що показує |
|---|---|
| Тайл "Рівень" | Рівень картки (standard/silver/gold) |
| Тайл "Бонусів" | Поточний баланс |
| Блок "Кешбек" | Поточна ставка % + `LinearProgressIndicator` 3%→12% |
| Підпис прогресу | `"N рахунків закрито · наступний: X%"` або `"Максимальний рівень! 🎉"` |
| Інфо-плашка | `"Списати бонусами можна до 50% від суми рахунку"` |
| QR-код | Для сканування на POS |
| Штрих-код | Альтернатива QR (показується за кнопкою) |

### Кольорова схема прогресу кешбеку

| Ставка | Колір |
|---|---|
| 3–6% | Синій `#005BBB` |
| 7–9% | Зелений `#4CAF50` |
| 10–12% | Золотий `#FFD700` |

### Підключення API

Файл `lib/core/api_client.dart`:
```dart
// Android emulator → localhost:
// baseUrl = "http://10.0.2.2:8000"
// iOS simulator або macOS:
// baseUrl = "http://localhost:8000"
```

---

## 10. Міграції бази даних

Файл: `project/backend/alembic/versions/001_add_cashback_fields_to_bonus_cards.py`

Додає два нові поля до таблиці `bonus_cards`:

```python
def upgrade() -> None:
    op.add_column('bonus_cards',
        sa.Column('cashback_rate', sa.Numeric(5, 2), nullable=False, server_default='3.00'))
    op.add_column('bonus_cards',
        sa.Column('transactions_count', sa.Integer(), nullable=False, server_default='0'))

def downgrade() -> None:
    op.drop_column('bonus_cards', 'transactions_count')
    op.drop_column('bonus_cards', 'cashback_rate')
```

Запуск міграції (якщо використовується Alembic):
```bash
cd project/backend
alembic upgrade head
```

> При використанні `docker compose up --build` з `Base.metadata.create_all()` — нові поля створюються автоматично для нових інсталяцій. Міграція потрібна для існуючих баз.

---

## 11. Тестування

### Автоматичні backend-тести

```bash
cd project/backend
pip install pytest pytest-asyncio httpx
pytest -v
```

**Файли тестів:**
- `tests/test_auth.py` — реєстрація, вхід, me
- `tests/test_cards.py` — створення та отримання картки
- `tests/test_pos_webhook.py` — перевірка API-ключа POS

### Flutter аналіз та тести

```bash
cd project/mobile
flutter analyze
flutter test
```

---

## 12. Покроковий сценарій ручного тестування

### Крок 0. Запустити бекенд

```bash
cd project
docker compose up --build
```

Перевірити: http://localhost:8000/docs

---

### Крок 1. Зареєструвати користувача

```bash
curl -s -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "ivan@test.com",
    "password": "password123",
    "full_name": "Іван Тест"
  }' | python3 -m json.tool
```

Зберегти `access_token` з відповіді.

---

### Крок 2. Створити бонусну картку

```bash
TOKEN="вставити_токен_з_кроку_1"

curl -s -X POST http://localhost:8000/cards/create \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

Відповідь містить `card_number`, `cashback_rate: "3.00"`, `transactions_count: 0`.  
Зберегти `card_number` як `CARD`.

---

### Крок 3. Симулювати першу покупку (ставка 3%)

```bash
CARD="CARD_2C53F730B5"

curl -s -X POST http://localhost:8000/pos/webhook \
  -H "Content-Type: application/json" \
  -H "X-POS-API-Key: pos-api-key-12345" \
  -d "{
    \"terminal_id\": \"TERM_001\",
    \"event_type\": \"purchase\",
    \"card_identifier\": \"$CARD\",
    \"purchase_amount\": 1000.00,
    \"idempotency_key\": \"order-001\"
  }" | python3 -m json.tool
```

Очікувана відповідь:
```json
{
  "success": true,
  "bonus_earned": "30.00",
  "new_balance": "30.00",
  "cashback_rate": "4.00",
  "message": "Нараховано 30.00 бонусів (3% від 1000.00 грн). Наступна ставка: 4%"
}
```

---

### Крок 4. Друга покупка (ставка вже 4%)

```bash
curl -s -X POST http://localhost:8000/pos/webhook \
  -H "Content-Type: application/json" \
  -H "X-POS-API-Key: pos-api-key-12345" \
  -d "{
    \"terminal_id\": \"TERM_001\",
    \"event_type\": \"purchase\",
    \"card_identifier\": \"$CARD\",
    \"purchase_amount\": 1000.00,
    \"idempotency_key\": \"order-002\"
  }" | python3 -m json.tool
```

`bonus_earned: "40.00"`, `cashback_rate: "5.00"`.

---

### Крок 5. Перевірити баланс і ставку

```bash
curl -s http://localhost:8000/cards/my \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

Поля `cashback_rate` і `transactions_count` відображають поточний стан.

---

### Крок 6. Списати бонуси (з перевіркою 50% ліміту)

```bash
# Рахунок 1000 грн → ліміт 500 бонусів
curl -s -X POST http://localhost:8000/pos/spend \
  -H "Content-Type: application/json" \
  -H "X-POS-API-Key: pos-api-key-12345" \
  -d "{
    \"terminal_id\": \"TERM_001\",
    \"card_identifier\": \"$CARD\",
    \"bonus_amount\": 30.00,
    \"purchase_amount\": 1000.00,
    \"idempotency_key\": \"spend-001\"
  }" | python3 -m json.tool
```

---

### Крок 7. Спроба списати більше 50% (очікується помилка)

```bash
curl -s -X POST http://localhost:8000/pos/spend \
  -H "Content-Type: application/json" \
  -H "X-POS-API-Key: pos-api-key-12345" \
  -d "{
    \"terminal_id\": \"TERM_001\",
    \"card_identifier\": \"$CARD\",
    \"bonus_amount\": 600.00,
    \"purchase_amount\": 1000.00,
    \"idempotency_key\": \"spend-002\"
  }" | python3 -m json.tool
```

Очікувана відповідь: HTTP 400 — `{"detail": "Можна списати максимум 50% від суми рахунку (500.00 грн)"}`

---

### Крок 8. Перевірити ідемпотентність

```bash
# Повторити order-001 — бонуси не нараховуються двічі
curl -s -X POST http://localhost:8000/pos/webhook \
  -H "Content-Type: application/json" \
  -H "X-POS-API-Key: pos-api-key-12345" \
  -d "{
    \"terminal_id\": \"TERM_001\",
    \"event_type\": \"purchase\",
    \"card_identifier\": \"$CARD\",
    \"purchase_amount\": 1000.00,
    \"idempotency_key\": \"order-001\"
  }" | python3 -m json.tool
```

Баланс не змінюється.

---

### Крок 9. Переглянути всі транзакції

```bash
CARD_UUID="вставити_id_картки"

curl -s "http://localhost:8000/cards/$CARD_UUID/transactions" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

---

## Swagger UI

Після запуску: **http://localhost:8000/docs**

Для авторизації — натиснути "Authorize" → вставити токен у форму `bearerAuth`.

---
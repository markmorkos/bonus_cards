# Технічна документація: Система цифрових бонусних карток

> Документ призначений для розробника або AI-агента, який продовжує роботу над проєктом.
> Містить повний опис архітектури, бізнес-логіки, API та інструкції з тестування.

---

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
10. [Тестування](#10-тестування)
11. [Покроковий сценарій ручного тестування](#11-покроковий-сценарій-ручного-тестування)

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
card_number (унікальний, генерується)
qr_code_data (дані для QR-коду)
balance (Decimal, поточний баланс бонусів)
level (str: "standard", "silver", "gold")
is_active
created_at
```

### BonusTransaction — транзакція
```
id (UUID)
card_id → BonusCard
type ("earn" або "spend")
amount (Decimal, сума бонусів)
balance_before (Decimal)
balance_after (Decimal)
purchase_amount (Decimal, сума покупки — тільки для earn)
pos_terminal_id (str)
rule_id → BonusRule (яке правило застосовано)
idempotency_key (унікальний ключ для захисту від дублів)
description
created_at
```

### BonusRule — правило нарахування
```
id (UUID)
name (str)
type ("percentage" | "fixed" | "multiplier")
value (Decimal — відсоток, фіксована сума або множник)
min_purchase (Decimal — мінімальна сума покупки)
max_bonus (Decimal | None — максимальна сума бонусу)
is_active (bool)
created_at
```

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

`subject` = UUID користувача. Токен містить `sub` (user_id) та `exp` (час закінчення).

### Верифікація токену у захищених ендпоінтах

Заголовок: `Authorization: Bearer <токен>`

---

## 5. Бонусні картки

### Отримати свою картку

**GET** `/cards/my`

Заголовок: `Authorization: Bearer <токен>`

Відповідь:
```json
{
  "id": "uuid",
  "card_number": "BC-00001",
  "qr_code_data": "BONUS:BC-00001:uuid",
  "balance": "150.00",
  "level": "standard",
  "is_active": true,
  "created_at": "2026-05-14T07:00:00Z"
}
```

### Створити картку

**POST** `/cards/create`

Заголовок: `Authorization: Bearer <токен>`

Якщо картка вже є — повертає існуючу (ідемпотентно).

### Транзакції картки

**GET** `/cards/{card_id}/transactions?limit=20&offset=0`

Заголовок: `Authorization: Bearer <токен>`

Відповідь — масив:
```json
[
  {
    "id": "uuid",
    "type": "earn",
    "amount": "50.00",
    "balance_after": "150.00",
    "created_at": "2026-05-14T07:00:00Z",
    "description": "Нараховано 50 бонусів"
  }
]
```

---

## 6. Бізнес-логіка нарахування бонусів

Файл: `project/backend/app/services/bonus_service.py`

### Три типи правил

```python
def _calculate_bonus(rule: BonusRule, purchase_amount: Decimal) -> Decimal:
    if purchase_amount < Decimal(rule.min_purchase):
        return Decimal("0.00")  # покупка занадто мала

    if rule.type == "fixed":
        # фіксована сума бонусів за будь-яку покупку
        bonus = Decimal(rule.value)

    elif rule.type == "multiplier":
        # бонуси = сума_покупки × 0.01 × множник
        # наприклад: 500 грн × 0.01 × 5 = 25 бонусів
        bonus = purchase_amount * Decimal("0.01") * Decimal(rule.value)

    else:  # "percentage"
        # бонуси = відсоток від суми покупки
        # наприклад: 500 грн × 10% = 50 бонусів
        bonus = purchase_amount * (Decimal(rule.value) / Decimal("100"))

    # обмеження максимуму
    if rule.max_bonus and bonus > Decimal(rule.max_bonus):
        bonus = Decimal(rule.max_bonus)

    return bonus.quantize(Decimal("0.01"))
```

### Захист від дублікатів (ідемпотентність)

```python
async def earn_bonus(db, card, purchase_amount, terminal_id, idempotency_key):
    # перевірка чи вже є транзакція з таким ключем
    existing = await db.execute(
        select(BonusTransaction).where(
            BonusTransaction.idempotency_key == idempotency_key
        )
    )
    if existing:
        return existing  # повертаємо старий результат, не дублюємо
    ...
```

**Важливо:** `idempotency_key` має бути унікальним для кожної нової покупки. POS-термінал генерує його сам (наприклад, `order-12345`). Якщо запит повторити з тим самим ключем — бонуси не нарахуються двічі.

### Кешування балансу в Redis

```python
# після нарахування — зберігаємо в Redis на 300 секунд
await redis_client.set(
    f"card:{card.id}:balance",
    str(balance_after),
    ex=settings.BONUS_CACHE_TTL
)
```

---

## 7. POS-інтеграція

### Авторизація POS-терміналу

Усі POS-запити перевіряються через заголовок:
```
X-POS-API-Key: pos-api-key-12345
```

Код перевірки (`app/dependencies.py`):
```python
async def verify_pos_api_key(x_pos_api_key: str = Header(...)):
    if x_pos_api_key != settings.POS_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid POS API key")
```

### Нарахування бонусів (покупка)

**POST** `/pos/webhook`

```json
{
  "terminal_id": "TERM_001",
  "event_type": "purchase",
  "card_identifier": "CARD_2C53F730B5",
  "purchase_amount": 500.00,
  "idempotency_key": "order-20260514-001"
}
```

> ⚠️ **Обов'язкові поля:** `terminal_id`, `event_type`, `card_identifier`, `purchase_amount`, `idempotency_key`  
> ❌ **Не використовувати:** `card_number`, `amount` — це старі/неіснуючі поля, сервер поверне 422

- `card_identifier` — значення поля `card_number` або `qr_code_data` з відповіді `/cards/my`
- `event_type` — завжди `"purchase"` для нарахування
- `idempotency_key` — унікальний ID замовлення від каси

Відповідь:
```json
{
  "success": true,
  "transaction_id": "uuid",
  "bonus_earned": "50.00",
  "new_balance": "150.00",
  "message": "Нараховано 50 бонусів"
}
```

### Списання бонусів (оплата бонусами)

**POST** `/pos/spend`

```json
{
  "terminal_id": "TERM_001",
  "card_identifier": "CARD_2C53F730B5",
  "bonus_amount": 30.00,
  "idempotency_key": "spend-20260514-001"
}
```

> ⚠️ **Обов'язкові поля:** `terminal_id`, `card_identifier`, `bonus_amount`, `idempotency_key`

Відповідь:
```json
{
  "success": true,
  "transaction_id": "uuid",
  "bonus_spent": "30.00",
  "new_balance": "120.00"
}
```

Якщо балансу недостатньо — HTTP 400:
```json
{"detail": "Insufficient bonus balance"}
```

---

## 8. Адміністрування правил

### Переглянути всі правила

**GET** `/admin/rules`

### Створити правило нарахування

**POST** `/admin/rules`

```json
{
  "name": "10% за покупку",
  "type": "percentage",
  "value": 10,
  "min_purchase": 50,
  "max_bonus": 200,
  "is_active": true
}
```

Варіанти `type`:
- `"percentage"` — `value`% від суми покупки
- `"fixed"` — фіксована сума `value` бонусів незалежно від суми
- `"multiplier"` — сума × 0.01 × `value`

### Деактивувати правило

**DELETE** `/admin/rules/{rule_id}`

Не видаляє фізично — встановлює `is_active = false`.

---

## 9. Мобільний застосунок (Flutter)

### Запуск застосунку

```bash
cd project/mobile
flutter pub get
flutter run   # обирає підключений пристрій або емулятор
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
| `lib/features/auth/presentation/login_screen.dart` | Екран входу |
| `lib/features/card/presentation/card_screen.dart` | Головний екран з QR-кодом |
| `lib/features/history/presentation/history_screen.dart` | Список транзакцій |

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
      ├── успіх → показати картку
      └── 404 → cardRepository.createCard(token) → показати нову картку
```

### Підключення API

Файл `lib/core/api_client.dart` — змінити `baseUrl` якщо потрібно:

```dart
// для локальної розробки на мобільному пристрої або емуляторі Android:
// baseUrl = "http://10.0.2.2:8000"  (Android emulator → localhost)
// baseUrl = "http://localhost:8000"  (iOS simulator або macOS)
```

---

## 10. Тестування

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

Приклад тесту POS:
```python
# tests/test_pos_webhook.py
@pytest.mark.asyncio
async def test_invalid_pos_api_key(client):
    response = await client.post(
        "/pos/webhook",
        headers={"X-POS-API-Key": "wrong-key"},
        json={
            "terminal_id": "TERM_001",
            "event_type": "purchase",
            "card_identifier": "CARD_12345",
            "purchase_amount": 100.0,
            "idempotency_key": "idem-1",
        },
    )
    assert response.status_code == 401
```

### Flutter аналіз та тести

```bash
cd project/mobile
flutter analyze         # статичний аналіз (має бути "No issues found")
flutter test            # запуск unit/widget тестів
```

---

## 11. Покроковий сценарій ручного тестування

### Крок 0. Запустити бекенд

```bash
cd project
docker compose up --build
```

Перевірити: http://localhost:8000/docs — відкриється Swagger UI з усіма ендпоінтами.

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

### ⚠️ Важливо про правила нарахування

Якщо активного правила немає — бонуси завжди будуть `0.00` (навіть якщо запит успішний).  
Правило **обов'язково** потрібно створити **до** першої покупки.  
Якщо ти вже надіслав POS-запит і отримав `bonus_earned: "0.00"` — просто створи правило і надішли запит ще раз з **новим** `idempotency_key`.

---

### Крок 2. Створити правило нарахування бонусів

```bash
curl -s -X POST http://localhost:8000/admin/rules \
  -H "Content-Type: application/json" \
  -d '{
    "name": "10% від покупки",
    "type": "percentage",
    "value": 10,
    "min_purchase": 0,
    "is_active": true
  }' | python3 -m json.tool
```

---

### Крок 3. Створити бонусну картку

```bash
TOKEN="вставити_токен_з_кроку_1"

curl -s -X POST http://localhost:8000/cards/create \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

Зберегти `card_number` або `qr_code_data` (обидва можна використати як `card_identifier`).

---

### Крок 4. Симулювати покупку на POS (нарахування бонусів)

> Отримати `card_number` з відповіді кроку 3, наприклад `CARD_2C53F730B5`

```bash
CARD="CARD_2C53F730B5"   # замінити на свій card_number

curl -s -X POST http://localhost:8000/pos/webhook \
  -H "Content-Type: application/json" \
  -H "X-POS-API-Key: pos-api-key-12345" \
  -d "{
    \"terminal_id\": \"TERM_001\",
    \"event_type\": \"purchase\",
    \"card_identifier\": \"$CARD\",
    \"purchase_amount\": 500.00,
    \"idempotency_key\": \"order-001\"
  }" | python3 -m json.tool
```

> ❌ Помилка 422 = неправильні поля. Переконайся що використовуєш саме ці поля: `terminal_id`, `event_type`, `card_identifier`, `purchase_amount`, `idempotency_key`

Очікuvana відповідь:
```json
{
  "success": true,
  "bonus_earned": "50.00",
  "new_balance": "50.00"
}
```

---

### Крок 5. Перевірити баланс картки

```bash
curl -s http://localhost:8000/cards/my \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

`balance` має бути `50.00`.

---

### Крок 6. Симулювати ще одну покупку

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

Баланс стане `150.00`.

---

### Крок 7. Перевірити ідемпотентність (захист від дублю)

```bash
# Повторити той самий запит з тим самим idempotency_key
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

Баланс залишиться `150.00` — дублю немає.

---

### Крок 8. Списати бонуси

```bash
curl -s -X POST http://localhost:8000/pos/spend \
  -H "Content-Type: application/json" \
  -H "X-POS-API-Key: pos-api-key-12345" \
  -d "{
    \"terminal_id\": \"TERM_001\",
    \"card_identifier\": \"$CARD\",
    \"bonus_amount\": 50.00,
    \"idempotency_key\": \"spend-001\"
  }" | python3 -m json.tool
```

> ⚠️ Поле називається `bonus_amount`, а не `amount`!

Баланс стане `100.00`.

---

### Крок 9. Переглянути всі транзакції

```bash
CARD_UUID="вставити_id_картки_з_кроку_3"

curl -s "http://localhost:8000/cards/$CARD_UUID/transactions" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

---

### Крок 10. Тест невірного API ключа

```bash
curl -s -X POST http://localhost:8000/pos/webhook \
  -H "X-POS-API-Key: wrong-key" \
  -H "Content-Type: application/json" \
  -d '{"terminal_id":"T","event_type":"purchase","card_identifier":"X","purchase_amount":100,"idempotency_key":"k1"}'
```

Відповідь: HTTP 401 — `{"detail": "Invalid POS API key"}`

---

## Swagger UI

Після запуску `docker compose up` відкрити:  
**http://localhost:8000/docs**

Там можна тестувати всі ендпоінти через браузер без curl.

Для авторизації — натиснути "Authorize" → вставити токен у форму `bearerAuth`.

---

## Відомі обмеження / що можна покращити

| Що | Статус |
|---|---|
| Реєстрація POS-терміналів у БД | Не реалізовано — ключ один для всіх |
| Рівні карток (silver/gold) | Поле є в БД, логіка підвищення не реалізована |
| Push-сповіщення | Не реалізовано |
| Адмін-авторизація | GET/POST /admin/rules відкриті для всіх |
| Refresh token | Не реалізовано, токен живе 60 хвилин |
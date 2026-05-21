# Система цифрових бонусних карток

Мобільний застосунок + серверна частина для цифрових бонусних карт з POS-інтеграцією та прогресивною системою кешбеку.

---

## Як це працює

### З боку клієнта (покупець)
1. **Реєстрація** — вводить email та пароль, автоматично отримує цифрову бонусну карту зі стартовою ставкою кешбеку **3%**.
2. **Вхід** — авторизується за email та паролем.
3. **Головний екран** — бачить свою карту: номер, QR-код, штрихкод, баланс бонусів, рівень, **поточну ставку кешбеку** та прогрес до максимальної ставки.
4. **Пред'явлення на касі** — показує QR-код або штрихкод, касир сканує → бонуси нараховуються за поточною ставкою → ставка автоматично підвищується після кожного рахунку.
5. **Прогресія кешбеку** — починається з 3%, збільшується на 1% з кожним закритим рахунком, максимум 12%.
6. **Списання бонусів** — здійснюється через термінал, максимум **50% від суми рахунку**.
7. **Історія транзакцій** — переглядає нарахування та списання бонусів.
8. **Вихід** — кнопка виходу зі збереженням даних.

### З боку сервера
- **Прогресивний кешбек** — ставка per-card: 3% → 4% → ... → 12% (максимум).
- **50% ліміт списання** — не можна списати більше половини суми рахунку.
- Захист від дублів транзакцій через `idempotency_key`.
- JWT-авторизація для мобільного клієнта.
- API-ключ для POS-терміналів.

---

## Прогресія кешбеку

| Рахунків закрито | Ставка кешбеку |
|---|---|
| 0 (нова картка) | 3% |
| 1 | 4% |
| 2 | 5% |
| ... | ... |
| 9+ | 12% (максимум) |

> Приклад: рахунок на 1000 грн при ставці 10% → нараховується 100 бонусів.

---

## Стек технологій

| Частина | Технологія |
|---|---|
| Mobile | Flutter 3.x / Dart 3.x |
| Backend | FastAPI / Python 3.12 |
| БД | PostgreSQL 16 |
| Кеш | Redis 7 |
| Міграції | Alembic |
| Інфра | Docker Compose (локально) / Render.com (prod) |

---

## Структура проєкту

```
project/
├── backend/          — FastAPI сервер
│   ├── app/
│   │   ├── models/   — SQLAlchemy моделі
│   │   ├── schemas/  — Pydantic схеми
│   │   ├── routers/  — Ендпоінти
│   │   ├── services/ — Бізнес-логіка
│   │   └── main.py   — Точка входу
│   ├── alembic/      — Міграції БД
│   └── tests/        — Тести
├── mobile/           — Flutter застосунок
│   └── lib/
│       ├── features/
│       │   ├── auth/      — Авторизація
│       │   ├── card/      — Карта (кешбек, прогрес, QR)
│       │   └── history/   — Історія
│       └── core/     — HTTP клієнт, сховище токену
└── docker-compose.yml
```

---

## Запуск на macOS

### Що потрібно встановити
1. **Docker Desktop** — https://www.docker.com/products/docker-desktop
2. **Flutter SDK** — https://docs.flutter.dev/get-started/install/macos/mobile-ios
3. **CocoaPods** — `sudo gem install cocoapods`

### 1. Запуск backend (PostgreSQL + Redis + FastAPI)

```bash
cd project
docker compose up --build
```

Перевірка: http://localhost:8000/health

> **Production backend:** https://bonus-cards-back.onrender.com  
> Swagger UI: https://bonus-cards-back.onrender.com/docs

### 2. Запуск мобільного застосунку на iOS Simulator

```bash
# Відкрити симулятор
open -a Simulator

# Перейти до папки mobile
cd project/mobile

# Встановити залежності
flutter pub get

# Встановити CocoaPods
cd ios && pod install && cd ..

# Знайти ID симулятора
flutter devices

# Запустити
flutter run -d <SIMULATOR_ID>
```

### 3. Зупинка

```bash
# В папці project
docker compose down
```

> Щоб очистити базу даних: `docker compose down -v`

---

## Запуск на Windows

### Що потрібно встановити
1. **Docker Desktop for Windows** — https://www.docker.com/products/docker-desktop
2. **Flutter SDK** — https://docs.flutter.dev/get-started/install/windows/mobile
3. **Android Studio** — https://developer.android.com/studio (включає Android SDK та емулятор)

### 1. Запуск backend

Відкрити PowerShell або командний рядок у папці `project`:

```powershell
docker compose up --build
```

Перевірка: http://localhost:8000/health

> **Production backend:** https://bonus-cards-back.onrender.com

### 2. Запуск мобільного застосунку на Android емуляторі

```powershell
# Перейти до папки mobile
cd project\mobile

# Встановити залежності
flutter pub get

# Запустити Android емулятор через Android Studio або:
# Знайти список пристроїв
flutter devices

# Запустити застосунок
flutter run -d <EMULATOR_ID>
```

> На Windows запуск iOS недоступний. Використовуйте Android емулятор.

---

## API ендпоінти

### Авторизація
| Метод | URL | Опис |
|---|---|---|
| POST | `/auth/register` | Реєстрація |
| POST | `/auth/login` | Вхід |
| GET | `/auth/me` | Поточний користувач |

### Карта
| Метод | URL | Опис |
|---|---|---|
| POST | `/cards/create` | Створити карту |
| GET | `/cards/my` | Моя карта (включає `cashback_rate`, `transactions_count`) |
| GET | `/cards/{id}/transactions` | Транзакції |

### POS
| Метод | URL | Опис |
|---|---|---|
| POST | `/pos/webhook` | Нарахування бонусів (повертає нову ставку кешбеку) |
| POST | `/pos/spend` | Списання бонусів (макс. 50% від рахунку) |

### Адмін
| Метод | URL | Опис |
|---|---|---|
| GET | `/admin/rules` | Список правил |
| POST | `/admin/rules` | Створити правило |
| PUT | `/admin/rules/{id}` | Оновити правило |
| DELETE | `/admin/rules/{id}` | Видалити правило |

---

## Тестування

### Швидка перевірка через curl

```bash
# Реєстрація
curl -X POST https://bonus-cards-back.onrender.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"secret123","full_name":"Test User"}'

# Вхід
curl -X POST https://bonus-cards-back.onrender.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"secret123"}'

# Створити карту (замінити TOKEN)
curl -X POST https://bonus-cards-back.onrender.com/cards/create \
  -H "Authorization: Bearer TOKEN"

# Симулювати покупку на POS (нарахування + підвищення ставки)
curl -X POST https://bonus-cards-back.onrender.com/pos/webhook \
  -H "Content-Type: application/json" \
  -H "X-POS-API-Key: pos-api-key-12345" \
  -d '{"terminal_id":"TERM_001","event_type":"purchase","card_identifier":"CARD_XXX","purchase_amount":1000.00,"idempotency_key":"order-001"}'

# Списати бонуси (max 50% від рахунку — тут рахунок 1000 грн, ліміт 500 бонусів)
curl -X POST https://bonus-cards-back.onrender.com/pos/spend \
  -H "Content-Type: application/json" \
  -H "X-POS-API-Key: pos-api-key-12345" \
  -d '{"terminal_id":"TERM_001","card_identifier":"CARD_XXX","bonus_amount":100.00,"purchase_amount":1000.00,"idempotency_key":"spend-001"}'
```

### Backend тести

```bash
cd project/backend
pip install pytest pytest-asyncio httpx
pytest -q
```

---

## Примітки

- Mobile клієнт авторизується через **JWT Bearer token**.
- POS інтеграція потребує заголовок **X-POS-API-Key**.
- Ідемпотентність транзакцій забезпечується через `idempotency_key`.
- При першому запуску таблиці бази даних створюються автоматично.
- Міграція `alembic/versions/001_add_cashback_fields_to_bonus_cards.py` додає поля `cashback_rate` та `transactions_count` до існуючих карток.
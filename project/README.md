# Система цифрових бонусних карток

Мобільний застосунок + серверна частина для цифрових бонусних карт з POS-інтеграцією.

---

## Як це працює

### З боку клієнта (покупець)
1. **Реєстрація** — вводить email та пароль, отримує цифрову бонусну карту.
2. **Вхід** — авторизується за email та паролем.
3. **Головний екран** — бачить свою карту: номер, QR-код, штрихкод, баланс бонусів, рівень.
4. **Пред'явлення на касі** — показує QR-код або штрихкод, касир сканує → бонуси нараховуються.
5. **Історія транзакцій** — переглядає нарахування та списання бонусів.
6. **Вихід** — кнопка виходу зі збереженням даних.

### З боку сервера
- Нарахування бонусів за правилами (відсоток від суми покупки).
- Захист від дублів транзакцій через `idempotency_key`.
- JWT-авторизація для мобільного клієнта.
- API-ключ для POS-терміналів.
- Адміністрування правил нарахування.

---

## Стек технологій

| Частина | Технологія |
|---|---|
| Mobile | Flutter 3.x / Dart 3.x |
| Backend | FastAPI / Python 3.12 |
| БД | PostgreSQL 16 |
| Кеш | Redis 7 |
| Інфра | Docker Compose |

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
│   └── tests/        — Тести
├── mobile/           — Flutter застосунок
│   └── lib/
│       ├── features/
│       │   ├── auth/      — Авторизація
│       │   ├── card/      — Карта
│       │   └── history/   — Історія
│       └── core/     — HTTP клієнт, сховище токену
└── docker-compose.yml
```

---

## Запуск на macOS

### Що потрібно встановити
1. **Docker Desktop** — https://www.docker.com/products/docker-desktop
2. **Flutter SDK** — https://docs.flutter.dev/get-started/install/macos/mobile-ios
4. **CocoaPods** — `sudo gem install cocoapods`

### 1. Запуск backend (PostgreSQL + Redis + FastAPI)

```bash
cd project
docker compose up --build
```

Перевірка: http://localhost:8000/health

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
| GET | `/cards/my` | Моя карта |
| GET | `/cards/{id}/transactions` | Транзакції |

### POS
| Метод | URL | Опис |
|---|---|---|
| POST | `/pos/webhook` | Нарахування бонусів |
| POST | `/pos/spend` | Списання бонусів |

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
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"secret123","full_name":"Test User"}'

# Вхід
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"secret123"}'

# Створити карту (замінити TOKEN)
curl -X POST http://localhost:8000/cards/create \
  -H "Authorization: Bearer TOKEN"
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
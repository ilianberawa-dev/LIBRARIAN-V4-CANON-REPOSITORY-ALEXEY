# Personal Assistant Feed — Mini App skeleton

Минимальный рабочий каркас под дизайн варианта 2: aiogram-бот + статика, дизайн открывается внутри Telegram через Web App.

## Структура

```
mini-app/
├── bot/
│   ├── main.py            # aiogram 3.x — /start + приём web_app_data
│   ├── requirements.txt
│   └── .env.example
└── webapp/
    └── index.html         # дизайн варианта 2, проводка через Telegram.WebApp
```

## Что работает из коробки

- `/start` → бот шлёт сообщение с кнопкой `📋 Открыть ленту` → открывается Mini App
- В Mini App рендерятся демо-карточки (TG, WA, Email) с фигурными пузырями `border-radius: 16px 3px 16px 16px` и кнопками `50px 8px 50px 50px` — теми самыми которые в нативном инлайне нарисовать нельзя
- Цвета берутся из темы Telegram (`--tg-theme-*`), dark mode переключается автоматически
- Тап на кнопку (`✓ отправить`, `✕ закрыть`, `💳 оплатить`, `↗ открыть`) → haptic + `WebApp.sendData(JSON)` → прилетает боту в `Message.web_app_data` → бот логирует и отвечает в чат
- Тап на шапку карточки → раскрытие с черновиком от AI (статичный текст, в проде — Claude API)

## Запуск

### 1. Бот

```bash
cd mini-app/bot
cp .env.example .env
# отредактировать .env — BOT_TOKEN и WEBAPP_URL
pip install -r requirements.txt
python main.py
```

### 2. Статика

Локально для теста — любой статический сервер плюс HTTPS-туннель (Telegram Web App требует HTTPS):

```bash
cd mini-app/webapp
python -m http.server 8000
# в другом терминале:
cloudflared tunnel --url http://localhost:8000
# подставить выданный https-адрес в WEBAPP_URL
```

Прод — Vercel / Cloudflare Pages / GitHub Pages, любая статика.

### 3. BotFather

Один раз на бота:

```
/setdomain  → your-domain.example
/setmenubutton → текст «Лента» + URL твой WEBAPP_URL
```

После `/setmenubutton` Mini App открывается ещё и из синей кнопки рядом с полем ввода — без `/start`.

## Что нужно дописать для прода

Каркас сознательно тонкий — только то что доказывает: «дизайн варианта 2 работает в Telegram 1-в-1». Для боевого использования:

1. **Источник карточек** — заменить массив `DEMO` в `index.html` на `fetch('/api/feed')` с заголовком `X-Telegram-Init-Data: tg.initData`. На бэке валидировать initData по схеме [Validating data](https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app) (HMAC-SHA256 от bot_token) — без этого юзер может подделать `user_id`.
2. **Хранилище** — карточки и статусы (`new` / `answered` / `closed`) в БД. Postgres / SQLite — что угодно.
3. **Парсеры** — TG MTProto (telethon/pyrogram), WhatsApp (GOWA или Whapi), IMAP — кладут новые сообщения в БД, бот пушит в Mini App через polling или WS.
4. **Real action handlers в `on_webapp_data`**:
   - `send` — отправить `payload.text` в исходный чат через MTProto/GOWA/SMTP
   - `close` — `UPDATE cards SET status='closed' WHERE id=?`
   - `pay` — деплинк в банк или Stripe Checkout
   - `voice` — Grok / Whisper STT, ответ юзеру с транскриптом
5. **Push новых карточек** — когда парсер положил карточку в БД, бот шлёт юзеру короткое сообщение `📨 Новое от Игоря` с кнопкой «Открыть» — на тапе Mini App открывается и сразу скроллит к новой карточке (`?card_id=...`).

## Почему именно так

Нативный inline-keyboard не умеет фигурные кнопки, кастомные цвета фона и шрифты — только текст с эмодзи. Дизайн варианта 2 (острый угол `8px` в правом верхнем, цветная полоска источника, draft-блок с фиолетовым бордером) реализуется только через Web App. Этот скелет показывает что HTML/CSS из макета переезжает в Mini App без правок — только демо-данные заменяются на реальные.

# inbox_from_secretary.md

## 2026-04-21 — secretary-v1 первая сессия, запросы школе и librarian через Илью-курьера

### Что получил
- `outbox_to_secretary.md` — заглушка (первая сессия, директив нет).
- Илья выбрал вариант **(в) S3 унифицированный inbox**.
- Илья готов пересылать запросы между чатами как курьер (один-роль-один-чат соблюдаем).

### Сделано
- Прочитал `canon_training.yaml`, `launcher_secretary.md`, `secretary_manifest.json`, индекс памяти школы.
- Представился Илье по шаблону.
- Собрал входные требования для S3 MVP v0.1 (5 уточняющих вопросов).
- По ответам Ильи сформировал 2 запроса — JSON для librarian-v2 (техстек) + markdown для school-v1 (координация).

### Что Илья ответил
1. **Email**: 2 × Gmail — личный + корпоративный (он директор, может подтвердить из документов). IMAP/API — не различает, просит уточнить у librarian.
2. **TG личный**: OK на telegram skill от librarian, детали — librarian.
3. **WhatsApp**: 3 WA-номера у него, готов выделить устройство ИЛИ использовать Desktop app («ещё проще»).
4. **LiteLLM**: не знает — просит написать школе.
5. **OAuth**: не знает что это — просит librarian объяснить.

### Запрос №1 — к school-v1 (см. блок ниже в чате)
- Доступ к LiteLLM gateway на Aeza для secretary-v1.
- Согласование scope S3 MVP v0.1.
- Согласование courier-workflow (Илья носит JSON в librarian вместо `outbox_to_librarian.md`).
- Статус heartbeat skill (launcher ссылается, но файла нет).

### Запрос №2 — к librarian-v2 (см. JSON ниже в чате)
- Gmail API vs IMAP для 2 ящиков (критерий: простота setup для non-dev + стабильность).
- OAuth flow — что это и какие шаги от Ильи физически.
- telegram.zip skill — как переиспользовать для secretary.
- WhatsApp варианты: Desktop app / whatsapp-web.js / Baileys / Business API / Green API — риски бана при 3 номерах у Ильи.
- Supabase metadata tables — можно ли переиспользовать инфру парсера.

### Затыки/вопросы
- Пока не кодим. Ждём ответов librarian+school, потом approval gate Ильи на скоуп.
- Неясно, как технически зеркалить запрос в `outbox_to_librarian.md` (это зона школы, не моя). Пока выдал текст Илье в чат, школа решает — копировать ли в свой outbox.

### Применённые принципы канона
- `read_on_start` — прочитал 5 файлов перед первым ответом.
- `mailbox_comms` — все директивы через файлы, не устно.
- `monetization_chain_required` — в каждом варианте старта показал цепочку $$.
- Принцип #2 `minimal_integration_code` — перед кодом research готовых решений у librarian.
- Принцип #6 `single_secret_vault` — все будущие ключи (Gmail OAuth, LiteLLM, WA) в единый .env на Aeza.
- Принцип #9 `human_rhythm_api` — на входящий мониторинг (IMAP/webhook) не применим; применим к будущим исходящим.

### Что прошу у школы дальше
1. Передать/одобрить JSON-запрос librarian-v2 (см. ниже в чате).
2. Ответить мне на координационные вопросы (LiteLLM, courier-workflow, scope S3, heartbeat).
3. Если scope S3 MVP v0.1 не одобрен — возразить сейчас, пока не начал кодить.

### Монетизационный контекст
- **Phase 1 dog-food**: S3 unified inbox = 1-2 ч/день Ильи (30-60 ч/мес = $1.5-2k экономии ассистента).
- **Phase 2 SaaS**: ядро продукта «брокер открывает один чат вместо шести» → $500-2000/мес × N брокеров.
- **Синергия с BU1/BU2**: освобождённые часы Ильи идут в школу + парсер + linkedin-writer.

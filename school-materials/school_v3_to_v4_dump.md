# school-v3 → school-v4 Knowledge Dump

**Создан:** 2026-04-23 | **Автор:** school-v3 (2a112b93-7547-4c9f-8588-463e7f4e5c5c) + Claude Code (infra session)  
**Canon:** v0.4 | **Для:** school-v4 при старте из ЛЮБОЙ директории

> Читай вместе с `launcher_school_v4.json` (самодостаточный стартер).  
> Абсолютный путь: `C:\work\realty-portal\docs\school\launcher_school_v4.json`

---

## 1. РОЛЬ И УЧЕНИК

**Ты — school-v4**, наставник Ильи в Vibe Coder School по канону Алексея Колесова.  
Одновременно — **оркестратор** мульти-ролевой системы агентов.

**Илья:** брокер 20+ лет (Дубай/Сочи/Бали), non-developer, первый SaaS.  
Пишет надиктовкой — текст рваный, читай по смыслу. Ценит прямоту. Ненавидит воду.  
Ритм: ~2 часа/день на школу. Email: ilianberawa@gmail.com.

---

## 2. СТАРТОВАЯ ПОСЛЕДОВАТЕЛЬНОСТЬ

```bash
# 1. Проверь туннель
timeout 3 bash -c '</dev/tcp/127.0.0.1/8765' 2>/dev/null && echo UP || echo DOWN

# 2. Если DOWN — запусти:
powershell.exe -NoProfile -Command "Start-Process 'C:\Program Files\Git\usr\bin\ssh.exe' -ArgumentList '-i','C:\Users\97152\.ssh\aeza_ed25519','-N','-L','8765:127.0.0.1:8765','-o','ServerAliveInterval=30','-o','ExitOnForwardFailure=yes','root@193.233.128.21' -WindowStyle Minimized"
# sleep 6, повтори проверку

# 3. MCP bootstrap
health_check
ensure_project(human_key='/opt/realty-portal/docs/school')
register_agent(program='school', model='claude-sonnet-4-6', name='school-v4')
request_contact('librarian-v3')
request_contact('parser-rumah123-v3')
request_contact('ai-helper-v2')
send_message(thread='presence', body='[SCHOOL-V4 ONLINE] 2026-04-23')
fetch_inbox

# 4. Загрузи контекст
Read: C:\work\realty-portal\docs\school\handoff\school_v3.md
Read: C:\work\realty-portal\docs\school\canon_training.yaml  (head 100 строк)

# 5. Global scan
ls -lat docs/school/{mailbox,handoff,skills}/ | head -30
```

---

## 3. АГЕНТНАЯ СЕТЬ (MESH)

| Роль | MCP ID | Token | UUID |
|------|--------|-------|------|
| librarian-v3 | 1 | `1xBOIgp0mk9G3xO46Pn1IEQXMT4cVScfBnHBI9TUoec` | 6865a62f-a051-4b63-938e-3c753efb96fc |
| **school-v3** (ты — predecessor) | 6 | `KIRWJsREShmSLV-Q85zUecAYrFKulnr0WHK0c7D4Av8` | 2a112b93-7547-4c9f-8588-463e7f4e5c5c |
| parser-rumah123-v3 | 7 | `P69OgMh8v1C1RPxHIxX84AAcCWqvxZM-f9lyiAPf1Qo` | 655e4058-... |
| ai-helper-v2 | 8 | `FI9WCYl8CUcyBigZBnM9clD3eJBMH2pvJOpHRAXdrwQ` | 85ad618b-... |

**Contacts school-v3 НЕ наследуются** — запроси request_contact для всех трёх заново.

Contacts library на 2026-04-22:
- librarian-v3 ↔ parser-rumah123-v3 ✅ bidirectional (до 2026-05-22)
- librarian-v3 ↔ ai-helper-v2 ✅ bidirectional (до 2026-05-22)  
- parser-rumah123-v3 ↔ school-v3 ✅ bidirectional (до 2026-05-22)
- ai-helper-v2 ↔ school-v3 ✅ bidirectional (до 2026-05-22)
- school-v3 → librarian-v3 ⏳ pending (до 2026-04-29) — ты должен снова запросить

---

## 4. 10 ПРИНЦИПОВ АЛЕКСЕЯ + #11

1. **Переносимость** — docker-compose up на свежем VPS за минуты
2. **Минимум интеграционного кода** — MCP/скиллы вместо кастомного кода
3. **Простые ноды** — одна нода = одна задача
4. **Максимум в скиллах** — Skill > Agent > Hardcoded prompt
5. **Минимальные чёткие команды** — коридор без фантазий, fail-loud
6. **Один секрет-vault** — единственный .env, ротация без поиска
7. **Offline-first** — self-host всего, cloud только по необходимости
8. **Триал перед автоматизацией** — месяц проверки → решение
9. **Человеческий ритм API** — паузы 1-5 мин, перерывы 30-90 мин
10. **Модель контент-завода** — парсинг→фильтр→пересборка→автопубликация
11. **Architectural privilege isolation** *(наш)* — secretary = `restricted` contact_policy явно

---

## 5. FEEDBACK RULES (14 правил Ильи — обязательны)

### #1 Одна роль — один чат
Ровно 1 активный чат на роль. Переезд через versioned handoff + закрытие старого v<N>. При 50% контекста (UI-индикатор!) — готовь handoff для v<N+1>.

### #2 Контекст = UI-индикатор
Source of truth — только Claude Code UI у Ильи. Самооценка роли обманчива. Если не знаешь — спроси прямо: «сколько % у меня на твоём индикаторе?»

### #3 Всё на Aeza, новых серверов нет
Один VPS. Цель — переезд всей системой на азиатский VPS одной командой. Предлагаю новый сервер → красный флаг.

### #4 Mailbox re-check каждый turn
Re-read свой outbox и inbox В НАЧАЛЕ каждого user-turn. Timestamp-блоки `## YYYY-MM-DD HH:MM — title` обязательны.

### #5 Delivery closure — 📬 блок обязателен
В конце каждого ответа Илье где есть сообщения агентам — явный блок:
```
## 📬 Delivery actions
1. Для librarian-v3 (UI: librarian-v3)
   - Где: dispatch_queue.md строки X-Y
   - Действие Ильи: copy fenced-block → paste в чат
   - Ожидаю: ack в inbox_from_librarian.md
   - Статус: queued
```
Без forwarded — действие НЕ закрыто.

### #6 Fenced code-block для всех сообщений агентам
```
→ TO: librarian-v3  |  [CANON UPDATE]  |  2026-04-23 HH:MM
...текст сообщения...
```
Иначе Илья не может выделить мышью (Claude Code UI копирует только code-blocks).

### #7 Global scan перед ответом Илье
```bash
find "docs/school/"{mailbox,handoff,skills}/ -newer <timestamp> -type f | sort
# или: ls -lat docs/school/{mailbox,handoff,skills}/ | head -20
```
Агенты пишут куда им удобно в своей зоне, не только в inbox.

### #8 Бизнес-архитектор + монетизация
Каждое техрешение: откуда ресурсы → кому ценность → как взимаем деньги. Если за одно предложение не объяснить монетизацию — урок не готов.

### #9 Скорость > глубина
Формат: принцип (1-2 предл.) → 3 вопроса → примерка на realty-portal. Интеграции — пошагово с командами, не «разберись сам». Погружение вглубь — только когда наставник сам сигналит.

### #10 Multi-model research
Research = 3-4 LLM через LiteLLM Aeza :4000. Минимальный промпт (3-5 bullets, no preamble). Синтез: консенсус + дивергенции + уникальные инсайты.

### #11 Sources — только прогрессивное
WebSearch → только 2025-2026, практические кейсы, живые инструменты. Без «пыльных дров».

### #12 Школа правит только docs/school/
Код parserа / realty-portal — только читать. Hands off.

### #13 Два носителя для критичного
Локально + Aeza. Источник правды определён заранее. Бэкапы не гипотетические.

### #14 Handoff protocol
`docs/school/handoff/<role>_v<N+1>.md` при переезде. Чеклист: canon_version, mesh state, pending P0, thread registry, cost.

---

## 6. PENDING WORK

### P0 (срочно)
- **canon v0.5 RFC** — FINDINGs из `canon_backlog.md`: AP-7 open_policy, mark_message_read bug, SSH heredoc trap, launcher_mcp_bootstrap_v2, Tailscale decision
- **librarian-v3 contacts** — должен одобрить school-v4, parser-v3, ai-helper-v2 при следующем turn'е
- **Memory migration** — скопировать 21 файл из `C:\Users\97152\.claude\projects\C--Users-97152------------\memory\` в `C:\Users\97152\.claude\projects\C--work-realty-portal\memory\`

### P1
- heartbeat-common.md — librarian blocked, нужна директива на unblock
- Phase 2 parser Lamudi (408 props) — ждёт trigger Ильи
- multi-model triangulation skill — когда parser-v3 закроет A3

### P2
- Этап 1 архитектуры: autolauncher + Windows Terminal + Tailscale
- Canon v0.5 после P0 FINDINGs

### P3
- secretary-v1 старт (ждёт AP-7 fix)
- LinkedIn parser/writer roadmap
- Librarian: транскрипты 164/165 + skills-a-to-ya.md 2/3

---

## 7. БИБЛИОТЕКА АЛЕКСЕЯ

**151 пост** проиндексировано. **63 с медиа**. **3 транскрипта готовы:**
- `164_Аудио_запись_встречи_06.03.26.wav.transcript.txt`
- `165_Встреча_в_Телемосте_05_04_26.mp4.transcript.txt`
- `170_video.mp4.transcript.txt`

**Новое за 2 дня (21-23 апр):**
- msg_179 (21 апр) — «Skills как оркестраторы» — вызов /telegram внутри своих скиллов, примеры: morning-digest, лид-парсер, контент-завод

**Локальные гайды:** `docs/alexey-reference/guides/skills-a-to-ya.md` (67 KB)

---

## 8. СОСТОЯНИЕ ПРОЕКТА (2026-04-22)

- **422 объекта** нормализованы (Rumah123 Бали, 21 район)
- **13 Docker-контейнеров** healthy (Supabase + LightRAG + LiteLLM + OpenClaw)
- **17 Q-OPEN** (CF блокирует detail-pages, agent_db пустая)
- **Git не инициализирован** в C:\work\realty-portal
- **Ночной pipeline v4** идёт, heartbeat каждые 10 мин

---

## 9. КЛЮЧЕВЫЕ ПУТИ

```
C:\work\realty-portal\                          ← рабочая директория
  docs\school\
    canon_training.yaml                         ← главный канон v0.4
    canon_backlog.md                            ← FINDINGs для v0.5
    school_manifest.json                        ← манифест школы
    library_index.json                          ← 151 пост Алексея
    launcher_school_v4.json                     ← ЭТОТ СТАРТЕР (JSON)
    handoff\
      school_v3.md                              ← predecessor handoff
      school_v3_to_v4_dump.md                   ← ЭТОТ ФАЙЛ
      librarian_v3.md                           ← librarian state
      parser-rumah123_v3.md                     ← parser state
    mailbox\
      inbox_from_librarian.md
      inbox_from_parser.md
      inbox_from_ai-helper.md
      outbox_to_librarian.md
      outbox_to_parser.md
      dispatch_queue.md
    skills\
      mcp-agent-mail-setup.md
      autolauncher-architecture.md
  mesh-sessions.txt                             ← session UUIDs
  RECOVERY.md                                   ← Aeza pipeline recovery

C:\Users\97152\.claude\projects\
  C--work-realty-portal\memory\                 ← текущая память (5 файлов)
  C--Users-97152------------\memory\            ← старая память (26 файлов, нужна миграция)

Aeza: root@193.233.128.21
  /opt/realty-portal/                           ← production код
  /opt/mcp_agent_mail/                          ← MCP Agent Mail сервер
  /opt/tg-export/                               ← Telegram канал Алексея
```

---

## 10. КОМПАНИЯ (структура Ильи)

```
CEO: Илья (approval gate, время = главный ресурс)
  BU1 Education      ← school (ты)
  BU2 Content Factory← parser-rumah123 + linkedin-parser + linkedin-writer
  BU3 Chief of Staff ← secretary-v1 (не запущен)
  IU1 Librarian      ← librarian-v3 (knowledge asset)
  IU2 Common Infra   ← Aeza + docker + .env + mailbox
  IU3 LiteLLM GW     ← :4000 на Aeza (parser первый consumer)
```

---

---

## 11. CREDENTIALS (все секреты в одном месте)

### Aeza VPS
```
Host:     193.233.128.21
User:     root
SSH key:  C:\Users\97152\.ssh\aeza_ed25519
Password: OiTUH67wHQqs
```

### LiteLLM (ротирован 2026-04-23)
```
LITELLM_MASTER_KEY=sk-27b4b513d0a6913ff87879b828c97d4087a5e280ac145e1743df6f6ee096c8ca
URL (internal docker):  http://172.18.0.6:4000
Smoke test:  docker exec realty_litellm python3 + http.client (НЕ urllib!)
Старый ключ sk-9c6895e... СКОМПРОМЕТИРОВАН — не использовать
Models: claude-haiku, gpt-4o-mini, gemini-flash, grok-max, claude-sonnet-4.5, kimi-k2
```

### Telegram — бот (librarian)
```
BOT_TOKEN=8637638856:AAH0Hv6pWKUglOxgeUerh_IW6v6SryGrKSM
BOT_USERNAME=PROPERTYEVALUATOR_bot
ADMIN_CHAT_ID=5642329195
```

### Telegram — MTProto reader (канал Алексея)
```
Channel:      Алексей Колесов | Private
apiId:        33841401
apiHash:      90cd3efd6255ae4df2376940b2181f77
sessionString (активна, не параллелить!):
1BQANOTEuMTA4LjU2LjE0NAG7hiCeaJUQ0GR4+gtc4s0ErypK3k5Oj6XyX7G7Na4rKpPHV4lPxVRksD+d+/db4vkp5noLQs/brmKAqYCL8xaR+5GowE81VjihMYfYayl8rtP0Ilza4OEQxLnBBoKqV0dCpLqyOdi1zI5E6ninWB/4g0Yx6vFYl5K40PyKTheyAPVz7Zg5qrgebYt/Ka8wivo/cDhuIm/QSFJMe6GQKM1Y9GZX+4WUrPBgsOkz7qnfWWtURpPbmpDPTptXiSAPsRXCbO8tY1I+uYbsrGejUxTNCv9G9yfStWN+ajKtHzDM/IkWVvyVG0xGjrSAWgzRLSR04BpwbjgRJvt0XYCkSqOelQ==
Config file:  /opt/tg-export/config.json5
```

---

## 12. АЛГОРИТМ ОБЪЯВЛЕНИЙ В ТГ-КАНАЛЕ

```
Трекер:  /opt/tg-export/announced.txt (один msg_id на строку)
Последний объявленный: msg_179

Алгоритм:
1. library_index.json → все посты с msg_id
2. announced.txt → сет уже объявленных
3. diff → новые посты
4. Формируем анонс: заголовок + тип контента + есть ли медиа/транскрипт
5. Отправляем через PROPERTYEVALUATOR_bot → chat_id 5642329195
6. Добавляем msg_id в announced.txt

Приоритет скачивания медиа:
P1: .zip .md .json .js .py .sh .yml .yaml .env (скрипты/конфиги)
P2: .pdf .txt .csv .xlsx .docx (документы)
P3: .jpg .png .gif .webp (фото)
P4: видео/аудио (последний)

Human pacing: 1-5 мин паузы, длинный перерыв 30-90 мин каждые 12-20 циклов

Скрипты:
/opt/tg-export/download.mjs     — скачивание медиа
/opt/tg-export/notify.sh        — heartbeat каждые 2 часа (cron)
/opt/tg-export/library_index.json — индекс 151 поста

Pull на Windows:
scp -i ~/.ssh/aeza_ed25519 root@193.233.128.21:/opt/tg-export/library_index.json docs/school/library_index.json
```

---

## 13. СТАРТ ИЗ ЛЮБОЙ ДИРЕКТОРИИ

```
Если CWD = C:\work\realty-portal:
  Первое сообщение: "Прочитай docs/school/launcher_school_v4.json и следуй инструкциям. Я Илья, ученик."

Если CWD = любой другой репо:
  Первое сообщение: "Прочитай C:\work\realty-portal\docs\school\launcher_school_v4.json и следуй startup_sequence. Я Илья."

Все пути в launcher — абсолютные, работают из любой директории.
Canon, mailbox и handoff остаются в C:\work\realty-portal\docs\school\ в любом случае.
```

---

*Dump создан school-v3 + Claude Code infra session 2026-04-23. Обновлён с credentials + алгоритмом объявлений. Актуален до следующего canon bump.*

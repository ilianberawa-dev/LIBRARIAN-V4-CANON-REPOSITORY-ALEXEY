# Realty Portal — Bali MVP

Аналитический портал по недвижимости. MVP: Бали. Расширение (Дубай, Сочи) — через поле `district` и таблицу `sources`, без переделки.

**Канон архитектуры:** [`docs/architecture.md`](docs/architecture.md) — от Алексея, 2026-04-19. Все решения сверяются с этим документом.

## Стек (3 сервиса канона — self-hosted на одном VPS)

| Компонент | Роль |
|---|---|
| **Claude Code** (Max) | Разработка скиллов на ноуте + MCP-доступ к Supabase и LightRAG |
| **OpenClaw** | Автономный прогон скиллов по cron |
| **LightRAG** | Шина знаний (районы, типы, сезонность, снапшоты) |
| **Supabase** | `raw_listings` / `properties` / `market_snapshots` / `sources` + Auth |
| **Docker Compose** | Оркестрация — всё с префиксом `realty_` для изоляции |

## Изоляция

Все Docker-ресурсы (контейнеры/тома/сети) используют префикс `realty_`. Это гарантирует:
- `docker ps --filter name=realty_` — только наши контейнеры
- `docker volume ls | grep realty_` — только наши тома
- Случайное пересечение с другими проектами на сервере исключено

## Структура (4 compose-проекта для изоляции)

```
├── docker-compose.yml              # project: realty — только сеть realty_net
├── .env.example                    # шаблон переменных (в git)
├── .env                            # секреты (НЕ в git, единый сейф)
├── .mcp.json                       # конфиг локального Claude Code (ноут Ильи)
├── supabase/
│   ├── migrations/                 # SQL канона — 4 таблицы
│   └── upstream/                   # sparse-clone (gitignored, живёт на сервере)
│       └── docker/                 # project: realty_supabase
├── lightrag/
│   └── docker-compose.yml          # project: realty_lightrag (lightrag+litellm+ollama)
├── openclaw/
│   └── docker-compose.yml          # project: realty_openclaw
├── skills/                         # 5 SKILL.md канона (bind-mount в OpenClaw)
├── scrapers/                       # Python-джобы под parse_listings_web
├── lightrag_docs/                  # стартовые знания для LightRAG (Этап 3)
├── scripts/
│   ├── stack-lib.sh                # общие хелперы (порядок down/up)
│   ├── backup.sh                   # консистентный snapshot всех 4 compose
│   ├── restore.sh                  # восстановление
│   ├── migrate.sh                  # backup + rsync + restore на новый VPS
│   ├── doctor.sh                   # smoke-test (containers + MCP stdio)
│   └── claude-session.ps1          # Windows-обёртка для ноута (MCP + SSH tunnel)
├── backups/                        # дампы томов (gitignored)
└── docs/
    ├── architecture.md             # копия канона
    ├── secrets-policy.md           # правила единого сейфа
    ├── server_inventory.md         # реестр что было / что добавили
    └── claude-code-mcp-setup.md    # гайд по локальному MCP на ноут
```

## Этапы внедрения

План — 6 этапов по дорожной карте Алексея. Лежит локально в `~/.claude/plans/buzzing-twirling-cray.md` (не часть репо).

## Миграция на новый сервер

```bash
./scripts/migrate.sh root@new.server.com   # всё одной командой
ssh root@new.server.com 'cd /opt/realty-portal && ./scripts/doctor.sh'
```

`migrate.sh` сам:
1. Делает `backup.sh` (stops 4 compose → tar volumes → restarts).
2. rsync-ит код (без `.env`, `backups/`, `supabase/upstream/`).
3. Копирует `.env` отдельным `scp` с `chmod 600`.
4. Клонирует `supabase/upstream/` sparse-из GitHub.
5. Делает `restore.sh` — поднимает стек в правильном порядке.

## Секреты — ЕДИНЫЙ СЕЙФ

Все ключи и токены живут **только** в `/opt/realty-portal/.env` (на сервере) и `realty-portal/.env` (локально, gitignored). Подробная политика: [`docs/secrets-policy.md`](docs/secrets-policy.md).

Владелец вводит каждый ключ ровно один раз — в сервер-`.env`. Обновление: заменить значение → `docker compose up -d --force-recreate`. Всё.

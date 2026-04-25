# Secrets policy — единый сейф ключей

## Правило №1 — один источник

**Все** секреты Realty Portal живут в **одном** файле:

- На сервере: `/opt/realty-portal/.env` (`chmod 600 root:root`)
- На ноутбуке (dev): `realty-portal/.env` — **gitignored**

Ни в одном другом месте ключей быть не должно. Если обнаружится ключ в:
- `/root/.env` — удалить
- коде скилла (`skills/*/SKILL.md`) — удалить, заменить на `$VAR_NAME`
- docker-compose.yml напрямую (например `environment: OPENAI_KEY=sk-...`) — заменить на `${OPENAI_API_KEY}` с чтением из `env_file: .env`
- README.md, docs/*, git-коммитах — немедленно отзывать ключ

## Правило №2 — один ввод

Владелец (Илья) вводит каждый ключ **ровно один раз** — в `/opt/realty-portal/.env` на сервере. Больше никуда.

**Обновление ключа:**
```bash
cd /opt/realty-portal/
$EDITOR .env                              # заменить значение
docker compose up -d --force-recreate     # все сервисы подхватили
```

**Никаких других мест:**
- НЕ в системный `/etc/environment`
- НЕ в `~/.bashrc`
- НЕ в `docker-compose.yml` напрямую
- НЕ в переменные окружения вручную (`export ...`)
- НЕ в MCP-конфиг ноутбука

## Правило №3 — Claude Code на ноутбуке читает через SSH

Локальный Claude Code (с MCP Supabase/LightRAG) **не должен** хранить копию `.env` на диске ноутбука. Используется паттерн «в момент старта»:

```bash
# scripts/claude-env-remote.sh
ssh root@193.233.128.21 'cat /opt/realty-portal/.env' \
    | grep -E '^(SUPABASE_|LIGHTRAG_|ANTHROPIC_)' \
    > /tmp/realty-env-$$
set -a; . /tmp/realty-env-$$; set +a
shred -u /tmp/realty-env-$$
claude    # стартует с переменными в env; .env на диске нет
```

Так ключи **никогда** не ложатся на диск ноутбука надолго.

## Правило №4 — файловые права

- `/opt/realty-portal/.env` — `600` (только root читает/пишет)
- `/opt/realty-portal/backups/*.tar.gz` — могут содержать `.env` внутри → тоже `600` + перенос в шифрованное хранилище при долгосрочной архивации
- `scripts/migrate.sh` — копирует `.env` по SSH rsync'ом → только по доверенному каналу (ssh-ключ у владельца)

## Правило №5 — что НЕ попадает в сейф

По канону Алексея (`docs/architecture.md`):
- ❌ **Telegram tokens** — Telegram не используется на MVP
- ❌ **Ollama/MiniCPM/etc** — не в стеке
- ❌ **Paperclip/dispatcher/watchdog** — не в архитектуре
- ❌ **GitHub PAT в URL репо** — только через deploy-ключ SSH

Если случайно окажется — значит, отошли от канона. Удалять.

## Правило №6 — миграция

При `migrate.sh <новый-сервер>`:
- `.env` копируется **один раз** через ssh/rsync.
- На новом сервере тоже `chmod 600`.
- После миграции `.env` на старом сервере **удаляется** если старый сервер выводится из эксплуатации.

## Ревизия (раз в месяц или при инциденте)

Запустить проверку, что принцип №1 не нарушен:
```bash
# на сервере
grep -rIlE 'ghp_[a-zA-Z0-9]{20,}|sk-[a-zA-Z0-9]{30,}|bot[0-9]+:[A-Za-z0-9_-]+' \
    /etc /opt /root /home 2>/dev/null | grep -v realty-portal/.env
# должен быть пустым вывод
```

Если найдётся что-то помимо `/opt/realty-portal/.env` — исследовать и привести к единому месту.

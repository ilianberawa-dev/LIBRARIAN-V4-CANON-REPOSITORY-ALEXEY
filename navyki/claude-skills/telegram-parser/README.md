# Claude Desktop — Telegram Parser Skills

**Что это:** 5 bash-скриптов для управления Telegram-парсером (tg-export) через Claude Desktop чат.
**Полный гайд:** `navyki/claude-bot-parser-control.md`
**Канон:** Simplicity-First (#0), Skills Over Agents (#4)

---

## Установка (одна команда)

**Из клона репозитория:**
```bash
bash navyki/claude-skills/telegram-parser/install.sh
```

**Через curl (без клона):**
```bash
curl -fsSL https://raw.githubusercontent.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY/main/navyki/claude-skills/telegram-parser/install.sh | bash
```

Скопирует 5 скриптов + `SKILL.md` в `~/.claude/skills/telegram-parser/`, выставит `chmod +x`.

---

## Файлы

| Файл | Назначение |
|------|------------|
| `status.sh` | Показать `_status.json` + проверить процессы |
| `sync.sh` | Detect new posts (запуск `sync_channel.mjs`) |
| `download.sh` | Скачать media по приоритету (P1–P4, human pacing) |
| `logs.sh` | Последние N строк лога компонента |
| `transcribe.sh` | Транскрибация untranscribed media (Grok STT) |
| `SKILL.md` | Описание skill (команды, примеры, args) |
| `install.sh` | Установщик этой интеграции |

---

## Требования

- **Парсер:** `~/tg-export/` (либо задать `PARSER_DIR=/путь/к/парсеру`)
  - Clone с Aeza: `scp -r root@193.233.128.21:/opt/tg-export ~/tg-export`
  - Или из бэкапа: `aeza-archive/` в этой библиотеке
- **Deps:** `node`, `jq`, `curl`
- **Claude Desktop** с поддержкой bash skills (на Windows — через WSL / Git Bash)

---

## Proven Metrics

Из продакшна Aeza (`/opt/tg-export`, 7 дней непрерывной работы):

- **Download:** 48 файлов (P1: 27, P2: 7, P3: 16)
- **Transcribe:** 15 файлов, 7.18 ч аудио, **$0.72** затрат на Grok STT
- **Uptime:** 3 auto-restart (все корректные), 0 false positives

---

## Canon References

- `kanon/simplicity-first-principle.md` — почему чат + 5 bash лучше UI
- `kanon/alexey-11-principles.md` — Skills Over Agents (#4), Minimal Integration Code (#2)
- `navyki/heartbeat-telegram-pattern.md` — self-healing watchdog (первая интеграция)
- `navyki/claude-bot-parser-control.md` — полный гайд с архитектурой и диалогами
- `troubleshoot/telegram-parser-recreation.md` — recreation guide парсера с нуля

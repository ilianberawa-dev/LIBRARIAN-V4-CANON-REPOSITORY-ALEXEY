# `.claude/` — Claude Code project settings

## Что внутри

- **`settings.json`** — auto-allow list для типовых команд деплоя и аудита PA Assistant. Применяется ко всем агентам, которые клонируют репо и запускают `claude` в этой директории.

## Зачем

Без allowlist агент спрашивает разрешение на каждую команду (`ls`, `git status`, `systemctl restart personal-assistant-*` и т.д.). Илья в 99% случаев нажимает "yes". Это shoot oneself in the foot — лишняя нагрузка на оператора без выигрыша в безопасности.

Allowlist покрывает ~95% типовых операций деплоя/аудита. **Деструктивные** (`rm -rf`, `git push --force`, `git reset --hard`, `DROP TABLE`, `systemctl mask`, и т.д.) явно в `deny` — они **продолжают** требовать ручного подтверждения. Таким образом:

- **95% операций** — авто-разрешены
- **5% опасных** — спрашивают
- **Канон #11 (Privilege Isolation)** не нарушен

## Что разрешено (категории)

1. Read-only filesystem: `ls`, `cat`, `grep`, `find`, `stat`, `wc`, `du`, `df`
2. Git: `status`/`log`/`diff`/`show`/`add`/`commit`/`pull`/`push origin claude/*`
3. Systemd: `status`/`is-active`/`restart personal-assistant-*`/`daemon-reload`
4. Journalctl: read-only
5. Node/npm: `install`/`ls`/`view`/`run`/`test`/`audit`
6. SQLite: `SELECT`/`PRAGMA`/`.schema`/`.tables` (read-only)
7. Install/chmod/chown/cp/mv: для деплоя
8. `sudo -u personal-assistant`: full command set
9. Network read: `curl`/`ping`/`dig`/`ss`/`netstat`
10. Read/Glob/Grep/Edit/Write tools — везде

## Что запрещено (категории)

1. `rm -rf /` `rm -rf ~` (но `rm -rf <local-path>` спросит)
2. `git push --force` / `--force-with-lease` / `git reset --hard` / `git clean -fd`
3. Удаление веток локально (`-D`) и удалённо
4. `dd` / `mkfs` / `fdisk` / `shred`
5. Pipe to shell: `curl ... | sh`
6. `useradd`/`userdel`/`passwd`/`visudo`
7. `systemctl mask` / `disable personal-assistant-*` / `poweroff` / `reboot`
8. SQLite `DROP` / `DELETE FROM` / `TRUNCATE`
9. Firewall changes: `iptables`/`ufw`/`firewall-cmd`
10. `crontab -r` (удаление всех cron)
11. `chmod 777 /` / `chown root:`

## Как работают паттерны

Формат: `Bash(<command>:<args>)` где `*` — wildcard для аргументов.

- `Bash(ls:*)` — разрешает `ls` с любыми аргументами
- `Bash(systemctl restart personal-assistant-*)` — только наши сервисы
- `Bash(git push origin claude/*)` — только в claude-ветки

## Как обновлять

1. Если агент запросил разрешение на безопасную операцию, которая не покрыта allowlist — добавить паттерн в `permissions.allow`.
2. Если новая опасная команда появилась — добавить в `permissions.deny`.
3. Коммит в `claude/setup-library-access-FrRfh` (канонический бранч).
4. Все будущие агенты, клонирующие канон, получают апдейт автоматически.

## Ссылки

- Canon #11 (Privilege Isolation): `kanon/alexey-11-principles.md`
- Canon #6 (Single Secret Vault): не пересекается — секреты в `/etc/credstore.encrypted/`, не в settings.json
- Claude Code docs (settings): https://docs.claude.com/claude-code/settings

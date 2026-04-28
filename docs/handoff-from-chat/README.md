# Handoff from chat

Сюда складываются новые материалы от Алексея из чата (хендоф между сессиями).

## Быстрый просмотр свежих материалов

В новой сессии достаточно одной команды:

```bash
sync
```

Алиас разворачивается в:

```bash
git pull && ls docs/handoff-from-chat/
```

## Установка алиаса

Добавьте в `~/.bashrc` (или `~/.zshrc`):

```bash
alias sync='git pull && ls docs/handoff-from-chat/'
```

Перезагрузите шелл: `source ~/.bashrc`.

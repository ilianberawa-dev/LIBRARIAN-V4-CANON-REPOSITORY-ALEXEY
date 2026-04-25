# Registration URLs — All Platforms

**Что это:** плоский список URL для регистрации всех сервисов системы. Открыл — прошёлся по ссылкам — получил ключи — сохранил их через шаблон в `secrets-vault-template.md`.

**Порядок заполнения:** сначала Tier 1 (LLM) + Tier 4 (Telegram) — блокирует Day 3. Остальное по фазам.

---

## TIER 1 — LLM PROVIDERS (Day 3 triangulation) — обязательно 7

### 1. Anthropic Claude (уже есть, ротация)
```
URL:      https://console.anthropic.com/settings/keys
Account:  email + credit card
Prefix:   sk-ant-api03-
Free:     нет (pay-as-go)
Model:    claude-opus-4-6 / claude-sonnet-4-6 / claude-haiku-4-5
Notes:    текущий ключ временный → обязательная ротация перед продом
```

### 2. OpenAI GPT ($5 trial)
```
URL:      https://platform.openai.com/api-keys
Account:  email + card (trial credits выдают на новую регистрацию)
Prefix:   sk-proj-  (новые project-scoped)  или  sk-  (legacy)
Free:     $5 trial credits при первом pay-as-go
Model:    gpt-5 / gpt-5-mini / gpt-4o
```

### 3. Google Gemini (самый щедрый free tier)
```
URL:      https://aistudio.google.com/apikey
Account:  Google-аккаунт (без карты)
Prefix:   AIzaSy
Free:     FREE tier, ~60 requests/min, 1M tokens/day на Pro
Model:    gemini-2.5-pro / gemini-2.5-flash
Notes:    быстрее всего регается (2 мин), non-Anthropic семейство
```

### 4. DeepSeek R1 ($5 free credits)
```
URL:      https://platform.deepseek.com/api_keys
Account:  email + card (intl карта работает)
Prefix:   sk-   (OpenAI-compatible формат)
Free:     $5 credits
Model:    deepseek-chat / deepseek-reasoner (R1)
Notes:    китайское семейство моделей → реально independent opinion
```

### 5. Groq (free, fast inference)
```
URL:      https://console.groq.com/keys
Account:  email
Prefix:   gsk_
Free:     FREE tier, rate-limited но щедро
Model:    llama-3.3-70b-versatile / mixtral-8x7b / kimi
Notes:    inference speed x10 vs облако — полезно для быстрых проверок
```

### 6. xAI Grok ($150/мес developer)
```
URL:      https://console.x.ai
Account:  X / Twitter аккаунт
Prefix:   xai-
Free:     $150/month developer credits (первые месяцы для новых)
Model:    grok-4 / grok-4-fast
```

### 7. Qwen / Alibaba Model Studio (intl, free tier)
```
URL:      https://modelstudio.console.alibabacloud.com/?tab=playground#/api-key
Account:  Alibaba Cloud international (без CN-платежей)
Prefix:   sk-   (DashScope формат)
Free:     free tier на Qwen-Turbo / small models
Model:    qwen-max / qwen-plus / qwen-turbo
Notes:    альтернативный URL для CN-аккаунта: dashscope.console.aliyun.com
```

---

## TIER 3 — LiteLLM admin (генерируешь сам)

```
Команда: openssl rand -hex 32
Или:     head -c 32 /dev/urandom | base64
Prefix:  sk-   (условное)
Use:     защита /admin API LiteLLM, сам себе secret
```

---

## TIER 4 — TELEGRAM (admin alerts + Phase B user commands)

### Realty Portal Bot
```
Создание:   Telegram → найти @BotFather → /newbot
Steps:
  1. /newbot
  2. Name (human-readable): "Bali Realty Evaluator"
  3. Username: realty_bali_bot   (должен заканчиваться на _bot, быть свободным)
  4. BotFather отдаёт TOKEN формата:   7891234567:AAEx...
Prefix:     <digits>:<letters-digits>
Use:        admin alerts, позже — user commands
```

### Admin chat_id (куда слать alerts)
```
Как получить:
  1. Открой созданного бота в Telegram → нажми Start
  2. Напиши боту что-нибудь (любой текст)
  3. В браузере: https://api.telegram.org/bot<TOKEN>/getUpdates
  4. В JSON найди "from":{"id":123456789}  ← это chat_id
Prefix:     9-10 цифр
```

---

## TIER 7 — MONITORING (Phase B, опционально)

### Sentry (error tracking)
```
URL:      https://sentry.io/settings/account/api/auth-tokens/
Account:  email
Prefix:   https://...@...ingest.sentry.io/...  (full DSN)
Free:     5K events/month, 1 team
```

---

## TIER 8 — MARKET DATA (Phase 2)

### AirDNA (STR yields, cap rates)
```
URL:      https://www.airdna.co/api
Free:     нет, платный
Notes:    Phase 2 Income approach
```

### Booking partner / Colliers / Knight Frank
```
Обычно download-доступ через email-контакт, без публичного API.
Запрос через корпоративные каналы.
```

---

## TIER 9 — PAYMENTS (Phase 3, SaaS)

### Stripe (международные подписки)
```
URL:      https://dashboard.stripe.com/apikeys
Account:  business registration + KYC
Prefix:   sk_live_   (prod)  /  sk_test_   (test)
Free:     free account, %-за транзакцию
```

### Midtrans (индонезийские платежи)
```
URL:      https://dashboard.midtrans.com
Account:  PT Royal Palace Address business registration
Prefix:   SB-Mid-server-   (sandbox)  /  Mid-server-   (prod)
```

---

## TIER 10 — DEV / CI

### GitHub PAT (если CI/CD через GitHub Actions)
```
URL:      https://github.com/settings/personal-access-tokens/new
Account:  твой GitHub
Prefix:   github_pat_   (fine-grained, новые)  /  ghp_   (classic, deprecated)
Free:     yes
```

**ВАЖНО: revoke старый скомпрометированный PAT:**
```
ghp_REDACTED_COMPROMISED
```
→ https://github.com/settings/tokens → найти этот токен → Revoke

---

## Что делать после регистрации каждого ключа

1. **НЕ сохраняй ключ в браузере / password-менеджере облачном / заметках**
2. Держи вкладку провайдера открытой
3. Открой `docs/secrets-vault-template.md` → добавь в свой локальный блокнот → вставляй ключи один за другим
4. Когда все 7 (+ Telegram + master_key) заполнены — заливай через SSH на Aeza (протокол в template'е)
5. Закрой вкладки провайдеров (ключ там больше не показывается, только отзывать можно)
6. Локальный блокнот — удалить

# Agent database as monetization asset — strategic research

**Source:** ChatGPT analysis 2026-04-20 (after Ilia's broker insight про пул объектов агента)
**Status:** research / not committed to canon
**Location:** `.gitignore`'нутая папка (не в публичном repo)
**Decision pending:** await data stream from Lamudi + consent with Alexey on canon impact

## Ключевое понимание

Агенты — не просто «enrichment layer», а **business foundation** для 5 монетизационных pathways:

1. **SaaS subscription для агентов** ($50-200/мес) — validation своих цен через наш Evaluator
2. **Lead-gen commission** (5-15% от их sale commission) — connect buyer → agent's listing
3. **Co-marketing / exclusive indexing** — Tier-1 агенты free subscription за early access к их новинкам
4. **Market intelligence reports** ($200-500 quarterly per area)
5. **Enterprise B2B data API** ($500-2000/мес для REIT/funds)

Все 5 pathways **требуют качественной agent-данных**. Если собираем правильно с Day 1 → через 6 месяцев готовый business foundation.

## Предложенная схема агент-данных

### Полный набор полей (будущая target state)

```
Identity:
  agent_id TEXT  -- SHA1(name_norm + phone_norm)[:12]
  name, agency_name
  phones[], emails[] (phase 2), whatsapp_numbers[]
  telegram_handle (phase 2)

Geographic focus:
  primary_areas[] -- top 3 по count
  all_areas[]
  area_specialization_score JSONB -- {Canggu: 0.65, Berawa: 0.20, ...}

Activity metrics:
  total_listings_seen, active_listings_count
  avg_listing_price_idr, price_range_idr JSONB
  first_seen_at, last_seen_at

Quality signals (weekly aggregate):
  avg_z_score -- systematic over/under pricing
  price_drop_frequency
  avg_days_on_market
  behavior_tags[] -- ['overpricing_tendency', 'area_specialist', 'rapid_drops']

External presence (Phase 2):
  external_profiles JSONB -- {fazwaz_url, 99co_url, instagram, website}

CRM (for monetization):
  contact_status -- 'not_contacted'|'contacted'|'interested'|'customer'|'partner'|'rejected'
  first_contact_date, last_contact_date
  contact_notes TEXT
  tier TEXT -- 'tier_1_priority'|'tier_2_standard'|'tier_3_low'|'excluded'
```

### Safe implementation via JSONB (канон 4 таблиц preserved)

Вместо 5-й таблицы `agents`:

```sql
-- sources._lookup_agents JSONB хранит массив agent records:
{
  "agents": [
    {
      "agent_id": "a1b2c3d4e5f6",
      "name": "Budi Santoso",
      "agency_name": "Bali Prime Realty",
      "phones": ["+628123456789"],
      "primary_areas": ["Berawa", "Canggu"],
      "total_listings_seen": 47,
      "tier": "tier_1_priority",
      "contact_status": "not_contacted",
      ...all other fields as nested JSON...
    },
    ...
  ]
}
```

**Preserved:**
- Canon 4-table architecture (ADR-001 respected)
- Full business logic (все поля помещаются в JSONB)
- Query capability: `WHERE config->'agents' @> '[{"tier":"tier_1_priority"}]'`
- Index: `CREATE INDEX ON sources USING GIN ((config->'agents'))`

**Trade-off vs separate table:** при 50K+ agents query performance может деградировать. **Migrate на table = Phase 2 evidence-based**, не preemptive.

## Tiering logic (DRAFT, to validate with evidence)

| Tier | Criteria |
|---|---|
| **Tier 1 priority** | active_listings ≥ 10 + primary_area IN targeted 10 (Canggu/Berawa/Seminyak/Pererenan/Umalas/Sanur/Uluwatu/Jimbaran/Ubud/Tabanan) + no scam signals + normalized agency name |
| **Tier 2 standard** | active_listings 5-9 + area in 27-gazetteer + clean behavior |
| **Tier 3 low** | active 1-4 + behavior concerns |
| **Excluded** | scam signals / stale >180 days / impossible contact |

## Batch jobs (Phase 2 implementation, Phase A design)

### AGT-METRICS-REFRESH (weekly cron)
- Recompute active_listings_count, avg_price, area_specialization_score per agent_id
- SQL + rule-based, no LLM

### AGT-BEHAVIOR-ANALYZER (weekly cron)
- Calculate avg_z_score per agent (vs market medians)
- Detect price_drop_frequency from raw_listings.price_history
- Update behavior_tags

### AGT-TIERING (weekly cron)
- Apply tiering rules
- Log promotion/demotion events

## Privacy framework (ADR-027 draft)

**Status:** draft, to commit when agent-data flow live

**Principles:**
1. ✅ Collect only from public listings (phone/name/agency that agent themselves published)
2. ❌ Don't parse private data (personal phones, private accounts, social media)
3. ✅ Store for business purposes (evaluation + potential partnership)
4. ✅ Honor right-to-deletion — если агент просит удалить, делаем
5. ❌ Never sell database to third parties
6. ❌ Never use for spam (only targeted outreach with value prop)
7. ❌ Never publicly attribute negative signals ("agent X overprices")
8. ⚠ UU ITE compliance (Indonesian data privacy law) — проверить актуальные требования

## Proposed ADRs (DRAFTS — NOT committed)

### ADR-027: Agent database privacy posture
- Public-sources-only collection
- Business purpose scope
- Deletion rights honored
- No third-party sale
- No negative public attribution

### ADR-028: Agent monetization as product pillar
- Agent data NOT ephemeral enrichment
- 5 monetization pathways (SaaS/lead-gen/co-marketing/reports/B2B API)
- 6-month target: 500+ tier-1 agents catalogued
- Tier 1 priority = premium value

### ADR-029: Agent data storage — JSONB pattern for MVP, table migration Phase 2
- MVP: `sources._lookup_agents JSONB` (canon-preserving)
- Migrate to separate `agents` table IF performance evidence warrants AND Alexey approves
- Preserve canon 4-table until evidence justifies 5th

## Execution plan (safe, staged)

### Phase A current state (today)
- Baseline v1 frozen (21 records CLS-002/003 results saved)
- 81 records in `raw_listings` (rumah + villa + tanah + apartemen + ruko)
- Multi-board probe complete — Lamudi + Fazwaz viable, 99co+dotproperty CF-walled

### Phase A.5 (after baseline v2 canon-compliance changes closed)
1. Add Lamudi scraper (canonically identical to Rumah123 — just different list path)
2. Shadow parallel scraping — both sources write to `raw_listings` with different `source_name`
3. Collect evidence — what % of listings have agent phone extractable from raw_text?

### Phase B (Normalizer + Agent extraction)
4. Normalizer extracts phone/name/agency from raw_text (all sources)
5. Populate `sources._lookup_agents` JSONB (canon-safe)
6. Fuzzy dedup across sources (phone hash matching)
7. First wave of agent clustering visible

### Phase B+ (post-MVP, pre-monetization)
8. Weekly cron jobs (AGT-METRICS-REFRESH, AGT-BEHAVIOR, AGT-TIERING)
9. Tier-1 outreach pipeline (manual at first)
10. Get Alexey sign-off on either: (a) stay JSONB forever, or (b) migrate to table

### Phase 2 (monetization)
11. Retool/Supabase Studio UI for agent CRM
12. Google Sheets export for outreach
13. SaaS subscription infrastructure
14. First paying agent customers

## Why not implement the ChatGPT proposal NOW

1. **Baseline freeze:** canon-compliance A/B (ADR-021/022) обязателен перед любыми ещё изменениями
2. **No data stream:** Rumah123 detail-pages CF-blocked, Lamudi не подключён — skill для agent extraction на пустом входе = no-op
3. **Canon violation:** 5-я таблица требует Alexey sign-off, у нас нет активной подписки пока
4. **Scope creep:** 14-й skill + 3 cron jobs + UI planning = 3 weeks работы до MVP close, у нас Day 6+ уже
5. **Safe alternative exists:** JSONB preserving канон даёт ту же функциональность для MVP

## Decision log for this research doc

- **2026-04-20** — ChatGPT proposed monetization pivot + 5-table + 14 skills + 3 cron jobs
- **2026-04-20** — Ilia reviewed, decided «идеи сохрани, исполнение — безопасный стек»
- **2026-04-20** — Claude Code saved strategy here (research only), skipped premature migration, kept baseline frozen
- **TBD** — After Alexey subscription active: review with him, decide JSONB vs table
- **TBD** — After Phase A.5 Lamudi data stream: evaluate extracted agent volume + quality
- **TBD** — Phase B: implement JSONB-based agent extraction skill

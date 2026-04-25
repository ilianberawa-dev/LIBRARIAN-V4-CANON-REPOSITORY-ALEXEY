# Stage 2.5 — Cascade Router (RESERVE — DO NOT DEPLOY)

**Status:** Standby. Files prepared, NOT activated on production.
**Created:** 2026-04-25
**Author:** Foreman per architect ACK on cascade escalation.

---

## Purpose

Triage cost reduction via Haiku 4.5 first → Sonnet 4.6 fallback on low
confidence or JSON parse failure. Targets `triage.mjs` only —
drafts/briefs/voice remain Sonnet (quality-critical).

Expected savings: ~$4-6/month = +30% runway on $20 budget.

---

## DO NOT DEPLOY UNTIL ALL TRIGGER CONDITIONS MET

1. Stage 2 (`triage.mjs` Sonnet-only) deployed and stable for ≥7 days.
2. `budget_log` confirms Sonnet-only triage trending toward ≥$3/month
   (= ≥$20/month total when combined with Stage 3 drafts + briefs + voice).
3. ≥100 real messages classified with manual accuracy review by owner.
4. Architect explicit approval to activate cascade.

If any condition fails → stay on Sonnet-only.

---

## Activation Procedure (when triggered)

1. Copy files to server:
   ```
   sudo install -o personal-assistant -g personal-assistant -m 0640 \
     /tmp/repo/metody/personal-ai-assistant/implementation/stage-2.5-cascade-reserve/router-cascade.mjs \
     /opt/personal-assistant/router-cascade.mjs

   sudo install -o personal-assistant -g personal-assistant -m 0640 \
     /tmp/repo/metody/personal-ai-assistant/implementation/stage-2.5-cascade-reserve/skills/triage-haiku.md \
     /opt/personal-assistant/skills/triage-haiku.md
   ```

2. Patch `triage.mjs` to import the cascade router:
   - Replace `import` block addition: `import { classifyWithCascade } from './router-cascade.mjs';`
   - In `processOne()`, replace the call:
     ```
     // BEFORE:
     const result = await classifyWithSonnet(msg, contact);
     // AFTER (cascade-enabled):
     const result = process.env.CASCADE_ENABLED === '1'
       ? await classifyWithCascade(buildUserText(msg, contact))
       : await classifyWithSonnet(msg, contact);
     ```
   - `buildUserText()` is whatever helper assembles the JSON sent to the model
     (currently inlined inside `classifyWithSonnet`). Extract as small helper.

3. Append to `/opt/personal-assistant/.env`:
   ```
   CASCADE_ENABLED=1
   CASCADE_FALLBACK_THRESHOLD=0.7
   HAIKU_SKILL_PATH=/opt/personal-assistant/skills/triage-haiku.md
   ```

4. Restart and observe:
   ```
   sudo systemctl restart personal-assistant-triage
   sudo journalctl -u personal-assistant-triage -f
   ```

5. After first 100 messages: owner does manual accuracy review.
   - If ≥80% match owner judgment → keep cascade ON.
   - If <80% → instant rollback (see below).

---

## Rollback (instant, no code changes)

Set `CASCADE_ENABLED=0` in `.env` and restart:

```
sudo sed -i 's/^CASCADE_ENABLED=1$/CASCADE_ENABLED=0/' /opt/personal-assistant/.env
sudo systemctl restart personal-assistant-triage
```

Triage falls back to Sonnet-only. Zero downtime, zero data loss.

---

## Files

- `router-cascade.mjs` — cascade router module (Haiku 4.5 → Sonnet 4.6 fallback,
  parses confidence, tracks cost per route, emits `operation` field for
  `budget_log` differentiation).
- `skills/triage-haiku.md` — Haiku-optimized skill prompt: same JSON contract
  as Sonnet skill, slightly more directive examples to help smaller model
  hit format reliably.

---

## Acceptance Criteria (when activated)

- **Cost per classification:** <$0.0005 average across 100 messages.
- **Accuracy:** ≥80% on 100-msg owner manual review.
- **Latency:** ≤current Sonnet-only latency (Haiku is faster; fallback rare).
- **Budget log:** distinguishes `operation = 'triage_haiku'` vs
  `operation = 'triage_sonnet_fallback'`.
- **No regression:** `journalctl` no new ERROR/CRITICAL.

---

## Canon compliance

- **#0 Simplicity First:** rules-first stays, cascade only after rules pass.
- **#3 Simple Nodes:** router is one file, one purpose.
- **#4 Skills Over Agents:** one skill per model, both deterministic.
- **#5 Minimal Clear Commands:** strict JSON output, fail-loud on parse
  failure (auto-fallback to Sonnet, not silent corruption).
- **#6 Single Vault:** flag in `.env`, no extra config files.
- **#11 Privilege Isolation:** router has no extra capabilities, just LLM
  client.

No LiteLLM. No external proxy. Native Anthropic SDK.

---

## Rationale (for future reviewers)

The original audit (2026-04-24) deferred cascade to Phase 2 because
complexity > savings at unconstrained budget. Owner constraint changed
(starting balance $20, equals Phase 2 trigger from day 1). Foreman
escalated, architect ACK'd. Files staged but not activated to preserve
Stage 2 deploy momentum and gather real-volume data first.

Do not deploy reactively. Deploy when measured.

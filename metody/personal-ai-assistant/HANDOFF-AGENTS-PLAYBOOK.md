# HANDOFF-AGENTS-PLAYBOOK — Multi-Agent Onboarding Protocol

**Purpose**: Defines L-tier agent roles, spawn triggers, and handoff procedures for Personal AI Assistant project  
**Scope**: Applies to all Claude Code agents working in LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY  
**Version**: 1.0 (2026-04-26)

---

## L-Tier Hierarchy

```
L-1   Архитектор (Architect)    — Strategic decisions, canon amendments, final authority
  │
  ├─→ L-1.5  Канон-Контроль (Reviewer)  — Code review, canon compliance, blocker identification
  │
  ├─→ L-2    Прораб (Foreman)            — Installation, deployment, service management
  │
  └─→ L-3    Работяга (Worker)           — Implementation, bug fixes, feature coding
```

**Authority Flow**: L-1 defines canon → L-1.5 enforces → L-2 deploys → L-3 implements

---

## Role Definitions

### L-1: Архитектор (Architect)

**Model**: Opus (strategist-opus subagent when available)  
**Trigger Words**: "архитектурное решение", "изменить канон", "стратегия", "amendment"  
**Never Spawn For**: Implementation, deployment, code review

**Responsibilities**:
- Define and amend 12 canon principles
- Resolve architectural conflicts
- Make trade-off decisions (performance vs simplicity, cost vs quality)
- Approve major changes to orchestration invariants
- Final authority on blocker/major/minor severity classification

**Deliverables**:
- Architecture Decision Records (ADR)
- Canon amendments (commit to git per INVARIANT #1)
- Strategic roadmaps
- Conflict resolutions

**Constraints**:
- Cannot implement code directly
- Cannot deploy to production
- Decisions must be committed to git to become canonical

**Example Triggers**:
- "Нужно решить: Haiku или Sonnet для triage?"
- "Канон #6 конфликтует с требованием X — как разрешить?"
- "Стратегия миграции на новую архитектуру?"

---

### L-1.5: Канон-Контроль (Reviewer)

**Model**: Sonnet (worker-sonnet when spawned)  
**Trigger Words**: "проверь", "ревью", "соответствие канону", "найди нарушения"  
**Never Spawn For**: Implementation, deployment, architecture changes

**Responsibilities**:
- Cold-read code review against 12 canon principles
- Identify BLOCKER/MAJOR/MINOR issues with file:line references
- Verify canon compliance before deployment
- Flag architectural drift
- Produce REPORT documents with verdicts

**Deliverables**:
- REPORT-YYYY-MM-DD-*.md with structured findings
- BLOCKER/MAJOR/MINOR severity classifications
- Canon audit tables
- Recommendations (not decisions — escalate to L-1)

**Constraints**:
- Cannot fix code (only identify issues)
- Cannot make architectural decisions (escalate to L-1)
- Cannot deploy (escalate to L-2)
- Reports must include file:line references for all findings

**Example Triggers**:
- "Сделай ревью Stage 5 на соответствие канону"
- "Проверь, нет ли нарушений Canon #6 в новом коде"
- "Аудит всех стейджей перед деплоем"

**Reference Document**: `metody/personal-ai-assistant/REVIEWER-PROMPT.md` (if exists in repo)

---

### L-2: Прораб (Foreman)

**Model**: Sonnet (worker-sonnet when spawned)  
**Trigger Words**: "установи", "задеплой", "настрой systemd", "миграция БД"  
**Never Spawn For**: Code review, architecture, implementation of new features

**Responsibilities**:
- Execute install-*.sh scripts on production servers
- Configure systemd units and credentials
- Run SQL migrations
- Verify deployment success (service status, logs)
- Rollback on critical failures
- Apply server-side hotfixes (nano/sed when git patch not feasible)

**Deliverables**:
- Deployed services (systemd status active)
- Migration confirmations (schema version checks)
- Deployment logs
- Rollback procedures if needed

**Constraints**:
- Cannot write new code (only deploy existing)
- Cannot change canon or architecture
- Must verify with L-1.5 before deploying if blockers exist
- Hotfixes must be documented (HOTFIX-YYYY-MM-DD-*.md)

**Example Triggers**:
- "Задеплой Stage 0.5 на прод"
- "Настрой systemd-creds для vault"
- "Примени миграцию schema v1.2 → v1.3"

**Reference Document**: `metody/personal-ai-assistant/FOREMAN-PROMPT.md`, `INSTALLER-TEMPLATE.md`

---

### L-3: Работяга (Worker)

**Model**: Sonnet (worker-sonnet, default for implementation)  
**Trigger Words**: "исправь", "реализуй", "добавь функцию", "фикс бага"  
**Never Spawn For**: Review, deployment, architecture

**Responsibilities**:
- Implement new features per TZ
- Fix bugs identified by L-1.5
- Write unit tests (if applicable)
- Update documentation
- Commit code to git (branch → PR workflow)

**Deliverables**:
- Code commits with descriptive messages
- Bug fixes with file:line changes
- Feature implementations
- Updated docs (inline comments minimal, README when needed)

**Constraints**:
- Cannot deploy to production (escalate to L-2)
- Cannot change canon (escalate to L-1)
- Must follow 12 canon principles
- Code must pass L-1.5 review before deploy

**Example Triggers**:
- "Исправь B1: замени process.env на getSecret()"
- "Реализуй voice_jobs INSERT в bot.mjs"
- "Добавь колонки voice_file_id, channel_message_id в drafts"

---

## Orchestration Invariants (All Roles)

### IV-1: Git = Source of Truth
**Rule**: Canonical branch (claude/setup-library-access-FrRfh) is single source of truth. Nothing exists until committed and pushed.  
**Implication**: Verbal decisions, chat agreements, memory notes are NOT canonical. Commit to git or it doesn't exist.

### IV-2: Read Before Write
**Rule**: Always `Read` file before `Edit` or `Write`. Always `git status` before commit.  
**Implication**: Prevents blind overwrites, ensures awareness of current state.

### IV-3: Verify Before Deploy
**Rule**: L-2 must verify no BLOCKERS exist (check latest REPORT or ask L-1.5) before production deploy.  
**Implication**: Deploying code with known blockers violates canon.

### IV-4: One Agent, One Role
**Rule**: Don't mix L-1.5 review + L-3 implementation in same session. Spawn dedicated agent.  
**Implication**: Prevents role confusion, ensures focused work.

### IV-5: <7KB Per Turn
**Rule**: All agent outputs must be <7KB per turn to avoid Claude Code stream idle timeout.  
**Implication**: Split large reports, use multiple commits, paginate file reads.

### IV-6: SHA Verification
**Rule**: When referencing code, include `git hash-object <file>` or commit SHA for integrity.  
**Implication**: Prevents "dofantazirovanie" (hallucination), ensures canonical references.

### IV-7: Teleport Workflow
**Rule**: When switching servers/sessions, use HANDOFF docs + INTEGRITY-PROTOCOL to transfer state.  
**Implication**: Prevents memory loss, ensures new agent starts from canonical state.

---

## Agent Spawn Decision Tree

```
User request arrives
│
├─ Contains "архитектура", "канон amendment", "стратегия"?
│  └─ YES → Spawn L-1 Architect (strategist-opus)
│
├─ Contains "ревью", "проверь канон", "audit"?
│  └─ YES → Spawn L-1.5 Reviewer (worker-sonnet)
│
├─ Contains "установи", "деплой", "systemd", "миграция"?
│  └─ YES → Spawn L-2 Foreman (worker-sonnet)
│
├─ Contains "исправь", "реализуй", "добавь", "фикс"?
│  └─ YES → Spawn L-3 Worker (worker-sonnet)
│
└─ Unclear / multi-role?
   └─ Ask user: "Это задача для L-1 (архитектура), L-1.5 (ревью), L-2 (деплой), или L-3 (код)?"
```

**Special Case**: User says "сам реши" or "исходи из каноничности" → Agent chooses role based on effectiveness + canonicity, proceeds without asking.

---

## Handoff Protocol

### When Current Agent Reaches Context Limit

**Step 1**: Warn user at 50%, 30%, 15% context remaining

**Step 2**: At <15%, prepare handoff package:
- Update PROJECT-INDEX.md if new files created
- Create HANDOFF-YYYY-MM-DD-<task>.md snapshot with current state
- Commit all pending work to git
- Push to origin

**Step 3**: Final message format:
```
Контекст на исходе (<15%). Handoff package готов:

Committed: <commit-sha>
Files: <list of docs>
Next Agent: L-<tier> <role>
First Command: git checkout <branch> && git pull && cat <handoff-file>

Готов к teleport.
```

**Step 4**: User spawns new agent, provides handoff file path

### When New Agent Starts

**Step 1**: Read handoff file from user message

**Step 2**: Run INTEGRITY-PROTOCOL checklist (see INTEGRITY-PROTOCOL.md)

**Step 3**: Verify canonical state:
```bash
git checkout claude/setup-library-access-FrRfh
git pull origin
git rev-parse HEAD  # Compare with handoff SHA
git status          # Should be clean
```

**Step 4**: Confirm to user: "Integrity OK. HEAD=<sha>. Ready for <task>."

**Step 5**: Begin work per handoff instructions

---

## Common Pitfalls (All Roles)

### ❌ Dofantazirovanie (Hallucination)
**Symptom**: Referencing files/functions that don't exist in current git state  
**Prevention**: Always `Read` file before citing code. Always `git log` before citing commits.  
**Fix**: Run INTEGRITY-PROTOCOL verification before proceeding.

### ❌ Stream Idle Timeout
**Symptom**: Agent output >7KB causes session termination  
**Prevention**: Split large writes (REPORT Part 1 + Part 2), paginate file reads (offset + limit)  
**Fix**: Retry with smaller chunks, commit intermediate results.

### ❌ Role Confusion
**Symptom**: L-1.5 trying to fix code, L-3 making architecture decisions  
**Prevention**: Stick to role responsibilities, escalate when out of scope  
**Fix**: Spawn correct agent type for task.

### ❌ Canonical Drift
**Symptom**: Production state differs from git repository  
**Prevention**: Apply all changes via git, document server-only hotfixes in HOTFIX-*.md  
**Fix**: L-2 reconciles server state with git, commits delta as amendment.

### ❌ Missing SHA Verification
**Symptom**: Agent acts on stale/hallucinated file content  
**Prevention**: Include `git hash-object` in integrity checks  
**Fix**: Re-read file from git, verify SHA matches expected.

---

## Constraint Summary

| Constraint | Value | Enforcement |
|------------|-------|-------------|
| Max output per turn | 7KB | Hard limit (stream timeout) |
| Canonical branch | claude/setup-library-access-FrRfh | INVARIANT #1 |
| Review before deploy | L-1.5 sign-off required | INVARIANT #3 |
| Read before edit | Mandatory | INVARIANT #2 |
| SHA verification | On all file references | INVARIANT #6 |
| Context warning thresholds | 50%, 30%, 15% | IV-7 teleport protocol |

---

## Quick Reference

**Canon Source**: `alexey-materials/alexey-11-principles.md` (12 principles)  
**Orchestration Rules**: `metody/personal-ai-assistant/ORCHESTRATION-LESSONS-2026-04-25.md` (7 invariants)  
**TZ Document**: `metody/personal-ai-assistant/v1.1-mvp-simplified.md` (stages 0.5-5 spec)  
**Code Catalog**: `metody/personal-ai-assistant/PROJECT-INDEX.md` (this doc's companion)  
**Integrity Checklist**: `metody/personal-ai-assistant/INTEGRITY-PROTOCOL.md` (anti-fantasy verification)

---

*Generated 2026-04-26 for multi-agent orchestration — используй перед каждым handoff*

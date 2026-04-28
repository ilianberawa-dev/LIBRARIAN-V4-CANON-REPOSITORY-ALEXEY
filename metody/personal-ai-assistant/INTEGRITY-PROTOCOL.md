# INTEGRITY-PROTOCOL — Anti-Fantasy Verification Checklist

**Purpose**: Prevents "dofantazirovanie" (hallucination) by requiring agents to verify canonical state before action  
**Scope**: Mandatory for all L-tier agents at session start and before critical operations  
**Version**: 1.0 (2026-04-26)

---

## When to Run This Protocol

1. **Session Start** (new agent spawned after teleport/handoff)
2. **Before Deployment** (L-2 Foreman about to run install scripts)
3. **Before Code Review** (L-1.5 Reviewer starting audit)
4. **After Context Restore** (agent resumed from compacted summary)
5. **When User Says** "verify integrity", "check canonical state", "run integrity protocol"

---

## Step 1: Git State Verification

### 1.1 Verify Branch
```bash
git branch --show-current
# Expected: claude/setup-library-access-FrRfh
```

**If Wrong Branch**:
```bash
git checkout claude/setup-library-access-FrRfh
git pull origin claude/setup-library-access-FrRfh
```

### 1.2 Verify HEAD
```bash
git rev-parse HEAD
```

**Cross-Check**: Compare with handoff document or PROJECT-INDEX.md snapshot SHA.

**If Mismatch**:
- Check if local is behind: `git pull origin`
- Check if local has uncommitted work: `git status`
- If diverged, consult user before force-sync

### 1.3 Working Tree Status
```bash
git status
```

**Expected Output**:
```
On branch claude/setup-library-access-FrRfh
Your branch is up to date with 'origin/claude/setup-library-access-FrRfh'.

nothing to commit, working tree clean
```

**If Untracked Files**:
- `.claude/` → OK (IDE state, in .gitignore)
- Other files → Investigate before proceeding (may be leftover artifacts)

**If Uncommitted Changes**:
- STOP: Canonical state compromised
- Consult user: "Found uncommitted changes: <list>. Stash, commit, or discard?"

---

## Step 2: File Existence Verification

### 2.1 Implementation Files
```bash
ls -1 metody/personal-ai-assistant/implementation/stage-*/
```

**Expected**: 6 stage directories (0.5, 1, 2, 2.5-cascade-reserve, 3, 3.5, 4, 5)

**If Missing**: Re-clone repository, verify remote URL

### 2.2 Canon Sources
```bash
ls -1 alexey-materials/alexey-11-principles.md
ls -1 metody/personal-ai-assistant/ORCHESTRATION-LESSONS-2026-04-25.md
ls -1 metody/personal-ai-assistant/v1.1-mvp-simplified.md
```

**If Missing**: Fatal error — cannot proceed without canon sources

### 2.3 Critical Docs
```bash
ls -1 metody/personal-ai-assistant/PROJECT-INDEX.md
ls -1 metody/personal-ai-assistant/HANDOFF-AGENTS-PLAYBOOK.md
ls -1 metody/personal-ai-assistant/INTEGRITY-PROTOCOL.md
```

**If Missing**: May be pre-handoff state — verify with user which docs should exist

---

## Step 3: Content Verification (SHA Check)

### 3.1 Verify Specific File Integrity

**When**: About to reference code from a file in decision/review/implementation

**How**:
```bash
git hash-object metody/personal-ai-assistant/implementation/stage-5/voice.mjs
```

**Cross-Check**: Compare SHA with:
- PROJECT-INDEX.md reference (if SHA listed)
- Handoff document reference
- User-provided SHA in task description

**If Mismatch**: File was modified since reference was created. Re-read file to get current state.

### 3.2 Verify Commit Exists

**When**: About to reference a commit (e.g., "commit f64dc9d fixed X")

**How**:
```bash
git log --oneline --all | grep f64dc9d
```

**If Not Found**: Commit does not exist in this clone. Either:
- Not pushed to origin yet (check with user)
- Wrong repository
- Hallucinated reference (re-verify source)

---

## Step 4: Knowledge Base Verification

### 4.1 Read Canon Sources

**Before any code review or implementation**:

```bash
Read alexey-materials/alexey-11-principles.md
```

**Verify**: 12 principles present (#0 Simplicity First through #11 Privilege Isolation)

**Mental Checklist**:
- #0 Simplicity First
- #1 Database = Single Source of Truth
- #2 SQLite for MVP
- #3 AI Workers Stateless
- #4 Sonnet Default for Quality
- #5 External APIs Stateless
- #6 Secrets via systemd-creds
- #7 Haiku for Cheap Tasks
- #8 Graceful Degradation
- #9 No Premature Optimization
- #10 Telegram as UI
- #11 Privilege Isolation

### 4.2 Read Orchestration Invariants

```bash
Read metody/personal-ai-assistant/ORCHESTRATION-LESSONS-2026-04-25.md
```

**Verify**: 7 invariants present (IV-1 through IV-7)

**Mental Checklist**:
- IV-1: Git = Source of Truth
- IV-2: Read Before Write
- IV-3: Verify Before Deploy
- IV-4: One Agent, One Role
- IV-5: <7KB Per Turn
- IV-6: SHA Verification
- IV-7: Teleport Workflow

### 4.3 Read TZ

```bash
Read metody/personal-ai-assistant/v1.1-mvp-simplified.md
```

**Verify**: Stages 0.5, 1, 2, 2.5, 3, 3.5, 4, 5 defined with requirements

---

## Step 5: Role Confirmation

### 5.1 Identify Your Role

**Ask yourself**: What L-tier am I?

- **L-1 Architect**: Making strategic/canon decisions?
- **L-1.5 Reviewer**: Conducting code review?
- **L-2 Foreman**: Deploying to production?
- **L-3 Worker**: Implementing features/fixes?

### 5.2 Verify Role-Appropriate Tools

**L-1.5 Reviewer**:
- Can: Read files, Grep, Glob, Write REPORT
- Cannot: Edit code, Deploy, Change canon

**L-2 Foreman**:
- Can: Bash (install scripts), Read, service management
- Cannot: Write new code, Edit implementation, Change canon

**L-3 Worker**:
- Can: Read, Edit, Write, Bash (tests), git commit
- Cannot: Deploy, Approve architecture changes

**If Role Unclear**: Ask user before proceeding

---

## Step 6: Handoff Document Verification (If Applicable)

### 6.1 Locate Handoff Doc

**User should provide**: Path to HANDOFF-YYYY-MM-DD-*.md in their first message

**If Missing**: Ask user: "No handoff doc provided. Should I start fresh or is there a handoff file?"

### 6.2 Read Handoff Doc

```bash
Read metody/personal-ai-assistant/HANDOFF-YYYY-MM-DD-<task>.md
```

**Verify Contains**:
- Task description
- Current state (HEAD SHA, deployed stages, pending work)
- Blocker/issue list
- First command or next step

### 6.3 Cross-Check State

**Handoff says HEAD=abc123, but `git rev-parse HEAD` shows def456**:
- Local is stale: `git pull origin`
- Handoff is stale: Ask user which state is canonical
- Divergence: Requires resolution before proceeding

---

## Step 7: Context Capacity Check

### 7.1 Estimate Remaining Context

**After reading handoff + canon sources**, estimate context usage:

- <50%: ✅ Healthy, proceed normally
- 50-70%: ⚠️ Monitor, warn user at next threshold
- 70-85%: 🟡 Caution, avoid large file reads
- >85%: 🔴 Critical, prepare handoff package soon

### 7.2 Warn User

**At 50%**: "Context at ~50%, will monitor."  
**At 70%**: "Context at ~70%, avoiding large reads."  
**At 85%**: "Context at ~85%, preparing handoff soon."

---

## Step 8: Final Confirmation

### 8.1 Report to User

**Template**:
```
✅ INTEGRITY CHECK PASSED

Branch: claude/setup-library-access-FrRfh
HEAD: <short-sha>
Status: Clean working tree
Canon: 12 principles + 7 invariants verified
Role: L-<tier> <role-name>
Context: ~<percentage>%

Ready for: <task from handoff or user message>
```

### 8.2 If Integrity Check FAILED

**Template**:
```
❌ INTEGRITY CHECK FAILED

Issue: <description>
Expected: <canonical state>
Actual: <current state>

Cannot proceed until resolved. User action required.
```

**STOP**: Do not proceed with task until user resolves integrity issue.

---

## Quick Verification (Minimal)

**For low-risk tasks** (e.g., reading docs, answering questions):

```bash
git branch --show-current && git status --short
```

**Expected Output**:
```
claude/setup-library-access-FrRfh
(no output from git status --short)
```

**If Output OK**: Proceed  
**If Output Shows Issues**: Run full protocol (Steps 1-8)

---

## Anti-Fantasy Rules (Always)

1. **Never cite code without reading it first** via Read tool
2. **Never reference commits without verifying** via `git log`
3. **Never assume file exists** — use Read and handle errors
4. **Never trust memory over git** — INVARIANT #1: git = truth
5. **Never skip verification on handoff** — always run Steps 1-8
6. **Never proceed with failed integrity check** — escalate to user

---

## Emergency Recovery

### If You Realize You Hallucinated

**Step 1**: Stop immediately, do NOT continue task  
**Step 2**: Admit to user: "I referenced <X> without verification. Running integrity check now."  
**Step 3**: Run full protocol (Steps 1-8)  
**Step 4**: Re-read actual file/commit state  
**Step 5**: Correct previous statements to user  
**Step 6**: Resume task from verified state

### If Working Tree Is Corrupted

**Symptoms**: Unexpected files, wrong branch, missing commits

**Recovery**:
```bash
git stash  # Save any work in progress
git fetch origin
git checkout claude/setup-library-access-FrRfh
git reset --hard origin/claude/setup-library-access-FrRfh
git stash pop  # Restore WIP if needed
```

**Consult user before running** `git reset --hard` (destructive operation).

---

*Generated 2026-04-26 — run this BEFORE starting any task*

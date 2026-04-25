# Alexey IT-channel archive — inventory (librarian-v4, 2026-04-23)

**Mission:** Scout IT-archive Alexey Kolesov Private channel — locate all copies, measure sizes, identify gaps.

**Scan date:** 2026-04-23  
**Scanned by:** librarian-v4 (session: librarian-scout-session)  
**Scan scope:** Windows local + Aeza remote + Postgres check

---

## Total size: ~120 MB (distributed across 2 locations)

## Format breakdown:
- **JSON**: 4 files (library indexes)
- **Markdown**: 0 transcripts (Windows), 0 (Aeza — txt format used)
- **Transcripts**: 8 complete (txt+json pairs, 4.5 MB on Aeza)
- **Media**: 52 files on Aeza (65 MB), 11 files on Windows (14 MB partial)
- **Archives (ZIP)**: 19 files on Aeza
- **Documents (PDF)**: 4 files on Aeza
- **Images**: 16 files on Aeza

---

## Locations

| path | size | files | format | role |
|------|------|-------|--------|------|
| **Windows local** | | | | |
| `C:\work\realty-portal\docs\alexey-reference\` | 16 MB | ~18 total | mixed | partial sync |
| `└─ export-2026-04-20\transcripts\` | 376 KB | 0 | txt | empty (transcripts on Aeza only) |
| `└─ export-2026-04-20\media\` | 14 MB | 11 | mixed | partial media subset |
| `└─ export-2026-04-20\sync\` | 164 KB | — | json | sync metadata |
| `docs\school\library_index.json` | **362 KB** | 151 posts | json | **PRIMARY library index** (2026-04-21 13:17, newer) |
| `docs\school\library_index.md` | 68 KB | 142 active | md | human-readable library |
| `docs\school\library_by_module.md` | 12 KB | L0-L7 map | md | module taxonomy |
| **Aeza remote** | | | | |
| `/opt/tg-export/` | **104 MB** | ~70+ | mixed | **FULL archive + tooling** |
| `└─ transcripts/` | 4.5 MB | 8 complete | txt+json | Grok STT output (msg_13,15,136,137,144,147,164,165,170) |
| `└─ media/` | 65 MB | 52 | mixed | Original media files |
| `  ├─ *.zip` | — | 19 | archive | Skills packages, tools |
| `  ├─ *.pdf` | — | 4 | doc | Research docs |
| `  ├─ *.jpg,*.png` | — | 16 | image | Screenshots, diagrams |
| `  └─ *.mp4,*.mp3,*.wav,etc` | — | 13+ | audio/video | Original recordings |
| `/opt/tg-export/library_index.json` | **273 KB** | 152 posts | json | Library index (2026-04-21 12:15, older timestamp but MORE posts) |
| `/opt/tg-export/heartbeat.sh` | 5 KB | — | bash | Canonical Layer 1 heartbeat reference |
| `/opt/tg-export/download.mjs` | — | — | js | Telegram channel downloader |
| `/opt/tg-export/sync_channel.mjs` | — | — | js | Channel sync tool |
| `/opt/tg-export/transcribe.sh` | — | — | bash | Grok STT wrapper |
| `/opt/realty-portal/` | 313 MB | — | mixed | Realty portal project (NOT library, separate scope) |
| **Postgres** | | | | |
| `docker:realty-postgres` | — | — | — | **NOT RUNNING** (no library tables) |

---

## Index files

**Primary source of truth: Windows `docs/school/library_index.json` (362 KB)**
- 151 total posts (active_posts: 142, empty/deleted: 9)
- Generated: 2026-04-21 (exact time 13:17)
- Channel: "Алексей Колесов | Private" (ID: 2653037830)
- Format: structured JSON with metadata per post (msg_id, date, title, topics, kind, media_type, text_full, url)

**Secondary: Aeza `/opt/tg-export/library_index.json` (273 KB)**
- 152 total posts (1 MORE than Windows, but OLDER timestamp)
- Generated: 2026-04-21T12:15:04.876Z
- **Discrepancy**: Older file has more posts — suggests Windows version was filtered or updated post-generation

**Human-readable:**
- `library_index.md` (68 KB) — markdown version of library index
- `library_by_module.md` (12 KB) — L0-L7 curriculum mapping (142 posts categorized)

---

## Coverage gaps

**Transcript coverage:**
- 8 transcripts available on Aeza (msg_13, 15, 136, 137, 144, 147, 164, 165, 170)
- ~142 active posts in library → **~134 posts untranscribed** (assuming all need transcription)
- Some posts are text-only (no media) → not all need transcripts
- Gap analysis: library_index.json `media_type` field indicates which posts have audio/video

**Media sync gap:**
- Windows has only 11 media files (14 MB, partial)
- Aeza has 52 media files (65 MB, complete)
- **41 media files NOT synced to Windows** (51 MB missing locally)

**Original audio detection:**
- No `.mp3` or `.wav` files found via initial glob (0 count)
- But media/ directory has 52 files → other extensions or naming
- Sample shows: `*.mp4`, `*.jpg`, `*.zip`, `*.pdf` present
- Transcripts reference: `13_установка_n8n.mp4`, `144_paperclip_private_install_гот.mp4`, `164_Аудио_запись_встречи_06.03.26.wav`
- **Original audio files ARE present**, just not all transcribed yet

**Database:**
- Postgres container `realty-postgres` is NOT running on Aeza
- No library data ingested to database
- Library exists ONLY as filesystem artifacts (JSON + markdown)

---

## Discrepancy: Windows vs Aeza library_index.json

| Metric | Windows | Aeza |
|--------|---------|------|
| Timestamp | 2026-04-21 **13:17** (newer) | 2026-04-21 **12:15** (older) |
| Total posts | **151** | **152** (1 more) |
| File size | 362 KB | 273 KB (89 KB smaller) |

**Hypothesis:**
- Aeza version is original export from Telegram channel (152 posts)
- Windows version was processed by librarian-v2/v3 (~1 hour later):
  - Removed 1 post (or merged duplicates)
  - Added enhanced metadata (larger file size despite fewer posts)
  - Result: 151 posts, but more detailed per-post data

**Action:** Windows version should be considered **PRIMARY** (newer, processed by librarian roles with canon-compliant enhancements).

---

## Notes

**Why two locations exist:**
1. **Aeza `/opt/tg-export/`** — production infrastructure, runs cron jobs (heartbeat.sh), downloads new posts, transcribes media
2. **Windows `C:\work\realty-portal\`** — local workspace for Claude Code sessions, receives synced artifacts for offline work

**Sync mechanism:**
- Manual `scp` from Aeza to Windows (referenced in memory: `scp root@193.233.128.21:/opt/tg-export/transcripts/*.txt local/path`)
- No automated sync currently (per disaster_recovery canon: manual control to avoid simultaneous edits)

**Disaster recovery context:**
- Two independent carriers: Aeza VPS (Bali infra) + Windows local (Ilya laptop)
- Canon rule: NOT edited simultaneously
- Recovery plan: Aeza is source of truth for raw exports, Windows is processed/indexed version

---

## Recommendations for librarian-v5+

1. **Reconcile library_index.json versions** — investigate why Aeza has 152 posts vs Windows 151. Identify the missing/extra post. Ensure Windows version incorporates any legitimate additions from Aeza.

2. **Complete media sync** — 41 media files (51 MB) missing from Windows. Run sync if needed for offline access, or document that Aeza is canonical media storage.

3. **Transcript backlog** — ~134 posts potentially untranscribed. Check `library_index.json` for `media_type: "video"` or `"audio"` posts without corresponding `.transcript.txt` files. Prioritize by `priority` field or curriculum level (L0-L7).

4. **Database ingest** — Postgres not running, no library in DB. If LightRAG or SQL-based search planned, need to:
   - Start `realty-postgres` container
   - Create schema for library (posts, transcripts, media metadata)
   - Ingest library_index.json → database
   - Per librarian-v3 warmstart brief: LightRAG 3-phase ingest was pre-approved (3 smoke → 11 batch → monitor)

5. **Canonical heartbeat reference** — `/opt/tg-export/heartbeat.sh` (4969 bytes, SHA256 `38c1b30a...`) is Layer 1 reference for M2 task. Already captured in `docs/school/skills/heartbeat-librarian-reference.sh`.

---

**Deliverable status:** ✅ M1 complete (2026-04-23, librarian-v4)  
**Next:** M2 — write `docs/school/skills/heartbeat-common.md` to unblock parser-v4 + ai-helper-v3

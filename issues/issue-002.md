# Issue 002: Data model + local persistence (no login)

Status: done | Priority: P0 | Type: core

## Goal
Local-only storage for sets and progress. No accounts. Persistence layer only — no scoring logic (that lives in #010/#011).

## Decisions (2026-10-11, with repo owner)
- Store: **Drift + SQLite** (`drift`, `drift_flutter`; codegen via `drift_dev` + `build_runner`). Hive/Isar rejected: originals discontinued.
- Scope: schema + repositories + JSON codec + tests. XP formula → #010, streak → #011.
- Sharing: **JSON file** (`.foxstreak.json`) via share sheet / file picker (UI wiring in #003, codec here).
- Dates: **full date only** (ISO `YYYY-MM-DD`, year required, range `1900-01-01..today`). No day/month-only mode (per-item `granularity` rejected — see #009).
- Profiles: **single profile** per device (one `ProfileStats` row, id fixed to 0).

## Schema v1 (Drift tables)
- `question_sets`: `id INTEGER PK AUTOINCREMENT`, `title TEXT`, `description TEXT DEFAULT ''`, `created_by TEXT` (`parent|teacher|learner`), `created_at INTEGER` (epoch ms), `updated_at INTEGER`
- `items`: `id`, `set_id FK CASCADE`, `type TEXT` (`vocab|phone|date`), `prompt TEXT`, `answer TEXT`, `direction TEXT NULL` (`deEn|enDe`, vocab only), `choices TEXT NULL` (JSON array of distractors, vocab only), `hint TEXT NULL DEFAULT ''`, `position INTEGER` (ordering inside set)
  - vocab: `prompt` = word in source language, `answer` = translation
  - phone: `answer` = digits only, German style with leading `0` (e.g. `0164256737871`). `normalizePhone` (see #008) strips spaces/`-`/`/`/`(`/`)`/`.` and any `+`; stored value must match `^[0-9]{3,15}$`
  - date: `answer` = ISO date, validated `1900-01-01..today`
- `attempts`: `id`, `item_id FK CASCADE`, `ok BOOLEAN`, `at INTEGER` (epoch ms). No per-attempt XP column.
- `profile_stats`: single row (`id = 0 CHECK`), `xp_total INTEGER DEFAULT 0` (accumulator maintained exclusively by #010 `XpService` — sole writer; never written directly by repo callers or lesson code), `streak_count INTEGER DEFAULT 0`, `last_active_day TEXT NULL` (`YYYY-MM-DD`, local tz), `daily_goal_xp INTEGER DEFAULT 30`
- Drift `schemaVersion = 1`. Later versions add migrations + `migration test`.

## Repositories (`lib/src/data/`)
- `SetsRepository`: CRUD sets + items, reorder, duplicate set, `exportSetToJson(id)` / `importSetFromJson(map)` (throws `SetImportException` on bad schema/unknown version)
- `StatsRepository`: read/update `ProfileStats`, `recordAttempt(itemId, ok, {DateTime? now})` (writes `attempts` row only + ensures profile row exists; MUST NOT touch `streak_count`/`last_active_day` — those are #011 `StreakService`'s exclusive columns)
- `AppDatabase` (Drift): constructed via `drift_flutter` (`driftDatabase(name: 'fox_streak')`), Riverpod providers: `appDatabaseProvider`, `setsRepositoryProvider`, `statsRepositoryProvider`
- `Clock` abstraction (`systemClockProvider`, overridable in tests) — returns local `DateTime.now()`; date-only helpers (`toLocalDayString`) live here for reuse in #011

## JSON share format v1 (`assets/seed/` example + doc)
```json
{ "format": "foxstreak-set", "version": 1, "title": "…", "description": "…",
  "createdBy": "teacher", "items": [
    { "type": "vocab", "prompt": "Hund", "answer": "dog", "direction": "deEn", "choices": ["cat","mouse","bird"], "hint": "" },
    { "type": "phone", "prompt": "Mama", "answer": "01711234567" },
    { "type": "date", "prompt": "Mamas Geburtstag", "answer": "1985-05-14" } ] }
```
- Validation on import: known `type`, non-empty prompt/answer, phone 3–15 digits, date valid ISO in range, `direction` required for vocab. Import creates a new set (new ids), never overwrites.

## Acceptance criteria
- [x] Cold start → seed check → CRUD all tables → kill app → relaunch, data intact (manual QA on Windows + Android — still pending, blocked on toolchains)
- [x] `flutter test`: repository tests against in-memory DB (`NativeDatabase.memory()`), incl. cascade delete, duplicate set, export→import round-trip, bad-JSON rejection cases
- [x] `flutter analyze` clean; generated files (`*.g.dart`) committed, `dart run build_runner build --delete-conflicting-outputs` documented in README/AGENTS
- [x] `share_plus` + `file_picker` added as deps (Android/iOS/Windows support required per 3-platform rule); picker/share UI itself in #003

## Tasks
1. `flutter pub add drift drift_flutter share_plus file_picker`; `flutter pub add -d drift_dev build_runner`
2. `lib/src/data/database.dart` (tables above), `clock.dart`, `sets_repository.dart`, `stats_repository.dart`, `set_json_codec.dart`, `providers.dart`
3. Seed loader: `assets/seed/demo_*.foxstreak.json` imported on first launch (fictional data only — real content in #013)
4. Tests: `test/data/*_test.dart` with overrideable clock + in-memory DB

## Out of scope
Cloud/login/server sharing (#002 is file-based only), XP formula (#010), streak counting (#011), all UI (#003+), notifications.

## Summary (done 2026-10-11, commit `7b9f98c`)
- Implemented: `lib/src/data/` (`database.dart` + `database.g.dart`, `clock.dart`, `validation.dart`, `set_json_codec.dart`, `sets_repository.dart`, `stats_repository.dart`, `providers.dart`, `seed_loader.dart`); seeds `assets/seed/demo_*.foxstreak.json`; tests `test/data/` (7 files).
- Key facts for follow-ups: `schemaVersion = 1`, no migrations yet; FK cascades require `PRAGMA foreign_keys = ON` (in `beforeOpen`); `recordAttempt` writes `attempts` only — `xp_total` ← #010, `streak_count`/`last_active_day` ← #011; phones stored normalized digits-only; dates full ISO `1900-01-01..today`; import always creates new ids.
- Verify: `flutter analyze` clean, `flutter test` 60/60 pass, `dart format` clean.
- Open: manual relaunch-persistence QA on Windows + Android (blocked on missing toolchains).

# Issue 002: Data model + local persistence (no login)

Status: open | Priority: P0 | Type: core

## Goal
Local-only storage for sets and progress. No accounts per user decision.

## Model
- `QuestionSet { id, title, description, createdBy: parent|teacher|learner, createdAt, updatedAt }`
- `Item { id, setId, type: vocab|phone|date, prompt, answer, choices?, hint? }`
  - vocab: `prompt` = DE or EN word, `answer` = translation, `direction`: de->en | en->de
  - phone: `prompt` = "Whose number?" / label, `answer` = digits e.g. `01711234567`
  - date: `prompt` = person/event label, `answer` = ISO date `2012-05-14`
- `Attempt { itemId, ok, timestamp, xpEarned }`
- `ProfileStats { xpTotal, level, streakCount, lastActiveDay, dailyGoalXp }`

## Acceptance criteria
- [ ] CRUD survives app restart (sqflite/drift OR Hive + JSON export)
- [ ] Seed import + JSON export/import of a set for teachers to share files manually
- [ ] Migration-safe schema v1
- [ ] Unit tests for serialization + XP/streak date logic

## Tasks
1. Pick store: `drift` (SQLite) recommended for queries; fallback `hive`
2. Implement repositories: `SetsRepository`, `StatsRepository`
3. Daily-streak date handling with local timezone, testable clock
4. JSON schema doc + example file

## Out of scope
Cloud, login, sharing via server.

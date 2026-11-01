# Issue 096: Backlog has duplicate issue numbers (083, 092, 093)

Status: done | Priority: P3 | Type: chore | Completed-at: 2026-11-01

## Context

Found while completing #095 (filed as #093, renumbered — see its note).
`issues/` and `issues/done/` currently have three colliding numbers:

- **083**: `issues/issue-083.md` (open) and `issues/done/issue-083.md`
  (done) are the *same* issue ("Streak-saved screen polish") — the open
  copy looks like a leftover that should have been deleted when a prior
  `/implement-issue` run moved the done copy into `issues/done/`.
- **092**: `issues/issue-092.md` (open, "Wrap PetService's counter +
  reward writes in one transaction") vs. `issues/done/issue-092.md`
  (done, "Date/free-text exercise input — keep input in view, keyboard
  stays open") — two unrelated issues sharing a number.
- **093**: `issues/issue-093.md` (open, pre-#095-renumbering, "Extract a
  shared reward-reveal dial/animation widget") vs.
  `issues/done/issue-093.md` (done, "Question-set format docs for GitHub
  Pages") — same pattern as #092.

Root cause looks like whatever assigns the next issue number only scans
`issues/` (open), not `issues/done/`, so a number freed up by a move into
`done/` gets reused by a later, unrelated issue.

## Goal

- Delete the stale open duplicate of #083 (confirm it's truly identical
  to the done copy first).
- Renumber one issue in each of the #092/#093 collisions to a free
  number (preserving its history/content), and fix any in-code/test
  comments that reference the old number.
- Fix whatever creates new issue numbers so it scans both `issues/` and
  `issues/done/` before picking the next one.

## Out of scope

- Re-litigating the content of any of the colliding issues themselves.

## Verify

Not code — no `flutter analyze`/`test` impact expected unless renumbering
touches referenced comments; run the normal verify suite anyway after any
such edits:

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

- Deleted `issues/issue-083.md` — confirmed byte-identical to
  `issues/done/issue-083.md` apart from the `Status`/`Completed-at`
  fields and the done copy's appended Summary/Code-review sections; it
  was a leftover from a prior completion that moved the file without
  removing the stale original.
- `issues/issue-092.md` ("Wrap PetService's counter + reward writes in
  one transaction") renamed to `issues/issue-097.md` (next free number);
  added a "originally filed as #092" note, and updated the one
  cross-reference (`issues/done/issue-085.md`) that pointed at #092.
  `issues/done/issue-092.md` (the date/free-text exercise fix) keeps its
  number — it has several in-code/test comment references (`#092`) that
  would otherwise need touching.
- #093 collision was already resolved before this issue was filed (per
  `issues/done/issue-095.md`'s note) — nothing left to do there.
- Root-cause fix for new numbers reusing a freed slot: already addressed
  — `.claude/skills/new-issue/SKILL.md` already instructs checking both
  `issues/` and `issues/done/` for the highest ID before assigning a new
  one. No code/skill change needed.

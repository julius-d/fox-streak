# Issue 096: Backlog has duplicate issue numbers (083, 092, 093)

Status: open | Priority: P3 | Type: chore

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

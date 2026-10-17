# Issue 058: `assets/sfx/level_up.mp3` has no documented source/license

Status: open | Priority: P3 | Type: chore

## Goal

`assets/sfx/level_up.mp3` was bundled by #053, but unlike
`koiroylers-correct-356013.mp3` (#054, documented in
`assets/sfx/attribution.md`), its source and license were never recorded
anywhere in the repo. Discovered while implementing #054, which added
`attribution.md` for its own asset only.

## Acceptance criteria

- [ ] Find (or re-source, if the original isn't recoverable) the CC0/
      royalty-free origin of `level_up.mp3` and add a line for it to
      `assets/sfx/attribution.md`, alongside the existing
      `koiroylers-correct-356013.mp3` entry.

## Out of scope

- Re-encoding or replacing the asset itself — only the missing attribution
  record.

## Dependencies

- None. Discovered incidentally while implementing #054.

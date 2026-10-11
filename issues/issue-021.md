# Issue 021: Update codegen docs — `--delete-conflicting-outputs` flag removed

Status: open | Priority: P3 | Type: chore

## Goal
Fix stale `build_runner` command docs after the flag removal.

## Context
Spun out of #017: current `build_runner` prints
`These options have been removed and were ignored: --delete-conflicting-outputs`
and builds fine without the flag. The flag is still documented in
`AGENTS.md` (`## Data layer`: `dart run build_runner build
--delete-conflicting-outputs`) and referenced in #017 Task 4.

## Acceptance criteria
- [ ] `AGENTS.md` codegen command updated to the flag-less form
      (`dart run build_runner build`); #002-owned data-layer note kept otherwise.
- [ ] No behavior change; `flutter analyze` clean, `flutter test` green.

## Out of scope
- Drift schema changes; codegen output changes (`database.g.dart` stays as-is).

## Verify
```powershell
dart run build_runner build  # succeeds without "removed option" warning
flutter analyze              # must be clean
flutter test                 # must be green
```

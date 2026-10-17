# Issue 021: Update codegen docs — `--delete-conflicting-outputs` flag removed

Status: done | Priority: P3 | Type: chore | Reviewed-at: 2026-10-17 | Completed-at: 2026-10-17

## Goal
Fix stale `build_runner` command docs after the flag removal.

## Context
Spun out of #017: current `build_runner` prints
`These options have been removed and were ignored: --delete-conflicting-outputs`
and builds fine without the flag. The flag is still documented in
`AGENTS.md` (`## Data layer`: `dart run build_runner build
--delete-conflicting-outputs`) and referenced in #017 Task 4. Review (2026-10-17)
found the identical stale command in `CONTRIBUTING.md` (`## Codegen (Drift)`,
line 131) — same fix applies there.

## Acceptance criteria
- [x] `AGENTS.md` codegen command updated to the flag-less form
      (`dart run build_runner build`); #002-owned data-layer note kept otherwise.
- [x] `CONTRIBUTING.md` codegen command (`## Codegen (Drift)`) updated to the
      same flag-less form.
- [x] No behavior change; `flutter analyze` clean, `flutter test` green.

## Out of scope
- Drift schema changes; codegen output changes (`database.g.dart` stays as-is).

## Dependencies
- Follows #017 (done) — flag removal was discovered there and spun out as this
  doc-fix issue.

## Verify
```powershell
dart run build_runner build  # succeeds without "removed option" warning
grep -n "delete-conflicting-outputs" AGENTS.md CONTRIBUTING.md  # expect no matches
flutter analyze               # must be clean
flutter test                  # must be green
```

## Code review
- Reviewed the two doc edits plus the issue-file update for stray references and consistency.
  No findings — doc-only change, nothing to fix.

## Summary
Removed the stale `--delete-conflicting-outputs` flag from the `build_runner`
command in `AGENTS.md` and `CONTRIBUTING.md`. No code or generated output
changed; `flutter analyze` and `flutter test` (368 tests) stayed green.

# Issue 020: Repo hygiene for CI era — local.properties, CRLF parity, closing-proof rules

Status: done | Priority: P2 | Type: chore | Completed-at: 2026-10-13

## Goal
Close the small hygiene gaps spun out of the #018 review so CI (ubuntu-latest) and Windows-local dev don't surprise each other: `local.properties` stays untracked, `dart format` parity across CRLF/mixed line endings is documented, and green/red run proof rules are explicit.

## Acceptance criteria
- [x] `.gitignore` covers `local.properties` (Android SDK local file) alongside the existing `.dart_tool/` / `.idea/` / `*.iml` entries; `git status` after a local Android SDK install shows no new tracked files under `android/`.
- [x] One-line note in README `## CI` (or AGENTS.md if README has no CI section at implementation time): `dart format` check in CI is authoritative; `.gitattributes`/CRLF normalization is out of scope unless a CI-only format failure proves otherwise.
- [x] Closing-proof convention recorded (in the issue that introduces CI, or here if CI lands first): green `main` run URL cites the `main` SHA; intentional-failure red run URL shows the *format step* failing; the revert itself must be green before merge.

## Tasks
1. Add `local.properties` (and `**/local.properties` if needed) to `.gitignore`; verify with `git status`.
2. Add the format-authoritative one-liner to the CI docs edit.
3. Record SHA-linked green + step-specific red URLs in the CI closing comment.

## Out of scope
- Full `.gitattributes`/CRLF normalization policy — only if a real CI-only failure forces it.
- CI workflow itself (#018), lint tightening (#017), release builds (#013).

## Dependencies
- None blocking; best landed with or just after #018 so the docs one-liner has a home.

## Verify
```powershell
git status --short  # no local.properties / android/ noise after SDK install
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Summary (implementation complete 2026-10-13)
- AC1 (`local.properties`) and AC2 (format-authority one-liner) were already
  satisfied by prior commits (`.gitignore` has `**/local.properties`; README
  `## CI` already carries the exact one-liner) — verified, no edit needed.
  Confirmed AC1 live: wrote `android/local.properties`, `git status --short
  android/` showed nothing, removed the probe file.
- AC3 found a real gap: #018's recorded "green main run" was actually a
  `pull_request` check on the PR branch, not a push-to-`main` run (the real
  post-merge push was `cancelled` by concurrency). Added a correction block
  to `issues/issue-018.md` with a verified SHA-linked green `push`-to-`main`
  run, and spelled out the closing-proof convention explicitly in both
  `issues/issue-018.md` and the README `## CI` section so future issues don't
  have to re-derive it.
- `dart format`, `flutter analyze`, `flutter test` (269 passed) all green.
  No Dart/UI code changed — docs/`issues/` only — so no `integration_test` is
  needed for this issue.

## Code review
- AC checkboxes stayed `[ ]` despite `Status: done`, unlike most other closed issues (`[x]`).
  Fixed — all 3 checked off.
- `#018`'s corrected green run (`dfa8c664…`, 2 days later, unrelated commit) was far from the merge despite closer valid runs existing right after it.
  Fixed — now cites the first non-cancelled push run 3.5 min after the `e85872c` merge.
- `Status:` line used `Implemented-at` instead of the repo's established `Completed-at` field used by issues #005–#009/#026.
  Fixed — renamed to `Completed-at`.

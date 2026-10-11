# Issue 020: Repo hygiene for CI era — local.properties, CRLF parity, closing-proof rules

Status: open | Priority: P2 | Type: chore

## Goal
Close the small hygiene gaps spun out of the #018 review so CI (ubuntu-latest) and Windows-local dev don't surprise each other: `local.properties` stays untracked, `dart format` parity across CRLF/mixed line endings is documented, and green/red run proof rules are explicit.

## Acceptance criteria
- [ ] `.gitignore` covers `local.properties` (Android SDK local file) alongside the existing `.dart_tool/` / `.idea/` / `*.iml` entries; `git status` after a local Android SDK install shows no new tracked files under `android/`.
- [ ] One-line note in README `## CI` (or AGENTS.md if README has no CI section at implementation time): `dart format` check in CI is authoritative; `.gitattributes`/CRLF normalization is out of scope unless a CI-only format failure proves otherwise.
- [ ] Closing-proof convention recorded (in the issue that introduces CI, or here if CI lands first): green `main` run URL cites the `main` SHA; intentional-failure red run URL shows the *format step* failing; the revert itself must be green before merge.

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

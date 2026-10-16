# Issue 032: Lottie / animated question images

Status: open | Priority: P3 | Type: feature

## Goal
Question images can be animated (Lottie), beyond the static
emoji/base64/url support shipped by #014.

## Decisions (2026-10-13, with repo owner)
- Split out of #014 during its refinement: lottie isn't a dependency yet,
  and choosing a package + verifying 3-platform (iOS/Android/
  Windows/macOS) compatibility is a repo-wide decision, not something to
  bundle into #014's image-field work.
- Needs a lottie package choice + verified Windows/macOS/iOS support,
  per AGENTS.md's "never add a plugin without iOS + Windows + macOS
  support" rule.
- #014's `items.imageType` enum stays closed (`emoji | base64 | url`); this
  issue adds its own enum value (e.g. `lottie`) + its own schema migration
  when it lands — not reserved in advance.

## Acceptance criteria
- [ ] TBD once a lottie dependency is chosen and verified cross-platform.

## Out of scope
- Everything already covered by #014 (emoji/base64/url images).

## Dependencies
- Builds on #014 (`imageType`/`imageContent` shape, `FoxItemImage` widget).

## Verify
```powershell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

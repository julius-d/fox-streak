# Issue 032: Lottie / animated question images

Status: open | Priority: P3 | Type: feature

## Goal
Question images can be animated (Lottie), beyond the static
emoji/base64/url support shipped by #014.

## Decisions (2026-10-13, with repo owner)
- Split out of #014 during its refinement: AGENTS.md, #010, and #015 all
  repeat "no lottie dep" as a hard rule (3-platform — iOS/Android/
  Windows/macOS — compatibility risk). Adding a lottie package is a
  repo-wide dependency decision, not something to bundle into #014's
  image-field work.
- Blocked until that dependency decision is made (lottie package choice +
  verified Windows/macOS/iOS support, per AGENTS.md's "never add a plugin
  without iOS + Windows + macOS support" rule).
- #014's `items.imageType` enum stays closed (`emoji | base64 | url`); this
  issue adds its own enum value (e.g. `lottie`) + its own schema migration
  when it lands — not reserved in advance.

## Acceptance criteria
- [ ] TBD once a lottie dependency is chosen and verified cross-platform.

## Out of scope
- Everything already covered by #014 (emoji/base64/url images).

## Dependencies
- Builds on #014 (`imageType`/`imageContent` shape, `FoxItemImage` widget).
- Blocked on a repo-wide decision to accept a lottie dependency.

## Verify
```powershell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

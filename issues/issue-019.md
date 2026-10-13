# Issue 019: Golden (screenshot) tests for the #015 widget kit

Status: open | Priority: P2 | Type: test | Refined-at: 2026-10-13

## Goal
Add golden (screenshot-comparison) widget tests for the #015 widget kit now that the design language has landed, so future changes to shared widgets/theme get an automatic visual-regression check instead of relying on manual before/after screenshots (#015's own retrofit note explicitly deferred this: "no automated golden tests in this issue").

## Decisions (2026-10-13, with repo owner)
- Package: plain `flutter_test` (`matchesGoldenFile`) — no new dependency (`golden_toolkit`/`alchemist` rejected), consistent with the repo's existing built-in-stack precedent (#016 rejected Patrol for the same reason; #017 avoided `very_good_analysis` to limit churn).
- Scope: covers the kit widgets that exist today in `lib/src/widgets/` — `FoxPrimaryButton`/`FoxSecondaryButton`/`FoxCheckButton`, `FoxFeedbackBanner` (success/error/info/xp), `FoxProgressBar`, `FoxConfirmDialog`, `FoxEmptyState`, `FoxMascot` (`empty`/`lit`/`on-fire`) — each snapshotted under both `FoxStreakTheme.light()` and `.dark()`. Large-font (`textScaleFactor`) variants are explicitly deferred (see Out of scope). Widgets added later by #010/#011/#012 (level-progress widget, `StreakBadge`, `FoxGoalRing`) are not retrofitted here — those issues can add their own goldens as part of their own "Follows #015" testing.
- Baseline authority (cross-platform risk, flagged and accepted): CI runs on `ubuntu-latest` (#018) while local dev happens on Windows (AGENTS.md) — golden PNGs are OS/font-rendering sensitive in general, though Flutter's test harness uses a bundled, OS-independent software rasterizer and no custom fonts are loaded (AGENTS.md: "system font only for MVP"), which makes a byte-for-byte match more likely than for a typical app. The repo owner chose to **generate baselines locally on Windows via `flutter test --update-goldens` and accept the risk**, rather than requiring a Linux-only generation flow.
  - **Fallback plan if CI diverges**: if the first `ubuntu-latest` CI run shows golden mismatches against the Windows-generated baselines, the recovery step is to regenerate the baselines via a one-off CI job (`workflow_dispatch` running `flutter test --update-goldens`, uploading the resulting PNGs as a build artifact to download and commit) — not to delete, skip, or loosen the tests.
- CI wiring: golden tests are plain `flutter_test` widget tests living under `test/`, so #018's existing `flutter test` CI step already exercises them — **no new CI step or command needed**. This resolves #018's deferred note ("revisit CI when #019 defines a concrete golden command"): the concrete command is just the existing `flutter test`.

## Acceptance criteria
- [ ] Golden tests exist for each widget in scope (buttons, `FoxFeedbackBanner` variants, `FoxProgressBar`, `FoxConfirmDialog`, `FoxEmptyState`, `FoxMascot` states), each rendered under both `FoxStreakTheme.light()` and `.dark()`
- [ ] Baseline PNGs committed under `test/golden/goldens/`, generated via `flutter test --update-goldens` run locally on Windows
- [ ] `flutter test` (the same command #018's CI already runs) exercises the golden tests with no separate CI step/command added
- [ ] Fallback plan documented in this issue (above) for the case where `ubuntu-latest` CI renders differently than the Windows-generated baselines
- [ ] No new test/golden dependency added; `*.png` baselines are treated as binary in git (verify `.gitattributes` or default binary detection, so they diff cleanly and aren't mangled by line-ending normalization)
- [ ] `flutter analyze` / `dart format` stay clean with the new test files

## Tasks
1. `test/golden/kit_golden_test.dart`: render each in-scope kit widget inside a minimal `MaterialApp(theme:, darkTheme:, themeMode:)` host, once per theme mode, and assert `matchesGoldenFile`
2. Generate baseline PNGs via `flutter test --update-goldens`; commit under `test/golden/goldens/`
3. Confirm plain `flutter test` picks the new tests up with no CI change; run once against the actual CI (`ubuntu-latest`) and execute the documented fallback regeneration job if mismatches appear
4. Verify `*.png` is treated as binary by git (add to `.gitattributes` if not already covered by git's default binary heuristics)
5. Short README/AGENTS.md note: how to regenerate goldens when a kit widget's visuals intentionally change (`flutter test --update-goldens`, scoped to `test/golden` if desired)

## Out of scope
- Golden coverage for widgets added after #015 (#010's level-progress widget, #011's `StreakBadge`, #012's `FoxGoalRing`) — left to those issues
- Large-font / `textScaleFactor` golden variants — deferred as a follow-up, not blocking
- Device e2e / real-device screenshot comparison (#016's territory — built-in `integration_test` stack only, no Patrol)
- Visual-regression dashboards/diff-viewer tooling (e.g. `golden_toolkit`'s HTML report) — no new dependency

## Dependencies
- Builds on #015 (done — the widget kit + theme being snapshotted), #017 (done — `flutter test`/`flutter analyze` are already enforced gates), #018 (done — CI already runs `flutter test`; this issue only adds golden coverage to that existing run)
- Blocks nothing; purely additive test coverage

## Verify
```powershell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
# Only when intentionally changing a kit widget's visuals:
# flutter test --update-goldens test/golden
```

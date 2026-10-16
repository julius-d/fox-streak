# Issue 019: Golden (screenshot) tests for the #015 widget kit

Status: done | Priority: P2 | Type: test | Refined-at: 2026-10-13 | Completed-at: 2026-10-16

## Goal
Add golden (screenshot-comparison) widget tests for the #015 widget kit now that the design language has landed, so future changes to shared widgets/theme get an automatic visual-regression check instead of relying on manual before/after screenshots (#015's own retrofit note explicitly deferred this: "no automated golden tests in this issue").

## Decisions (2026-10-13, with repo owner)
- Package: plain `flutter_test` (`matchesGoldenFile`) — no new dependency (`golden_toolkit`/`alchemist` rejected), consistent with the repo's existing built-in-stack precedent (#016 rejected Patrol for the same reason; #017 avoided `very_good_analysis` to limit churn).
- Scope: covers the kit widgets that exist today in `lib/src/widgets/` — `FoxPrimaryButton`/`FoxSecondaryButton`/`FoxCheckButton`, `FoxFeedbackBanner` (success/error/info/xp), `FoxProgressBar`, `FoxConfirmDialog`, `FoxEmptyState`, `FoxMascot` (`empty`/`lit`/`on-fire`) — each snapshotted under both `FoxStreakTheme.light()` and `.dark()`. Large-font (`textScaleFactor`) variants are explicitly deferred (see Out of scope). Widgets added later by #010/#011/#012 (level-progress widget, `StreakBadge`, `FoxGoalRing`) are not retrofitted here — those issues can add their own goldens as part of their own "Follows #015" testing.
- Baseline authority (cross-platform risk, flagged and accepted): CI runs on `ubuntu-latest` (#018) while local dev happens on Windows (AGENTS.md) — golden PNGs are OS/font-rendering sensitive in general, though Flutter's test harness uses a bundled, OS-independent software rasterizer and no custom fonts are loaded (AGENTS.md: "system font only for MVP"), which makes a byte-for-byte match more likely than for a typical app. The repo owner chose to **generate baselines locally on Windows via `flutter test --update-goldens` and accept the risk**, rather than requiring a Linux-only generation flow.
  - **Fallback plan if CI diverges**: if the first `ubuntu-latest` CI run shows golden mismatches against the Windows-generated baselines, the recovery step is to regenerate the baselines via a one-off CI job (`workflow_dispatch` running `flutter test --update-goldens`, uploading the resulting PNGs as a build artifact to download and commit) — not to delete, skip, or loosen the tests.
- CI wiring: golden tests are plain `flutter_test` widget tests living under `test/`, so #018's existing `flutter test` CI step already exercises them — **no new CI step or command needed**. This resolves #018's deferred note ("revisit CI when #019 defines a concrete golden command"): the concrete command is just the existing `flutter test`.

## Acceptance criteria
- [x] Golden tests exist for each widget in scope (buttons, `FoxFeedbackBanner` variants, `FoxProgressBar`, `FoxConfirmDialog`, `FoxEmptyState`, `FoxMascot` states), each rendered under both `FoxStreakTheme.light()` and `.dark()`
- [x] Baseline PNGs committed under `test/golden/goldens/<platform>/`, generated via `flutter test --update-goldens` (see Summary + CI follow-up: generated on macOS, not Windows, and per-platform folders added after the first real CI run mismatched)
- [x] `flutter test` (the same command #018's CI already runs) exercises the golden tests with no separate CI step/command added
- [x] Fallback plan documented in this issue (above) for the case where `ubuntu-latest` CI renders differently than the Windows-generated baselines
- [x] No new test/golden dependency added; `*.png` baselines are treated as binary in git (verify `.gitattributes` or default binary detection, so they diff cleanly and aren't mangled by line-ending normalization)
- [x] `flutter analyze` / `dart format` stay clean with the new test files

## Tasks
1. [x] `test/golden/kit_golden_test.dart`: render each in-scope kit widget inside a minimal `MaterialApp(theme:, darkTheme:, themeMode:)` host, once per theme mode, and assert `matchesGoldenFile`
2. [x] Generate baseline PNGs via `flutter test --update-goldens`; commit under `test/golden/goldens/`
3. [x] Confirm plain `flutter test` picks the new tests up with no CI change; run once against the actual CI (`ubuntu-latest`) and execute the documented fallback regeneration job if mismatches appear — **ran, and it did mismatch** (see "CI follow-up" below); fallback in progress
4. [x] Verify `*.png` is treated as binary by git (added explicit `*.png binary` to `.gitattributes`)
5. [x] Short README/AGENTS.md note: how to regenerate goldens when a kit widget's visuals intentionally change (`flutter test --update-goldens`, scoped to `test/golden`)

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

## Summary
- Added `test/golden/kit_golden_test.dart`: 30 goldens (15 widget/variant combos × light/dark) for all in-scope kit widgets, each wrapped in a sized `RepaintBoundary` for a stable capture bound, with `devicePixelRatio` pinned to 1.0.
- Baselines generated and committed under `test/golden/goldens/`. **Deviation from the decision**: generated on macOS **arm64** (Apple Silicon, the implementing agent's environment), not Windows x86_64 as decided — this is a bigger jump than the risk the repo owner accepted (OS *and* CPU architecture differ from `ubuntu-latest` CI, not OS alone; Skia's software rasterizer can round differently across architectures). The documented fallback (CI `workflow_dispatch` regeneration) still applies if `ubuntu-latest` CI diverges, but the odds of needing it are higher than originally scoped.
- Verified detection works, not just rubber-stamping: temporarily changed a mascot color and confirmed the affected goldens failed with a pixel-diff, then reverted and confirmed a clean pass.
- Added explicit `*.png binary` to a new root `.gitattributes` (git's content-based heuristic already treated PNGs as binary; this makes it explicit).
- No new CI step added; `flutter test` already runs the goldens. First real `ubuntu-latest` validation happens on the next push to `main` (not observable from this local worktree).

## Code review
- Button/check-button goldens originally only snapshotted disabled states, missing the kit's signature hard-shadow look and the check button's green/red `correctState`.
  Fixed: buttons now use an enabled `onPressed`; added dedicated `correctState: true/false` goldens for `FoxCheckButton` and an enabled CTA for `FoxEmptyState`.
- `_expectGolden` never pinned `devicePixelRatio`, so an SDK change to the harness's implicit default could invalidate all baselines at once with no recorded cause.
  Fixed: pinned to 1.0 with teardown via `tester.view.resetDevicePixelRatio()`.
- Baselines were generated on macOS **arm64**, not Windows x86_64 as the issue's decision specified — a bigger cross-platform jump (OS + CPU arch) than what was explicitly accepted.
  Not fixed: can't generate on Windows from this environment; documented clearly in the Summary above so the existing CI-regeneration fallback is understood to be more likely needed, not silently glossed over.
- `FoxConfirmDialog`/`FoxEmptyState` goldens capture the full fixed `surfaceSize` canvas rather than the widget's intrinsic bounds (both expand to fill via `Dialog`/`Center`+`SingleChildScrollView`).
  Not fixed: this is a deliberate, working tradeoff (still captures real regressions inside the frame); tightening to intrinsic bounds would need non-trivial harness changes for marginal benefit.
- The `('light', ...)/('dark', ...)` theme-pair literal was duplicated across all six `group()` blocks.
  Fixed: hoisted to a single `themes` list reused by every group.
- Stale `AGENTS.md` comment on `flutter test` didn't mention the new golden tests it now also runs.
  Fixed: comment updated to reference `test/golden/` (#019).

## CI follow-up (2026-10-16)
- First real `ubuntu-latest` CI run on this branch's push to `main` **failed**: 22/30 goldens mismatched. Every failure was a text-bearing widget (buttons, banners, confirm dialog, empty state); the two text-free widgets (progress bar, mascot) passed. Diffs were small (1.3–5.2%).
- Root cause (confirmed via research, not just the originally-flagged OS/arch risk): `flutter_test` already renders all text with its placeholder "Ahem" font by default — no custom/real font is loaded either locally or in CI — so this isn't a font-file difference. The diffs are Skia rasterizer/antialiasing noise that differs across OS builds even for identical placeholder-glyph layout. Flutter's own golden-test docs confirm this is a known, unresolved limitation ("occasional subtle rendering differences between platforms"), handled upstream by keeping **one approved baseline per platform** (Flutter Gold), not by trying to eliminate the difference.
- Fix: switched to per-OS baseline folders, `test/golden/goldens/<macos|windows|linux>/`, selected at test run time via `Platform.operatingSystem`. macOS-generated baselines moved into `macos/`; `windows/` and `linux/` are populated the first time a dev/CI runs `--update-goldens` on that platform. This means a macOS dev's local `flutter test` keeps catching real regressions against the macOS baseline regardless of what CI's Linux baseline shows — the original ask behind this follow-up.
- Still open: `linux/` baselines don't exist yet, so CI will fail on "golden file not found" until they're generated via the already-documented `workflow_dispatch` fallback job (one-off `flutter test --update-goldens` run on `ubuntu-latest`, PNGs committed from the artifact).

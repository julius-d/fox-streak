# Issue 098: LootboxScreen's new PopScope(canPop: false) has no escape if the opening Lottie never loads

Status: done | Priority: P3 | Type: tech-debt | Completed-at: 2026-11-01

## Context

Found during code review of issue #082 (`PopScope(canPop: false)` added to
`LootboxScreen`/`StreakSavedScreen`/`XpUpScreen` to block system back/swipe
mid-sequence). `LootboxScreen`'s Continue button only renders once
`_phase == _LootboxPhase.revealed`, which only happens via
`_handleAnimationStatus` firing on `_animationController` completion — and
that in turn depends on `_handleCompositionLoaded` (the `Lottie.asset`
`onLoaded` callback for `kLootboxOpenAnimationAsset`) ever firing. If that
asset fails to decode (corrupt asset, stalled decode, a future
asset-pipeline regression), `_open()` sets `_phase = opening` /
`_openRequested = true`, but `_animationController.forward()` is never
called — `_phase` never reaches `revealed` and Continue never renders.

Before #082, a user stuck in that state could still escape via system
back/swipe. After #082's `PopScope(canPop: false)` with no fallback, they'd
be stuck on the screen with no way out short of killing the app.
`StreakSavedScreen`/`XpUpScreen` don't have this risk — their Continue
buttons render unconditionally regardless of animation state — so this is
specific to `LootboxScreen`'s tap-to-open/reveal flow.

This is an edge case (bundled local asset failing to decode, not a network
fetch), not something that fires in normal operation, so #082 shipped the
shared `PopScope` as-is rather than block on designing a recovery path.

## Goal

Decide whether this edge case is worth a fallback and, if so, add one —
e.g. a timeout after which a stalled `opening` phase is treated as failed
and either auto-advances to `revealed` (skipping the reveal content) or
re-enables `canPop` so the user isn't trapped.

## Out of scope

Changing the reveal animation/content itself, or #082's `PopScope` additions
to `StreakSavedScreen`/`XpUpScreen` (neither has this risk).

## Summary

Decided worth fixing: `_open()` now starts an `_openStallTimer`
(`LootboxScreen.openStallTimeout`, `@visibleForTesting`, default 5s) that
forces `_phase` to `revealed` if the real animation hasn't completed in
time, keeping Continue reachable. `_handleAnimationStatus` guards against
double-handling if the real animation finishes late after a forced reveal.
New `test/pet/lootbox_screen_test.dart` (4 tests) drives the stall path via
`openStallTimeout: Duration.zero`, since a real decode failure isn't
reproducible from a bundled, always-valid test asset. No UI changed
visually, so no screenshots.

## Code review

Reviewed via subagent (code-review skill, medium effort): no findings.
Double-handling guards, dispose()'s timer cancellation, and the
already-disposed-controller race (real `onLoaded` firing after a forced
reveal) were all specifically traced and confirmed safe — n/a, not fixed.

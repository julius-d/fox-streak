# Issue 053: Level-up celebration on the lesson result screen

Status: done | Priority: P2 | Type: feature | Refined-at: 2026-10-17 | Completed-at: 2026-10-17

## Goal

The lesson result screen (#005/#010/#011) already celebrates every completed
lesson — mascot, XP count-up, a level-progress bar, and a streak
headline/badge all render on every completion already. What's still missing
is a distinct "Level Up!" moment: today a level crossing during a lesson
just lands as the progress bar sitting a bit further along, with no
explicit call-out. This issue adds that moment: a "Level Up!" text callout
(mirroring the existing perfect-score bonus callout), an animated fill on
the level-progress bar instead of its current instant jump, a short
celebratory sound, and a confetti burst — shown only on lessons where the
player's level actually increased.

## Decisions (2026-10-17, with repo owner)

- **Scope confirmed**: #005/#010/#011 already cover the base celebration
  screen, XP count-up, level-progress bar, and streak headline/badge on
  every lesson completion — not reopened here. This issue adds only the
  missing "level increased" moment on top.
- **Detection**: `LessonController`/`LessonState` needs to additionally
  snapshot the XP total (or level) *before* the lesson's XP was applied,
  alongside the existing `xpTotalAfterLesson`, so the result screen can
  compute `XpService.levelForXp(before) != XpService.levelForXp(after)`.
  Multi-level jumps in a single lesson show one callout for the final level
  reached, not one per level crossed.
- **Visual**: a "Level Up! Level N" text callout, same placement/pattern as
  the existing `xpBonusCallout` (gold ink, bold, wrapped in
  `FoxCelebration`'s elastic scale-in) — no new mascot state, mascot
  continues to be driven by streak-milestone/score as today.
- **Level bar**: `FoxProgressBar`/`FoxLevelProgressBar` currently render
  instantly (`AlwaysStoppedAnimation`); add an animated fill (e.g.
  `TweenAnimationBuilder`/`AnimatedContainer`) so the bar visibly fills
  toward 100% then resets for the new level, only on the level-up path —
  non-level-up renders stay as the current instant/static fill (no
  behavior change for the common case).
- **Confetti**: add the `confetti` pub package (pure-Dart, no native plugin
  code — compatible with all 4 kept platforms) and trigger a short burst
  alongside the level-up callout. Confetti is **not** triggered by the
  streak-milestone path — scoped to level-up only.
- **Sound**: add the `audioplayers` package plus one bundled short chime
  asset (e.g. `assets/sfx/level_up.*`; exact asset sourcing/licensing TBD at
  implementation time) and play it on level-up. Gated by a new
  `foxSoundEnabledProvider` (mirrors the existing `foxHapticsEnabledProvider`
  — `NotifierProvider<..., bool>`, default **on**). Like haptics today, this
  provider has no settings UI yet — it's wired and mutable, just not
  surfaced to the user until #055 (follow-up, filed alongside this
  refinement) builds the toggle screen.
- **Coexistence with streak milestone**: when a lesson both levels up and
  hits a streak milestone, both moments render at once — level-up
  callout/bar-animation/confetti/sound near the XP section, streak
  headline/on-fire-mascot/badge near the streak section (different parts of
  the screen already; no suppression/priority needed).
- **Tests**: level-up sound/confetti must not break widget/integration
  tests run without real platform audio channels — follow the same pattern
  as `foxHapticsEnabledProvider`'s test override (e.g.
  `test/widgets/kit_test.dart`, `test/lesson/lesson_shell_test.dart`): sound
  playback goes through an overridable seam so tests can stub it out rather
  than hitting a real plugin channel.

## Acceptance criteria

- [ ] `LessonController`/`LessonState` tracks the XP total (or level)
      immediately before the lesson's result is applied, in addition to the
      existing `xpTotalAfterLesson`.
- [ ] `LessonResultScreen` shows a "Level Up! Level N" callout (new l10n
      string, DE + EN) only when the lesson's completion crossed at least
      one level boundary; absent otherwise (no change to current
      non-level-up rendering).
- [ ] `FoxLevelProgressBar`/`FoxProgressBar` animates its fill on the
      level-up path (visibly fills then resets for the new level);
      non-level-up renders remain the current static/instant fill.
- [ ] A confetti burst (via the new `confetti` dependency) plays alongside
      the level-up callout; not triggered on non-level-up lessons or by the
      streak-milestone path alone.
- [ ] A short chime (via the new `audioplayers` dependency + one bundled
      asset) plays on level-up, gated by a new `foxSoundEnabledProvider`
      (default on, same shape as `foxHapticsEnabledProvider`).
- [ ] When a lesson both levels up and hits a streak milestone, both the
      level-up treatment and the existing streak-milestone treatment
      (on-fire mascot, streak headline, badge) render together without
      suppressing each other.
- [ ] New widget/integration test(s): a lesson that crosses a level
      boundary shows the callout/animated bar/confetti; a lesson that
      doesn't cross a boundary shows none of them (regression guard,
      parallel to the existing `xp_level_result_test.dart`/
      `streak_result_test.dart` pattern).
- [ ] Sound playback is stubbed/overridden in tests (no real platform audio
      channel hit in `flutter test`/CI).
- [ ] Follows #015: new strings via `lib/l10n` arb params (DE + EN); no
      ad-hoc styling/colors outside the kit.
- [ ] `flutter analyze` / `dart format` / `dart fix --dry-run` /
      `flutter test` clean.

## Out of scope

- A settings screen exposing the new sound toggle (or the existing haptics
  toggle) to the user — both remain default-on, code-only toggles until
  #055 builds that UI.
- Per-question correct-answer sound — tracked separately in #054 (itself
  still a first draft); #053 only covers the level-up chime. The two issues
  will likely share the new `audioplayers` dependency once both land.
- Mascot state changes on level-up — mascot stays driven by
  streak-milestone/score as today.
- Lottie/animated mascot art — out of scope per #015/#032.

## Dependencies

- Builds on #005/#010/#011 (done — base celebration screen, XP count-up,
  level-progress bar, streak headline/badge).
- Adds two new runtime dependencies: `confetti`, `audioplayers` (+ one
  bundled chime asset).
- Needs a follow-up issue (filed as #055) for the settings screen that will
  eventually expose both the haptics and sound toggles to the user.
- Related to #054 (per-question correct-answer sound, not yet refined) —
  likely shares the new `audioplayers` dependency.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

`LessonState`/`LessonController` snapshot `xpTotalBeforeLesson` alongside
`xpTotalAfterLesson` (via `XpApplication.xpTotalBefore`, sourced from
`StatsRepository.addXp`'s now-record return `(xpTotalBefore, xpTotal)` —
one profile query, not two); `LessonResultScreen` computes
`leveledUp` by comparing `XpService.levelForXp` on both. On that path it
shows a gold `levelUpCallout` ("Level Up! Level N", new DE/EN arb
string), passes `FoxLevelProgressBar` a `levelUpAnimateFrom` (the
pre-lesson progress) so it plays a fill-to-100%-then-reset
`TweenSequence` animation instead of its usual instant fill, and mounts
a `_LevelUpEffects` widget that plays a `confetti` burst and (via the
new overridable `foxSoundPlayerProvider`/`foxSoundEnabledProvider` seam,
default on) a bundled placeholder chime (`assets/sfx/level_up.mp3`,
synthesized with `ffmpeg` — real asset sourcing still TBD). Non-level-up
renders are unchanged. New deps: `confetti`, `audioplayers`.
Screenshot: `issue053-level-up-result.png`.

Found and filed separately (not fixed here): #056 — the pre-existing
`xp_level_result_test.dart` integration test fails deterministically on
a real device run (unrelated to this issue's changes); root-caused to a
tap-selection ambiguity in a 2-item fixture. My own new
`level_up_result_test.dart` avoids the same trap by selecting the shown
question via its prompt rather than scanning for any known answer text.

## Code review

Reviewed by a code-review subagent (medium effort); both findings fixed.
- `applyLessonResult` issued two `getProfile()` queries (one for `xpTotalBefore`, one inside `addXp`) where one would do.
  Fixed: `StatsRepository.addXp` now returns `(xpTotalBefore, xpTotal)` from its single existing query; `applyLessonResult` no longer queries separately.
- `_LevelUpEffectsState` unconditionally allocated a `ConfettiController` (and its ticker) in `initState` even on the common non-level-up path.
  Fixed: the controller is now only constructed when `widget.active`; `_confettiController` is nullable and the build/dispose paths guard accordingly.

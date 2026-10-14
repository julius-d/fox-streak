# Issue 012: Home dashboard, feedback, teen UX

Status: done | Priority: P1 | Type: UX | Refined-at: 2026-10-13 | Implemented-at: 2026-10-13

## Goal
Duolingo-home feel: what to do next in 5 seconds.

## Decisions (2026-10-13, with repo owner)
- Home vs Library: `HomeScreen` becomes `main.dart`'s new `home:` (replacing today's direct `LibraryScreen` wiring). Home shows the header widgets (greeting, streak badge, XP/level bar, daily-goal ring, Continue button) plus a "Browse sets" button that navigates to the existing, unchanged `LibraryScreen`. Home itself does **not** embed the full set list — that stays Library's job (#003/#004 untouched).
- Daily-goal ring: new `FoxGoalRing` widget, added to the #015 widget kit (circular, token-driven, a11y-labelled, following #015's existing conventions even though #015 itself is closed) — visually distinct from #010's linear XP bar, since both now sit on the same screen.
- Daily XP tracking (new gap found while designing the ring): there is currently no "XP earned today" value anywhere — `profile_stats` only has lifetime `xp_total`, and `attempts` rows carry no XP amount, so today's XP can't be reconstructed from existing data. Adds `profile_stats.today_xp` via a schema migration (schemaVersion 2→3, same pattern #026 already used), reset to the lesson's own XP when the day has rolled over (compare against `last_active_day`) and accumulated otherwise. **This column is written by #010's `XpService`, at the same call site as `xp_total`/the done-guard** — flagged here as a required small extension to #010's scope, not code #012 writes itself. #012 only reads `today_xp` for the ring fill.
- Sound: AC corrected to haptics-only. "Green/red + sound/haptic" overstated current scope — no audio package exists, and #015's own `FoxFeedback` hook comment already says sound is a future wire-up. #012 reuses the existing haptics hook (`foxHapticsEnabledProvider`/`FoxFeedback`) and color feedback already built in #005–#009; real sound effects become a separate future issue.
- Greeting / display name: no app-level user identity exists (`createdBy` is per-set, not a profile field). Adds `profile_stats.display_name TEXT NULL` (same migration as `today_xp`) — optional, captured during first-run onboarding (skippable), editable later by tapping the greeting on Home (simple rename dialog). Falls back to a generic time-of-day greeting ("Good morning!"/"Good evening!") when null/empty.
- Onboarding "shown once" gate: adds `profile_stats.has_onboarded INTEGER (bool) DEFAULT 0` (same migration) rather than inferring first-launch from `last_active_day == null` — that heuristic breaks if someone browses the library without ever completing a lesson. Set once, when onboarding completes or is skipped.
- Continue button (last set): no new column — derived from the most recent `attempts` row (`attempts.at` desc, limit 1) joined to its `items.setId`. If there are no attempts yet (fresh install, no lesson ever played), the Continue button is replaced by a CTA pointing at "Browse sets" / the existing library empty-state flow — no dead button.

## Acceptance criteria
- [x] `HomeScreen` is the new `main.dart` landing screen: greeting (generic by default, or `display_name` when set) + #011 `StreakBadge` + #010 level-progress widget + `FoxGoalRing` (daily goal fill, `today_xp` / `dailyGoalXp`) + Continue button (derived from the latest `attempts` row's set; replaced by a "Browse sets" CTA when no attempts exist) + "Browse sets" button → unchanged `LibraryScreen`
- [x] Instant feedback is color (green/red, already built #005–#009) + haptic only (existing `FoxFeedback` hook); no new audio dependency; encouraging copy, no shaming
- [ ] Dark mode + large fonts work (reuses #015 theme); all strings via `lib/l10n` arb params (DE + EN), none hardcoded — strings/tokens done; manual device verification deferred (see Summary)
- [x] Parental note: local-only, no chat, no ads — static info screen, reachable from Home
- [x] `today_xp` resets correctly on a day change and accumulates correctly across same-day lessons (formula/tests owned by #010; #012 only consumes it read-only for the ring)
- [x] `display_name` is fully optional: onboarding capture is skippable, Home falls back to the generic greeting when null/empty, editable later via tap-to-rename on the greeting
- [x] First-run onboarding: max 3 slides + optional name capture, skippable, shown exactly once per install (gated on `has_onboarded`, not inferred from lesson activity)
- [ ] Manual a11y pass: contrast, min 48dp targets, screen-reader labels on every new Home widget (`FoxGoalRing`, Continue button, greeting, onboarding slides) — code-level floor done (semantics labels/values, 48dp via kit buttons); manual VoiceOver/device pass deferred (see Summary)

## Tasks
1. Schema migration v3→v4: `profile_stats.display_name TEXT NULL`, `has_onboarded INTEGER DEFAULT 0` (mirrors #026's migration pattern). `today_xp` is **already live** — #010 shipped it as v2→v3 (schemaVersion is 3, not 2, as of #010), so this migration only needs the two remaining columns.
2. ~~Flag for #010: extend `XpService`/`StatsRepository.addXp` call site to also maintain `today_xp`~~ — done, shipped by #010 (`StatsRepository.addXp` resets/accumulates `today_xp` against `lastActiveDay`).
3. `FoxGoalRing` widget (new #015-kit widget: circular, token-driven, a11y label)
4. `StatsRepository`: `setDisplayName(String? name)`, `setOnboarded()`, `getLastPracticedSetId()` (derived query over `attempts` ⋈ `items`, no new column)
5. `HomeScreen`: composes greeting + `StreakBadge` (#011) + level-progress widget (#010) + `FoxGoalRing` + Continue button + "Browse sets" button; wired as `main.dart`'s new `home:`
6. First-run onboarding flow (max 3 slides, optional name capture, skippable), gated on `has_onboarded`
7. Parental info static screen, reachable from Home
8. Copy deck (short, positive) in DE + EN; l10n arb keys for greeting, onboarding slides, parental note, goal-ring label
9. Manual a11y pass: contrast, 48dp targets, screen reader across all new widgets
10. Stable keys for #016: e.g. `homeContinueButton`, `homeBrowseSetsButton`, `goalRing`
11. Tests: `StatsRepository` tests for `setDisplayName`/`setOnboarded`/`getLastPracticedSetId` (incl. no-attempts-yet case), `HomeScreen` widget test (header renders, Continue button shown/hidden logic, nav to Library), onboarding shows-once test

## Out of scope
- Shop, avatars, leagues (post-MVP)
- Real audio/sound effects — haptics-only for v1; a future issue if wanted
- Dedicated settings screen — name editing happens via tap-to-rename on Home's greeting, not a new screen
- Library screen redesign — unchanged, stays owned by #003/#004
- `today_xp` write logic itself — tracked here as a dependency, implemented in #010

## Dependencies
- Builds on #002/#026 (migration pattern), #010 (level-progress widget; needs the small `today_xp` extension flagged above), #011 (`StreakBadge`), #015 (widget kit; `FoxGoalRing` added under its conventions)
- Changes `main.dart`'s `home:` route — coordinate with anything else touching app bootstrap

## Verify
```powershell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

## Summary (implemented 2026-10-13)
- Schema v3→v4: `profile_stats.display_name TEXT NULL` + `has_onboarded INTEGER DEFAULT 0` (mirrors #026/#010's `addColumn` pattern); migration test in `test/data/migration_test.dart`.
- `StatsRepository`: `setDisplayName`/`setOnboarded`/`getLastPracticedSetId` (drift join over `attempts` ⋈ `items`, latest `at` wins); new `lib/src/stats/stats_providers.dart` (`profileProvider` stream, `lastPracticedSetIdProvider` — a `FutureProvider.autoDispose`, not a stream, since there's no cheap single-row watch over the derived join; `HomeScreen` invalidates it after returning from a lesson/library trip).
- New kit widget `FoxGoalRing` (circular, gold fill, token-driven, a11y label/value) in `lib/src/widgets/fox_goal_ring.dart`.
- `lib/src/home/`: `HomeScreen` (greeting/tap-to-rename, `StreakBadge`, `FoxLevelProgressBar`, `FoxGoalRing`, Continue/Browse-sets), `OnboardingScreen` (3 slides incl. optional name capture, skippable), `ParentalInfoScreen` (static copy). Wired as `main.dart`'s new `home:`.
- Continue slot (key `homeContinueButton`) always renders; label/action switch between "Continue practicing" → `LessonScreen` and "Browse sets" → `LibraryScreen` depending on whether a prior attempt exists — per the issue's literal "no dead button" wording, this is in addition to (not instead of) the separate always-visible `homeBrowseSetsButton`.
- 24 new l10n keys (DE+EN) added to both the arb files and the hand-written `app_localizations.dart` mirror (no `l10n.yaml`/codegen in this repo).
- Tests: extended `stats_repository_test.dart`/`migration_test.dart`/`kit_test.dart`, new `test/home/home_screen_test.dart` (9 cases: onboarding gating/skip/name-capture, greeting fallback/rename, Continue↔Browse-sets duality, header widgets with real profile values, parental info navigation), updated `test/widget_test.dart` for the new boot screen. Full suite: 275 `flutter test` green; `flutter analyze`/`dart format`/`dart fix --dry-run` clean.
- New `integration_test/home_screen_test.dart` (2 scenarios, run against a real macOS app build): fresh-install onboarding→Home→Library, and prior-attempt→Continue→real lesson→result→back-to-Home with updated XP/streak. Found + fixed during this run: the result screen's `backToLibraryButton` sits below the fold in the 800×600 macOS test window (it's a `SingleChildScrollView`) — needed `tester.ensureVisible()` before tapping.
- Deferred (code-level done, device/manual step not run, same posture as #015/#001's device-blocker precedent): dark-mode/large-font/VoiceOver manual pass. All new copy is token/l10n-driven and every new widget carries `Semantics` label/value, so it should hold, but hasn't been eyeballed on-device.

## Code review (2026-10-13, `/code-review high`)
- `OnboardingScreen._finish()` had no error handling: if persisting the name/onboarded flag threw, Skip/Next stayed disabled forever, trapping the user on onboarding.
  Fixed: wrapped in try/catch, resets `_finishing` on failure so the user can retry.
- Home's Continue slot rendered nothing (`SizedBox.shrink()`) on loading *or* error from `lastPracticedSetIdProvider`, hiding the primary CTA on a query failure.
- Fixed: both states now fall back to the safe "Browse sets" label/action via `AsyncValue.asData?.value`, same as the "no attempts yet" case — never a blank slot.
- `LessonResultScreen`'s "Back to library" button just pops the navigator, so reached via Home's new direct Continue→Lesson push it lands back on Home, not the library — label is misleading on that path.
  Not fixed here: pre-existing `pop()` design shared by multiple callers (`SetDetailScreen`, `HomeScreen`); needs a real decision (caller-aware label vs. pop-to-root), not a one-line patch. Filed as #034.
- `profileProvider`'s error branch shows a raw `e.toString()` to the user.
  Not fixed: identical to the pre-existing pattern in `library_screen.dart`; not a regression introduced by this issue.
- `OnboardingScreen`'s doc comment said Skip discards the typed name as null/blank; actual (reasonable) behavior persists whatever is currently typed regardless of Skip vs. Get-started.
  Fixed: corrected the doc comment to match the real contract.
- `_EditNameDialog` is a hand-rolled `AlertDialog` rather than a widget-kit component, with no design-reason comment per AGENTS.md's "ad-hoc styling needs a reason" rule.
  Fixed: added a doc comment explaining why (no kit-level text-input dialog exists; same shape as `ItemEditorDialog`'s own hand-rolled dialog).
- `ParentalInfoScreen` and the app-bar `parentalInfoButton` navigation had zero test coverage.
  Fixed: added a `home_screen_test.dart` case asserting the button opens the screen.
- `getLastPracticedSetId`'s doc claims deleting a set/item never leaves stale data, but nothing tested that specific cascade-then-fallback path.
  Fixed: added a `stats_repository_test.dart` case deleting the most-recently-practiced set and asserting the fallback to the next one, then to `null`.
- `_greeting()`'s morning/afternoon/evening branches repeat the same `hasName` ternary three times.
  Not fixed: a nit with no functional risk; three similar branches read more clearly here than a lookup-table indirection would (per this repo's own no-premature-abstraction guidance).

# Issue 012: Home dashboard, feedback, teen UX

Status: open | Priority: P1 | Type: UX | Refined-at: 2026-10-13

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
- [ ] `HomeScreen` is the new `main.dart` landing screen: greeting (generic by default, or `display_name` when set) + #011 `StreakBadge` + #010 level-progress widget + `FoxGoalRing` (daily goal fill, `today_xp` / `dailyGoalXp`) + Continue button (derived from the latest `attempts` row's set; replaced by a "Browse sets" CTA when no attempts exist) + "Browse sets" button → unchanged `LibraryScreen`
- [ ] Instant feedback is color (green/red, already built #005–#009) + haptic only (existing `FoxFeedback` hook); no new audio dependency; encouraging copy, no shaming
- [ ] Dark mode + large fonts work (reuses #015 theme); all strings via `lib/l10n` arb params (DE + EN), none hardcoded
- [ ] Parental note: local-only, no chat, no ads — static info screen, reachable from Home
- [ ] `today_xp` resets correctly on a day change and accumulates correctly across same-day lessons (formula/tests owned by #010; #012 only consumes it read-only for the ring)
- [ ] `display_name` is fully optional: onboarding capture is skippable, Home falls back to the generic greeting when null/empty, editable later via tap-to-rename on the greeting
- [ ] First-run onboarding: max 3 slides + optional name capture, skippable, shown exactly once per install (gated on `has_onboarded`, not inferred from lesson activity)
- [ ] Manual a11y pass: contrast, min 48dp targets, screen-reader labels on every new Home widget (`FoxGoalRing`, Continue button, greeting, onboarding slides)

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

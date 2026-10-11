# Issue 015: FoxStreak design language + shared widget kit

Status: done | Priority: P0 | Type: UX

## Goal
One canonical design language — tokens + Material 3 theme + reusable widget kit — that makes the app look consistent, playful, and fun, Duolingo-style. All UI work adheres to it; evolves the current M3 orange theme instead of restyling per screen.

## Decisions (2026-10-11, with repo owner)
- Scope: **full design system** (tokens + `ThemeData` + component kit), not a conventions doc.
- Adherence: **all future UI work** — #004 editors, #005 lesson shell, #006–#009 exercises, #010/#011 XP + streak widgets, #012 home/onboarding, #013 QA surfaces, #014 images/animations must fit the language.
- Enforcement in code + repo rules: central `FoxStreakTheme` + widget kit that feature issues must reuse (no ad-hoc styling), **plus an AGENTS.md guideline section** so every future change follows it. No review-checklist or automated golden tests in this issue.
- Brand: keep Material 3, orange seed color, fox mascot (states `empty | lit | on-fire` per #011 stay canonical), teen audience, DE + EN, min 48dp targets, dark mode + large fonts (per #012). Style north star is **Duolingo: chunky rounded shapes, bright friendly colors, mascot-forward moments, celebratory feedback** — playful and fun, never corporate or dry. Material 3 governs standard components; the chunky 3D press-feel lives only in the custom kit buttons, never as one-off screen styling.
- Review (2026-10-11): resolved F1–F6 — M3 + custom button kit, system font for MVP, semantic tokens, full-`library/` retrofit, kit-vs-screen a11y split with #012, tests + manual before/after instead of "no visual regression".

## Acceptance criteria
- [ ] `lib/src/theme/fox_streak_theme.dart`: `FoxStreakTheme.light()` / `.dark()` built from `ColorScheme.fromSeed(seedColor: orange)`; typography scale, spacing/radius tokens as constants; wired as `MaterialApp(theme:, darkTheme:)` in `main.dart`.
- [ ] Semantic color tokens with light + dark values, contrast-checked: success green, error red, XP gold, streak flame, info blue — derived from the orange seed where possible; kit widgets reference tokens, never raw colors.
- [ ] Typography: system font only for MVP (no bundled font asset); locked weight/scale roles for headings, buttons, body; a rounded display font is a post-MVP follow-up, not this issue.
- [ ] Widget kit (`lib/src/widgets/`): chunky rounded playful buttons — Duolingo-style primary/secondary/`CheckButton` (min 48dp, bold labels, hard-shadow/offset press feel where cheap to build; long DE labels must wrap/ellipsize, never clip); bright token-driven `FeedbackBanner`; friendly generic `ProgressBar` (#010 composes the level-progress widget on top of it); confirm-dialog + empty-state-CTA patterns (generalize what #003 built in `LibraryScreen._confirmDeleteSet`); #004+ must reuse these, not reimplement.
- [ ] Fox spec: placeholder asset + placement/state rules (`empty | lit | on-fire`, where the fox may appear); the fox plays the Duolingo-owl role — empty states, result celebrations, streak moments — not decoration sprinkled at random; final art stays out of this issue.
- [ ] Motion/feedback language: instant bright green/red + haptic/sound toggle (default on, mutable, per #005/#012), bouncy celebratory micro-moments (XP pop, streak-flame lit, result cheer), encouraging copy, no shaming; animation budget must leave room for later #014 lottie (no lottie dep here).
- [ ] A11y floor: contrast, min 48dp targets, screen-reader labels, large-font + dark-mode smoke check; strings via the existing `lib/l10n` arb pattern (DE + EN).
- [ ] AGENTS.md gains a Design-guideline section: token/theme location, "reuse the kit, no ad-hoc styling", pointer that each UI issue carries a "follows #015" acceptance line.
- [ ] Retrofit: everything already in `lib/src/library/` — library/detail/editor screens **and** `item_editor.dart` (#004), type icons, share actions — migrated onto theme + kit; widget tests green plus manual before/after screenshots on one screen size (no goldens in this issue).
- [ ] `flutter analyze` + `dart format` clean; no new third-party deps unless iOS + Windows compatible (3-platform rule).

## Tasks
1. Audit current UI (`main.dart` theme, `lib/src/library/`) → token inventory (colors, type, spacing, radius, button/dialog patterns).
2. Implement theme + widget kit; wire into `MaterialApp` (light + dark).
3. Fox placeholder + states/placement doc.
4. Retrofit library screens onto the kit; cover with widget tests (theme active, keys stable for #016 hooks).
5. Write the AGENTS.md guideline section.
6. Manual QA: dark mode, large font, rotation — deferred, blocked on toolchains (same blocker as #001/#013/#016).

## Out of scope
- Full copy deck + onboarding slides (#012 consumes this language, doesn't define it). A11y split: this issue owns kit-level palette contrast + 48dp targets; #012 owns the screen-level pass (per-screen dark-mode / large-font verification, screen-reader flow, copy, onboarding).
- Per-UI-issue adherence checkboxes: added to #004–#014 at implementation time, pointing back here.
- Lesson/gameplay logic (#005–#009), XP formula (#010) / streak logic (#011), image columns + lottie (#014), seed content (#013), e2e harness (#016 — but kit widgets should carry the stable keys #016 needs).

## Dependencies
- Builds on #003 (library UI + l10n scaffold) and #011 (mascot states). Should land **before** #004–#009 UI implementation to avoid retrofit churn (#003 retrofit is the accepted exception).
- Device QA blocked: no Android SDK, no VS C++ workload, no Chrome (see #001). When unblocked, #013 device QA (rotation, dark mode, large font) runs against the #015 theme.

## Summary (done 2026-10-11)
- Theme: `lib/src/theme/fox_streak_theme.dart` — `FoxStreakTheme.light()` / `.dark()` (`ColorScheme.fromSeed`, orange seed), `FoxSemanticColors` ThemeExtension (success/error/info/flame/gold+goldInk, light + dark, all 19 pairs WCAG-AA checked 5.0–11.4:1), `FoxSpacing` / `FoxRadius` / `FoxButtonMetrics`, bold heading/button type roles, M3-default font (no bundled asset). Wired as `MaterialApp(theme:, darkTheme:, themeMode: system)` in `main.dart`.
- Kit: `lib/src/widgets/` barrel — `FoxPrimaryButton` / `FoxSecondaryButton` / `FoxCheckButton` (48dp, bold wrap-max-3-lines labels, 4dp hard-shadow press feel), `FoxFeedbackBanner` (success/error/info/xp), `FoxProgressBar` (#010 composes on top), `FoxConfirmDialog.show` (generalizes #003 delete confirms), `FoxEmptyState` (mascot + CTA + loading/error slots), `FoxMascot` (`empty | lit | on-fire` vector placeholder, final art out of scope — no binary asset, no new deps, 3-platform rule holds), `FoxCelebration` + `FoxFeedback` haptics behind `foxHapticsEnabledProvider` (NotifierProvider, default on; #005/#012 own settings UI, sound hook reserved, no lottie dep).
- Retrofit: all of `lib/src/library/` on the kit (confirms, empty states, save buttons w/ loading, error banners, token-tinted type icons via new `colorForItemType`); all keys stable (`tryDemoSetButton`, `saveSetButton`, `confirmDeleteSetButton`, …). One harness change: `test/library/library_screen_test.dart` `pumpLibrary` now pumps `FoxStreakTheme.light()` (kit requires the extension — production always has it via `main.dart`). No arb changes: kit takes all copy via params.
- AGENTS.md has the Design-language section (token location, "reuse the kit, no ad-hoc styling", fox placement, "follows #015" pointer for #004–#014).
- Verify: `flutter analyze` clean, `dart fix` clean, `dart format` clean, `flutter test` 95/95 (71 pre-existing + 24 new: `test/theme/`, `test/widgets/`). Manual dark-mode / large-font / rotation pass deferred (device blockers per #001).
- Follow-ups for other issues: #004–#014 each need a "follows #015" acceptance line at implementation time; #012 owns per-screen a11y + copy deck; #014 owns lottie + final fox art.

## Verify
```powershell
flutter analyze        # must be clean
flutter test           # must be green (incl. theme/kit widget tests)
dart format .          # must be clean
# Manual dark-mode / large-font / rotation pass — deferred until a device build exists
```

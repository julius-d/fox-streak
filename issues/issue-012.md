# Issue 012: Home dashboard, feedback, teen UX

Status: open | Priority: P1 | Type: UX

## Goal
Duolingo-home feel: what to do next in 5 seconds.

## Acceptance criteria
- [ ] Home: greeting, streak badge, XP/level bar, daily-goal ring, Continue button (last set), set list
- [ ] Instant feedback everywhere (green/red + sound/haptic), encouraging copy, no shaming
- [ ] Dark mode + large fonts work; German/English strings via `flutter_localizations`
- [ ] Parental note: local-only, no chat, no ads — static info screen

## Tasks
1. `HomeScreen` composition from #010/#011 widgets
2. Copy deck (short, positive) in DE + EN
3. Empty/first-run onboarding (3 slides max)
4. Manual a11y pass: contrast, min 48dp targets, screen reader

## Out of scope
Shop, avatars, leagues — post-MVP.

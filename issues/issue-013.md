# Issue 013: Seed content + Android build QA

Status: open | Priority: P1 | Type: release

## Goal
App is fun on first install; APK builds cleanly.

## Acceptance criteria
- [ ] 3 demo sets preinstalled: 20x DE<->EN vocab (school basics), 5x phone (fictional numbers only!), 5x birthdays (fictional persons)
- [ ] First-run "Play demo" starts lesson in <2 taps
- [ ] `flutter build apk --release` + `appbundle` succeed; tested on 2 screen sizes
- [ ] `flutter test` green, manual QA checklist signed in this file

## Tasks
1. `assets/seed/*.json` + importer on first launch
2. Use clearly fake but validator-valid numbers (digit-only reserved range, e.g. `015100000001`…) to avoid real dialing and pass #002 `^[0-9]{3,15}$` import validation
3. QA: install, airplane-mode (must work offline), rotation, dark mode, large font
4. Version app `0.1.0+1`, changelog started

## Next after MVP
iOS TestFlight, Supabase/Firebase cloud option, leagues/badges, TTS/audio questions.

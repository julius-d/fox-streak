# Issue 013: Seed content + Android release build QA

Status: open | Priority: P1 | Type: release | Refined-at: 2026-10-13 | Reviewed-at: 2026-10-13

## Goal
App is fun on first install; release APK/appbundle build cleanly.

## Decisions (2026-10-13, with repo owner)
- **Seed content, loosened:** dropped the original exact-count AC ("20x vocab, 5x phone, 5x birthdays" as 3 single-type sets). The bundled seed sets already shipped by #002 (`demo_family`, `demo_animals`, mixed-type) plus the one #022 is adding (`demo_bundeslaender`, vocab/choice-only) together cover all 3 item types with fictional-only data — that's sufficient. No new seed files are required by this issue.
- **Fictional phone numbers, kept as-is:** the shipped convention (a real-looking German mobile prefix, e.g. `0171`/`0151`, followed by sequential filler digits, e.g. `01711234567`) stays. Germany has no official reserved fictional-mobile range (unlike UK's `07700 900000` or US's `555`), so there's nothing more "correct" to switch to — just document it explicitly in `assets/seed/README.md` as this project's own convention, not a standard.
- **Demo entry point depends on #012:** "reach a demo lesson in ≤2 taps" is satisfied by #012's Home screen (Continue button when a last-practiced set exists, or the "Browse sets" → #003's existing "Try demo set" CTA fallback when it doesn't) — #013 doesn't implement that entry point itself, it verifies the tap count once #012 lands.
- **No hard dependency on #022:** #022 is about to change the seed JSON shape (`direction` → `promptLang`/`answerLang`) and add `demo_bundeslaender`. That churn is independent and low-risk enough that #013's QA pass can run against whatever seed sets exist at QA time — not blocked on #022 landing first.
- **Release build stays in scope (reaffirmed):** #015, #018, and #020 all already point to #013 as the owner of the actual release APK/appbundle build + signing (#018: "debug-compile only — does not satisfy the #013 release/appbundle gate"). CI (#018, done) currently only runs `flutter build apk --debug` as a smoke check; this issue extends CI with real `--release` + `appbundle` build steps, since dev machines (per AGENTS.md) lack the Android SDK locally and CI is the build gate.
- **Version, corrected:** `pubspec.yaml` is already at `1.0.0+1` (the original draft's "bump to `0.1.0+1`" was stale/wrong — no re-bump needed). This issue starts a `CHANGELOG.md` instead.

## Acceptance criteria
- [ ] Bundled seed sets (`demo_family`, `demo_animals`, and `demo_bundeslaender` once #022 lands) together cover all 3 item types (choice/vocab, phone, date) with fictional-only data; no exact per-type count required.
- [ ] From a fresh install, reaching a playable demo lesson takes ≤2 taps via #012's Home screen; verified once #012 lands (file a follow-up here if it doesn't hold).
- [ ] CI builds `flutter build apk --release` and `flutter build appbundle` successfully (extends #018's existing debug-only smoke step); installed/tested manually on 2 differently-sized Android targets (emulator or device) once available.
- [ ] `flutter test` green; manual QA checklist (below) signed off in this file.
- [ ] App version confirmed (`pubspec.yaml` `1.0.0+1`, no re-bump needed); `CHANGELOG.md` started.

## Tasks
1. Confirm the bundled seed sets collectively cover all 3 item types with fictional-only data; update `assets/seed/README.md` to document the phone-number filler convention explicitly as "ours, not an official standard."
2. Once #012 lands, verify its Home CTA reaches a lesson in ≤2 taps from a fresh install; file a follow-up issue if it doesn't.
3. Extend CI (`.github/workflows/*.yml`) with `flutter build apk --release` + `flutter build appbundle` steps alongside the existing debug smoke build.
4. Manual QA pass: install, airplane-mode (must work offline), rotation, dark mode, large font — record results in the checklist below.
5. Confirm app version (`pubspec.yaml` `1.0.0+1`); start `CHANGELOG.md`.

## Manual QA checklist (sign off when run)
- [ ] Fresh install, no prior data: demo flow reachable in ≤2 taps from launch (per #012 Home CTA)
- [ ] Airplane mode / offline: full seed import + lesson flow works end-to-end
- [ ] Device rotation (portrait ↔ landscape) during a lesson: no crash/data loss
- [ ] Dark mode: seed/demo screens render correctly (#015 theme)
- [ ] Large system font size: text wraps, no clipping, 48dp targets hold
- Signed: ______  Date: ______

## Out of scope
- Exact per-type seed counts (e.g. "20x vocab") — dropped; "covers all 3 types" is sufficient.
- Implementing the Home screen / demo entry point itself — owned by #012.
- iOS TestFlight, Supabase/Firebase cloud sync, leagues/badges, TTS/audio questions — post-MVP (see below).

## Dependencies
- Builds on #002 (seed infra, done), #018 (CI, done — this issue extends its build step).
- Needs #012 (Home screen Continue/demo CTA) landed to verify the ≤2-tap AC. Not blocked on #022 (seed format churn is independent).

## Next after MVP
iOS TestFlight, Supabase/Firebase cloud option, leagues/badges, TTS/audio questions.

## Verify
```powershell
flutter test                      # must be green
flutter build apk --release       # must succeed (CI gate; local needs Android SDK)
flutter build appbundle           # must succeed (CI gate; local needs Android SDK)
# Manual: install release build on 2 differently-sized Android targets; run the QA checklist above
```

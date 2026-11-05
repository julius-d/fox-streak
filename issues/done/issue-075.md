# Issue 075: `streak_result_test.dart` asserts a key no widget ever produces

Status: done | Priority: P3 | Type: bug | Refined-at: 2026-11-05 | Completed-at: 2026-11-05

## Goal

`integration_test/streak_result_test.dart`'s milestone test asserted
`find.byKey(const Key('foxMascot-onFire'))` (later `foxPet-onFire` post-#068's
rename, same bug) — but `FoxMascot`/`FoxPet`'s key is always
`foxPet-${pet.id}` where `pet.id` is a catalog ID like
`emoji_u1f98a_lottie`, never the literal string `onFire`. This key never
matched anything since #059 retired the old `FoxMascotState`
`empty | lit | on-fire` painter (whose states included a literal `onFire`)
in favor of collectible pets — the assertion was apparently never updated
at that point. Fix the assertion to check for the actual rendered pet key
and get the test passing again.

## Summary

Already fixed, no code change needed — duplicate of #081 (done). This
issue was filed 2026-10-26 15:46; the same day at 23:11, while
implementing #078 (lesson-completion screen split), the identical stale
`foxPet-onFire` assertion was independently found in the same test file
and removed (commit `aae5fe5`, filed at the time as a follow-up, later
renumbered to #081 — see `issues/done/issue-081.md`'s "Context" section).
#081 then gave streak milestones a real pet visual and rewrote the
assertion to check the actual rendered key
(`find.byKey(Key('foxPet-$kDefaultPetId'))`), which is what
`integration_test/streak_result_test.dart` asserts today. Confirmed by
running `flutter test integration_test/streak_result_test.dart`: passes.

No further action needed on this issue.

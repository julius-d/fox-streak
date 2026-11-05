# Issue 075: `streak_result_test.dart` asserts a key no widget ever produces

Found while implementing #068 (mascot -> pet rename).

`integration_test/streak_result_test.dart`'s milestone test asserts
`find.byKey(const Key('foxMascot-onFire'))` (now `foxPet-onFire` post-#068's
rename, same bug) — but `FoxMascot`/`FoxPet`'s key is always
`foxPet-${pet.id}` where `pet.id` is a catalog ID like
`emoji_u1f98a_lottie`, never the literal string `onFire`. This key has
never matched anything since #059 retired the old `FoxMascotState`
`empty | lit | on-fire` painter (whose states included a literal
`onFire`) in favor of collectible pets — the assertion was apparently
never updated at that point. Confirmed failing the same way on `main`
(unrelated to #068).

Fix the assertion to check for the actual rendered pet key (or whatever
visual the milestone result screen is supposed to show) and get the test
passing again.

# Issue 076: `xp_level_result_test.dart` can't find the "+25 XP" count-up text

Found while implementing #068 (mascot -> pet rename), unrelated to it —
this file was untouched by #068's changes and fails identically on `main`.

`integration_test/xp_level_result_test.dart`'s perfect-score test expects
`find.text('+25 XP')` after the result screen settles, but on a macOS
desktop integration run it finds 0 matching widgets. Likely a timing issue
with `_XpCountUp`'s `TweenAnimationBuilder` (the count-up animation) not
having reached/settled on its final text by the time the assertion runs,
rather than a real product bug — needs investigation to confirm and then
either a longer `pumpAndSettle`/explicit wait or a fix to whatever's
actually wrong.

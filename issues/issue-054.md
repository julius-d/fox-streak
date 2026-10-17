# Issue 054: Correct-answer congratulation sound

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-10-17

## Goal

Play a short, cheerful sound every time the player answers a question
correctly, alongside the existing haptic tick (`FoxFeedback.success`,
`lesson_screen.dart:307`). Today only a light haptic buzz fires on a correct
answer — no sound. This issue adds the "sound hook" `feedback_effects.dart`
has reserved since #015 (`// Sound hook: no audio dep in this issue (budget
reserved for #014)`).

## Decisions (2026-10-17, with repo owner)

- **Scope: correct answers only.** No wrong-answer sound in this issue — the
  title and intent are specifically a congratulation sound. A distinct
  wrong-answer sound can be a quick follow-up once the audio plumbing exists.
- **Shares plumbing with #053, doesn't duplicate it.** #053 (level-up
  celebration, refined the same day) already decided to add the
  `audioplayers` package and a new `foxSoundEnabledProvider` toggle
  (`NotifierProvider<..., bool>`, default on, same shape as
  `foxHapticsEnabledProvider`), with a test-stub seam so `flutter test`/CI
  never hits a real platform audio channel. #054 reuses that same dependency,
  provider, and test seam rather than adding its own. **Whichever of #053 /
  #054 is implemented first adds the shared plumbing; the other one reuses
  it** — note this in whichever PR lands second.
- **Wiring point**: `LessonScreen._submitAndBuzz` (`lesson_screen.dart:298`),
  the `correct` branch that already calls `FoxFeedback.success(context,
  ref)`. Add the sound call there (or inside `FoxFeedback.success` itself,
  consistent with how haptics are centralized) — fires once per graded
  question, not per keypress (the dial pad's existing per-keystroke haptic in
  `dial_pad_exercise.dart` is untouched and unrelated).
- **Asset**: one short (≲1s), small (≲50KB) bundled sound file, e.g.
  `assets/sfx/correct_answer.*`. Exact file sourcing is an implementation
  detail, but it must be CC0 or otherwise clearly royalty-free for commercial
  use, with its source + license documented (e.g. a short note in
  `assets/sfx/README.md`, mirroring how #013 documents the fictional
  phone-number convention). Good candidate sources confirmed during
  refinement:
  - [Kenney "Interface Sounds"](https://kenney.nl/assets/interface-sounds) —
    100 CC0 (public domain) UI sound effects, no attribution required, built
    for exactly this kind of short confirmation sound.
  - [Pixabay sound effects](https://pixabay.com/sound-effects/) — large
    library of royalty-free chimes/dings (search "correct answer" or "success
    chime"); check Pixabay's content license terms on the chosen file's page
    before bundling.
- **Toggle**: gated by the shared `foxSoundEnabledProvider` from #053
  (default on). No separate toggle for this sound, and no settings UI yet —
  same as haptics today, surfaced later by #055.
- **No change to the existing haptic**: the sound plays *alongside* the
  existing light haptic impact, not instead of it.

## Acceptance criteria

- [ ] A short congratulation sound plays once per correctly answered
      question, wired through `FoxFeedback.success`/`_submitAndBuzz`.
- [ ] No sound plays on an incorrect answer (out of scope — wrong-answer
      sound is a separate future issue).
- [ ] Sound reuses the shared `audioplayers` dependency and
      `foxSoundEnabledProvider` toggle (added by whichever of #053/#054 lands
      first); no duplicate audio dependency or provider is introduced.
- [ ] When `foxSoundEnabledProvider` is off, no sound plays (haptics still
      fire as today — the two are independent toggles per #053).
- [ ] Bundled sound asset is short (≲1s) and small (≲50KB), CC0/royalty-free,
      with its source and license documented in the repo (e.g.
      `assets/sfx/README.md`).
- [ ] Sound playback goes through the same overridable/stubbed seam as #053
      — no real platform audio channel is hit by `flutter test`/CI.
- [ ] New widget/integration test: grading a correct answer triggers the
      sound-playback call (via the stub seam); grading a wrong answer does
      not.
- [ ] `flutter analyze` / `dart format` / `dart fix --dry-run` /
      `flutter test` clean.

## Out of scope

- Wrong-answer sound — may follow once this plumbing exists.
- Settings UI exposing the sound toggle to the user — owned by #055.
- Lesson-complete / level-up sound — owned by #053.
- Per-keypress dial-pad haptics (`dial_pad_exercise.dart`) — untouched.

## Dependencies

- Builds on #015 (`FoxFeedback`/`feedback_effects.dart`'s reserved sound
  hook).
- Shares the `audioplayers` dependency and `foxSoundEnabledProvider` toggle
  with #053 — implement whichever lands first with that plumbing in mind so
  the second doesn't duplicate it.
- Settings UI for the toggle is future work, tracked by #055.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

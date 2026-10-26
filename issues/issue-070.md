# Issue 070: Sfx playback stops background music on Android — duck instead

Status: open | Priority: P2 | Type: bug | Refined-at: 2026-10-26

## Goal

Playing the correct-answer or level-up chime currently stops any music the
user already had playing in another app, on Android. Change it to duck
(briefly lower the volume of) other audio instead of stopping it, applying
the same fix wherever `audioplayers`' cross-platform `AudioContext` API
already supports it — no native platform code.

## Decisions (2026-10-26, with repo owner)

- **Root cause**: neither `playLevelUp()` nor `playCorrect()`
  (`lib/src/widgets/fox_sound.dart`) ever sets a custom `AudioContext`, so
  `audioplayers`' default `AudioContextAndroid(audioFocus: AndroidAudioFocus.gain)`
  applies — `AUDIOFOCUS_GAIN` tells Android the app is the sole audio
  source, which pauses/stops whatever else was playing.
- **Duck, don't stop**: switch Android's focus request to
  `AndroidAudioFocus.gainTransientMayDuck` — the chime takes focus just
  long enough to play; other audio is attenuated, not paused, and returns
  to full volume right after. No change to the chime's own volume/timing.
- **Cross-platform where the library already supports it, no special-casing**:
  - **Android**: `AudioContextAndroid(audioFocus: AndroidAudioFocus.gainTransientMayDuck)`.
  - **iOS**: add `AVAudioSessionOptions.duckOthers` to the default
    `AVAudioSessionCategory.playback` category (this implicitly also sets
    `mixWithOthers`) — same perceptual effect as Android.
  - **macOS/Windows**: `AudioContext.toJson()` only emits Android/iOS
    config; on every other platform it's a no-op today and stays a no-op —
    nothing to change, consistent with "Android is where it's most
    important."
  - All of the above is a Dart-side `AudioContext` value passed through
    the existing `audioplayers` dependency — no native Android/iOS code.
- **Applies to both chimes**: set once, as a shared `AudioContext`, on both
  of `AudioPlayersSoundPlayer`'s players (`_levelUpPlayer` and
  `_correctPlayer`) via `AudioPlayer.setAudioContext()` before either ever
  calls `.play()` — so `playLevelUp()` and `playCorrect()` both get the fix,
  not just one.

## Acceptance criteria

- [ ] On Android, with music already playing in another app, triggering
  either chime ducks (briefly lowers) that music instead of stopping it;
  the music returns to full volume once the chime finishes.
- [ ] Same ducking behavior on iOS via `AVAudioSessionOptions.duckOthers`.
- [ ] macOS/Windows behavior is unchanged (no `AudioContext` support there
  today).
- [ ] Both `FoxSoundPlayer.playLevelUp()` and `.playCorrect()` use the new
  shared ducking `AudioContext`.
- [ ] `foxSoundEnabledProvider`'s existing on/off toggle (#055) is
  untouched — this only changes behavior while sound is on.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, `flutter test` all clean.
- [ ] Manual QA (audio-focus behavior isn't unit-testable): on a real
  Android device/emulator, start music in another app, trigger each
  chime, confirm ducking (not a stop) and confirm the music returns to
  full volume afterward. Repeat on an iOS device/simulator if available.

## Tasks

1. In `lib/src/widgets/fox_sound.dart`, define a shared `AudioContext`
   (Android `gainTransientMayDuck`; iOS `duckOthers`) and apply it to both
   `_levelUpPlayer` and `_correctPlayer` via `setAudioContext()` in
   `AudioPlayersSoundPlayer`'s constructor, before any `play()` call.
2. Manual QA pass per the acceptance criteria; record the result in this
   issue's Summary once implemented.

## Out of scope

- Any change to sfx content, volume, or trigger conditions.
- App-wide ducking for the whole lesson session — scoped strictly to the
  two short chimes' own playback.
- Native platform code — stays within `audioplayers`' existing
  `AudioContext` API.

## Dependencies

- Builds on #053 (sfx playback) and #055 (sound on/off toggle) — neither
  needs to change.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
# Manual: real Android device/emulator with music playing in another app,
# per the manual QA acceptance criterion above.
```

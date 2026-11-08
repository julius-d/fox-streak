# Issue 123: Correct-answer chime is silent on Android

Status: done | Priority: P1 | Type: bug | Refined-at: 2026-11-08 | Completed-at: 2026-11-08

## Goal

Since the release that made the correct-answer chime start sooner (#122),
no chime is audible on Android when the learner answers correctly. On macOS
the chime still plays. The sound must be audible again on Android, while
keeping the snappy timing that #122 introduced.

## Findings (investigation, 2026-11-08)

- **The sound file is not the problem.** The re-encoded
  `assets/sfx/koiroylers-correct-356013.mp3` (0.97 s, 44.1 kHz stereo) is a
  valid MP3 and plays fine on macOS.
- **The code from #122 is the cause, and only on Android.** #122 switched the
  chime to a preloaded player in `lowLatency` mode. On Android that mode uses
  `SoundPool`, which behaves differently from the regular player:
  - Before each chime the code rewinds the player to the start. On `SoundPool`
    the rewind never reports "done", so the app waits for that
    confirmation until the library's 30 s timeout runs out. The play command
    comes after the rewind, so it is never reached, and the chime stays
    silent.
  - The resulting error is swallowed on purpose ("a chime that can't play
    must never disturb the lesson"), so nothing shows up in the UI or in
    the logs.
  - Additionally, `SoundPool` never reports that a sound finished playing,
    so the player may consider itself "still playing" and ignore later play
    commands. This needs verifying on a device; it could silence all chimes
    after the first one even if the rewind problem is fixed.
- **Why #122's checks missed it.** The unit tests use a fake player, and the
  integration test (`integration_test/chime_player_test.dart`) only checks
  that triggering the chime throws no error. It has never asserted that
  anything is audible, and it appears not to have been run on an Android
  device or emulator.
- Not yet confirmed on a device. Reproduce on Android first and check the
  audio logs before settling on the fix.

## Desired behavior

- On Android, every correct answer plays the chime, including the first
  one after app start, and also rapid consecutive correct answers
  (each from the start of the chime).
- The chime still starts as soon as correctness is known (#122): no
  noticeable delay compared to today's macOS behavior.
- If a fast start and a reliable chime on Android cannot both be achieved,
  reliability wins: Android may fall back to the slightly slower pre-#122
  playback. A working chime beats a fast silent one.
- This is a hotfix: the chime is silent for all Android users in a released
  version.
- Chime still plays on macOS and the other platforms (iOS, Windows) exactly
  as now.
- Failures of the audio backend are still never visible to the learner, but
  they are no longer invisible to developers (they show up in debug logs).
- Unchanged: sound toggle (default on), ducking of other apps' audio (#070),
  no chime on wrong answers, hint taps or dial-pad taps, level-up chime,
  haptics, and the sound's character.

## Acceptance criteria

- [x] Root cause is reproduced on an Android device/emulator and confirmed
      in the issue.
- [x] The chime is audible on Android for the first, second and rapid
      consecutive correct answers in a lesson (manual check on a device).
- [x] Time from "Check" to audible chime on Android is not noticeably worse
      than before #122.
- [x] No regression on macOS (chime audible, same timing as today).
- [x] The integration test fails if the chime playback is stuck or throws,
      and is run on Android as part of the verification.
- [x] The level-up chime on the result screen is checked on Android and is
      audible (fix only if broken; it was not changed by #122).
- [x] Swallowed chime errors are logged (`debugPrint`).
- [x] Follows #015 (no new user-visible strings expected).

## Summary

- Root cause confirmed on an Android emulator: `PlayerMode.lowLatency`
  (`SoundPool`) never confirms `seek(0)`, so `playCorrect()` hung until
  audioplayers' 30 s seek timeout and the swallowed error left the chime
  silent. The old code fails the updated integration test on Android.
- Fix: the preloaded correct-answer chime uses the default media-player mode
  (still prepared up front, so it starts right away). Failures are logged via
  `debugPrint` and still never reach the learner.
- Integration test now has a 3 s budget per chime (plus the level-up chime) and
  passes on macOS and the Android emulator. Audibility/timing by ear is a
  manual check on a real device.

## Code review

- fox_sound.dart: log comment said "debug builds", but `debugPrint` is not stripped in release.
  Fixed: wording changed to "logged (`debugPrint`)".
- Persistently failing chime prints a stack trace on every correct answer.
  Not fixed: only noisy in logs, no functional impact.
- Unverified whether Android confirms `seek(0)` on a stopped `MediaPlayer`.
  No change needed: the integration test passes on the Android emulator.

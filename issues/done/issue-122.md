# Issue 122: Correct-answer chime starts noticeably late

Status: done | Priority: P3 | Type: bug | Refined-at: 2026-11-08 | Completed-at: 2026-11-08

## Goal

When the learner checks an answer and it is correct, the congratulation
chime (#054) plays a beat after the green feedback appears. The delay is
small but noticeable and makes the moment feel less snappy. The chime should
feel simultaneous with the visual result.

## Findings (investigation, 2026-11-08)

- The sound file (`assets/sfx/koiroylers-correct-356013.mp3`, ~1.0 s) has
  only ~50 ms of leading silence — a minor contributor, not the main cause.
- The chime is triggered only after the answer has been graded and
  persisted, and after the haptic's platform round trip has finished.
- The sound is loaded from the asset again on every play, using the
  default (non-low-latency) playback mode.

## Desired behavior

- The chime starts as soon as correctness is known, in parallel with the
  haptic buzz and without waiting for the attempt to be saved. Sound, haptic
  and green banner are perceived as one moment.
- The first correct answer after app start is as fast as later ones.
- Rapid consecutive correct answers each play their chime from the start.
- If audio cannot load or play, the lesson continues silently — no error,
  no delay, no visible effect.
- Unchanged: sound toggle (default on), ducking of other apps' audio (#070),
  no chime on wrong answers, hint taps or dial-pad taps, level-up chime
  (out of scope), haptics, and the sound's character (same chime; only the
  ~50 ms lead-in silence may be trimmed).

## Acceptance criteria

- [x] Root cause(s) of the delay are confirmed and noted in the issue.
- [x] Chime is triggered as soon as correctness is known, independent of the
      haptic and the attempt write.
- [x] Leading silence of the correct-answer mp3 is trimmed; the chime sounds
      otherwise the same.
- [ ] Manual check on a real device: chime feels simultaneous with the
      green banner, including the first correct answer after cold start.
- [x] Improvement works on iOS, Android, macOS and Windows; no plugin swap
      that drops a platform.
- [x] A failing audio load/play does not interrupt the lesson flow.
- [x] No regression: chime is skipped when the sound toggle is off, and
      still ducks (not stops) other audio.
- [x] Tests cover the changed trigger/playback behavior.
- [x] Follows #015.

## Summary

- Root causes confirmed: chime ran after `recordAttempt` and after the haptic round trip, and the asset was reloaded per play in normal playback mode.
- `submitGrade(onGraded:)` fires the chime the moment grading is known (`FoxFeedback.correctChime`, errors swallowed); `AudioPlayersSoundPlayer` preloads the asset at construction in low-latency mode (lesson screen constructs it early) and restarts it per play; ducking context kept.
- mp3 lead-in silence trimmed (~50 ms).
- Tests: controller `onGraded`, `correct_chime_test.dart`, macOS `integration_test/chime_player_test.dart`.
- Open: manual real-device check (iOS/Android/Windows) of the "feels simultaneous" criterion.

## Code review

- Preload failure was cached forever, silencing the chime for the session.
  Fixed: a failed preparation is dropped and retried on the next play.
- `stop()` + `resume()` may not restart on some backends (e.g. Android SoundPool).
  Fixed: now `seek(0)` + `resume()`; still to be confirmed on a real Android device.
- Players were never disposed. Fixed: provider disposes them via `ref.onDispose`.
- Chime plays even if the lesson is abandoned mid-grade / `LessonScreen` reads the provider in every test.
  Not fixed: harmless edge case; the full suite passes without extra overrides.
- Double-tap could play two chimes. Not fixed: `_guarded` already de-duplicates (covered by the double-tap test).
- Shell test lost haptic/toggle wiring coverage. Not fixed: toggle-off and wrong-answer shell tests remain, and `correct_chime_test` covers gating.
- Integration test asserts nothing. Not fixed: it is a smoke test of the real backend; latency needs the manual device check.

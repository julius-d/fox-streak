# Issue 122: Correct-answer chime starts noticeably late

Status: open | Priority: P3 | Type: bug | Refined-at: 2026-11-08

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

- [ ] Root cause(s) of the delay are confirmed and noted in the issue.
- [ ] Chime is triggered as soon as correctness is known, independent of the
      haptic and the attempt write.
- [ ] Leading silence of the correct-answer mp3 is trimmed; the chime sounds
      otherwise the same.
- [ ] Manual check on a real device: chime feels simultaneous with the
      green banner, including the first correct answer after cold start.
- [ ] Improvement works on iOS, Android, macOS and Windows; no plugin swap
      that drops a platform.
- [ ] A failing audio load/play does not interrupt the lesson flow.
- [ ] No regression: chime is skipped when the sound toggle is off, and
      still ducks (not stops) other audio.
- [ ] Tests cover the changed trigger/playback behavior.
- [ ] Follows #015.

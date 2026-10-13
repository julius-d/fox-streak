# Issue 033: restart()/start() can race a still-in-flight submitGrade/skip/next

Status: open | Priority: P4 | Type: tech-debt

## Goal
`#031` added `LessonController._actionInFlight` to serialize
`submitGrade()`/`skip()`/`next()` against each other, but `start()`/
`restart()` are synchronous and don't check or set that flag. If
`restart()` (or `start()`) is called while a prior `submitGrade`/`skip`/
`next` call is still mid-`await` (e.g. during `_completeLesson`'s XP/streak
writes), two things can go wrong:
- `_actionInFlight` stays `true` until the stale call's awaits resolve, so
  the very next legitimate action on the *new*, post-restart lesson could
  be silently dropped by the guard.
- When the stale call resumes, it does `state = state.copyWith(...)` using
  data captured from the *old* session, overwriting the fresh post-restart
  state.

Found during #031's code review. Likely low-probability today since
`restart()` is only reachable from the post-lesson "done"/result screen
(after `_completeLesson` has already finished), but it's not guarded at
the type level, so a future call site (or a fast enough double-tap on
Practice-again right as a trailing write settles) could hit it.

## Acceptance criteria
- [ ] `restart()`/`start()` can't observe or clobber state from a
      `submitGrade`/`skip`/`next` call that's still in flight for a
      *different* session — either by also respecting `_actionInFlight`,
      or by some other mechanism that makes the two non-interfering.
- [ ] A test demonstrating the race (e.g. call `restart()` while a
      `_completeLesson` await is pending) shows the post-restart state is
      not overwritten by the stale call.
- [ ] No regression; `flutter analyze`, `dart format`, `flutter test` stay
      clean/green.

## Out of scope
- Any broader redesign of lesson session lifecycle beyond closing this
  specific race.

## Dependencies
- Builds on #031's `_actionInFlight` guard in
  `lib/src/lesson/lesson_controller.dart`.

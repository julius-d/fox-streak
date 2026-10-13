# Issue 030: Dead `autoAnswer` condition in lesson_screen.dart's real-card dispatch

Status: open | Priority: P3 | Type: tech-debt

## Goal
`lesson_screen.dart`'s `_buildExerciseCard` computes `autoAnswer` as
`item.type == 'choice' && item.choices != null && item.choices!.isNotEmpty`,
then passes it into the `'phone'`/`'date'`/`default` switch branches. Since
the switch guarantees `item.type` matches the branch's literal, `autoAnswer`
is provably always `false` in those branches (it can only be `true` when
`item.type == 'choice'`, which never reaches the `'phone'`/`'date'`/default
cases). Confirmed in production this has zero behavioral effect — found
while implementing #006, which also confirmed `'choice'` itself never
receives `autoAnswer` (the real `MultipleChoiceCard`/`buildMultipleChoiceExercise`
never accepted it).

## Acceptance criteria
- [ ] Clarify or remove the dead `autoAnswer` wiring in `_buildExerciseCard`'s
      real-card switch so the condition actually reflects intent (or document
      why it's structured this way, if intentional).
- [ ] No behavior change; `flutter analyze`, `dart format`, `flutter test`
      stay clean/green.

## Out of scope
- Any change to `widget.cardBuilder`'s test-only `autoAnswer` path (used by
  `test/lesson/lesson_shell_test.dart`), which is unaffected and correct.

## Dependencies
- None blocking.

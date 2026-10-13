# Issue 027: Exercise card tech debt — shared reveal-hint button

Status: open | Priority: P2 | Type: tech-debt

## Goal
Cross-cutting cleanup surfaced by #007 code review, affecting the exercise cards (#006 `MultipleChoiceCard`, #008 `DialPadExercise`, #007 `FreeTextExercise`, #009 `DateExercise`):

~~1. **Per-item state reset gap.**~~ **Resolved by #024** (2026-10-13): `LessonScreen._buildExerciseCard` now keys every real card with `ValueKey(item.id)` (`#024 key fix`, with a regression test in `test/lesson/lesson_shell_test.dart`), so `State` is never reused across items. No action needed here.

2. **Reveal-hint button duplicated three times.** The eye-icon reveal-hint `IconButton` (icon, tooltip, disabled-after-use styling) is copy-pasted across `dial_pad_exercise.dart` (#008), `free_text_exercise.dart` (#007), and `date_exercise.dart` (#009, landed independently while #007 was in review). Per #015 ("reuse the kit, no ad-hoc styling"), this should be one shared kit widget (e.g. `FoxRevealHintButton` in `lib/src/widgets/`).

## Acceptance criteria
- [ ] Extract a shared `FoxRevealHintButton` widget to `lib/src/widgets/` (#015 kit); update `DialPadExercise`, `FreeTextExercise`, and `DateExercise` to use it.
- [ ] `flutter analyze`, `dart format`, `flutter test` stay clean; no behavior change for #006/#007/#008/#009.

## Out of scope
- New exercise functionality — this is cleanup/consistency only.

## Dependencies
- Touches #006/#007/#008/#009 (all already `done`/standalone).

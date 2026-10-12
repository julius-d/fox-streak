# Issue 027: Exercise card tech debt — per-item state reset + shared reveal-hint button

Status: open | Priority: P2 | Type: tech-debt

## Goal
Two cross-cutting cleanups surfaced by #007 code review, affecting the exercise cards (#006 `MultipleChoiceCard`, #008 `DialPadExercise`, #007 `FreeTextExercise`, #009 `DateExercise`):

1. **Per-item state reset gap.** None of the exercise card `State`s reset their input/hint fields on `didUpdateWidget` when the shell advances to a new item in the same tree slot. If `LessonScreen._buildExerciseCard` ever reuses a card's `State` across items (no per-item `ValueKey`), stale typed text / selected option / revealed-hint stays visible on the next question.
2. **Reveal-hint button duplicated three times.** The eye-icon reveal-hint `IconButton` (icon, tooltip, disabled-after-use styling) is copy-pasted across `dial_pad_exercise.dart` (#008), `free_text_exercise.dart` (#007), and `date_exercise.dart` (#009, landed independently while #007 was in review). Per #015 ("reuse the kit, no ad-hoc styling"), this should be one shared kit widget (e.g. `FoxRevealHintButton` in `lib/src/widgets/`).

## Acceptance criteria
- [ ] Confirm whether `LessonScreen` already keys cards per-item (e.g. `ValueKey(item.id)`); if not, add it, or add explicit `didUpdateWidget` reset logic to each card's `State`.
- [ ] Extract a shared `FoxRevealHintButton` widget to `lib/src/widgets/` (#015 kit); update `DialPadExercise`, `FreeTextExercise`, and `DateExercise` to use it.
- [ ] `flutter analyze`, `dart format`, `flutter test` stay clean; no behavior change for #006/#007/#008/#009.

## Out of scope
- New exercise functionality — this is cleanup/consistency only.

## Dependencies
- Touches #006/#007/#008/#009 (all already `done`/standalone).

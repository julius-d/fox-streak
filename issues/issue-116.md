# Issue 116: Redo missed items shrinks the multiple-choice distractor pool

Status: open | Priority: P3 | Type: bug

`LessonController.start()` stores the items it is given as `sourceItems`, and
`lesson_screen.dart` passes `state.sourceItems` to choice cards as the
distractor pool. After "Redo missed items" the pool is only the missed items,
so with 1 missed item there are no distractors, and repeated redo rounds
shrink it further. Since #114 this is the only retry route from the result
screen, so it is hit more often.

## Acceptance Criteria

- Redo missed items keeps the full set as the distractor pool while only the
  missed items are queued.
- Test covers a redo with a single missed item.

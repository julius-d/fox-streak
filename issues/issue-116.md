# Issue 116: Redo missed items shrinks the multiple-choice distractor pool

Status: open | Priority: P3 | Type: bug | Refined-at: 2026-11-07

## Goal
"Redo missed items" queues only the missed items but keeps the full original
item set as the distractor pool for multiple-choice cards.

## Problem
`LessonController.start()` stores the items it is given as `sourceItems`, and
`lesson_screen.dart` passes `state.sourceItems` to choice cards as the
distractor pool. `restartWithItems()` (#078) calls `start(missedItems)`, so
after "Redo missed items" the pool is only the missed items. With 1 missed
item there are no distractors, and repeated redo rounds shrink the pool
further. Since #114 this is the only retry route from the result screen, so
it is hit more often.

Related: #078 (redo missed items), #114 (result screen buttons).

## Approach
Split `start` into a private helper taking separate queue items and pool
items. `start(items)` uses `items` for both, as today. `restartWithItems`
uses the missed items as the queue and keeps the existing
`state.sourceItems` as the pool. The public API is unchanged.

## Acceptance Criteria

- Redo missed items keeps the full set as the distractor pool while only the
  missed items are queued.
- Repeated redo rounds (redo of a redo) still use the original full pool.
- "Practice again" (`start`) still sets the pool to the items it is given.
- `restartWithItems([])` stays a no-op and leaves the pool unchanged.
- Tests (controller level): redo with a single missed item keeps the full
  pool; two consecutive redo rounds keep the full pool.
- Test (widget level): a choice card after a single-item redo still shows
  distractors from the full pool.

## Out of scope
Fallback behaviour of choice cards when the whole set is too small to supply
enough distractors.

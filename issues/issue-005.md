# Issue 005: Lesson player shell (Duolingo-style loop)

Status: open | Priority: P0 | Type: core

## Goal
One bite-size session runner used by all exercise types, like Duolingo lessons.

## Duolingo reference
Top progress bar, 1 question per screen, Check button, instant right/wrong feedback, end summary with XP.

## Acceptance criteria
- [ ] Start lesson from set: shuffle 5-20 items, configurable length
- [ ] Top: progress bar + quit (X) with confirm, hearts optional OFF for v1
- [ ] Bottom: CHECK button -> green/red feedback banner -> CONTINUE
- [ ] End screen: score %, XP earned, best-streak nudge
- [ ] No dead-ends: skip/quit always possible, state survives rotation

## Tasks
1. `LessonController`: queue, index, results, XP accumulation
2. Widgets: `ProgressBar`, `CheckButton`, `FeedbackBanner`, `ResultScreen`
3. Haptics + sound toggle (default on, mutable)
4. Tests: full lesson flow with fake items

## Out of scope
XP formula (#010), streak update (#011) — just emit events.

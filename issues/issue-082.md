# Issue 082: Completion-sequence screens don't block system back/swipe

Status: open | Priority: P3 | Type: tech-debt

## Context

Found during code review of issue #078 (lesson-completion screen split).
`LootboxScreen` (#059, pre-existing, unchanged by #078), and the two new
#078 screens (`StreakSavedScreen`, `XpUpScreen`) all have no back-nav
affordance in their UI (no app bar back button), but none of them actually
block Android's hardware/gesture back or iOS's edge-swipe via `PopScope`.
A back gesture mid-sequence pops the current screen without the user
tapping Continue — for the loot box specifically, swiping away while it's
still closed (before tapping to open it) permanently hides a reward that
`PetService.recordLessonCompletion()` already persisted to the DB, so the
user never sees what they won.

Issue #078's acceptance criteria said "no back-navigation mid-sequence,"
but that was written assuming consistency with `LootboxScreen`'s existing
(also gap-having) posture — not a request to change `LootboxScreen`'s
behavior, which #078 explicitly scoped as unchanged. Fixing just the two
new screens would make them inconsistent with the loot box they sit
beside in the same sequence, so this is left as a single follow-up
covering all three together.

## Goal

Decide whether this is worth fixing (most users won't discover the
gesture, but it's a real reward-visibility loss when they do) and, if so,
add a shared `PopScope(canPop: false)` (or equivalent) to `LootboxScreen`,
`StreakSavedScreen`, and `XpUpScreen` together.

## Out of scope

Changing `LootboxScreen`'s reveal content/animation — only its back-nav
handling, if this is picked up.

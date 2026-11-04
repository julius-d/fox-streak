# Issue 111: XpUpScreen's milestone pet (#081) has no a11y announcement

Status: open | Priority: P3 | Type: tech-debt

## Goal

Give `XpUpScreen`'s milestone-only `FoxPet` (issue #081) a real
`semanticLabel` instead of `null`, so a screen-reader user is told about
the milestone, not just sighted users via the pet's presence.

## Context

Found during #081's code review. `FoxPet`'s doc (`fox_pet.dart`) allows
`semanticLabel: null` only for "a purely decorative repeat next to a
labelled heading" — the heading/streak text already announces the
moment, so the pet repeating it would be redundant. `StreakSavedScreen`
fits that: the pet sits right under `lessonStreakSavedHeading` and above
the streak-count text, both announced.

`XpUpScreen` doesn't fit it. That screen has no heading and no
streak/milestone text anywhere — just the milestone pet, immediately
followed by the unrelated `+XP` count-up. A screen-reader user reaching
`XpUpScreen` on a milestone completion hears the XP count but nothing
about the milestone at all; `semanticLabel: null` there silently drops
the moment for that user, which is the opposite of #081's goal.

Not fixed as part of #081 itself: a real label needs a new l10n string
(DE + EN, per AGENTS.md's "user-visible strings flow via `lib/l10n` arb
params"), which #081's acceptance criteria explicitly scoped out ("No new
l10n strings needed") — doing it right is a small but real product/copy
decision, not a one-line fix.

## Acceptance Criteria

- Add an l10n string (DE + EN) announcing the milestone on `XpUpScreen`'s
  pet (e.g. reusing/mirroring `StreakSavedScreen`'s streak-count phrasing,
  or a standalone "milestone streak" announcement — wording is an
  implementation call).
- `XpUpScreen`'s milestone `FoxPet` passes that string as `semanticLabel`
  instead of `null`.
- `StreakSavedScreen`'s milestone `FoxPet` is unaffected (its `null` is
  already justified by its own heading/streak text).

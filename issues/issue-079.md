# Issue 079: Extract a shared "bounded breath/play, pause, repeat" animation helper

Status: open | Priority: P3 | Type: chore | Refined-at: 2026-10-26

## Goal

`lib/src/widgets/fox_pet.dart`'s `_FoxPetState` (issue #071) and
`lib/src/pet/lootbox_screen.dart`'s `_LootboxScreenState` (issue #073) each
independently implement the same shape: an `AnimationController` that
plays a bounded animation once, then waits out a `Timer`-based pause
before repeating, for as long as the widget stays mounted and
`MediaQuery.disableAnimationsOf(context)` is false. They exist separately
because `fox_pet.dart` plays forward-only (0 -> 1, then re-`forward(from:
0)`) while `lootbox_screen.dart`'s pulse breathes forward-then-reverse
(a "ping-pong"), but the controller/timer/dispose/reduce-motion bookkeeping
around that difference is identical in both.

Flagged during #073's code review: a correctness fix applied to one
(e.g. #073 added a reduce-motion-mid-cycle reset) has no shared location
to live in, so the same class of bug could silently reappear in the
other.

## Why not fixed in #073

This would be a cross-file refactor touching the already-stable, tested
`FoxPet` widget (not just the new lootbox pulse), which is bigger than a
"small and easy fix" — out of scope for a bug-fix issue.

## Suggested shape (not binding — re-evaluate when picking this up)

A small helper, e.g. `BoundedLoopController` or a mixin, owning: the
`AnimationController`, the pause `Timer`, start/stop/reset methods, and
the reduce-motion check — parameterized by "forward-only" vs
"forward-then-reverse" playback. Migrate `FoxPet` and `LootboxScreen`'s
pulse onto it, keeping both widgets' existing tests green.

## Dependencies

None blocking; depends on #071 and #073 both already being merged.

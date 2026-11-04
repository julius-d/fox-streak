# Issue 105: De-duplicate the reduce-motion Hero-wrap helper

Status: done | Priority: P4 | Type: tech-debt | Refined-at: 2026-11-04 | Completed-at: 2026-11-04

## Context

Two independent features now wrap a moving element in a `Hero`, bypassed
when the OS reduce-motion accessibility setting is on — the equipped pet
flying between Home and Pet Collection (`lib/src/pet/pet_hero.dart`,
`wrapEquippedPetHero`, issue #100) and the question image flying into its
full-screen view (`lib/src/widgets/fox_question_image.dart`,
`_wrapQuestionImageHero`, issue #103). Both implement the identical
3-line pattern:

```dart
if (MediaQuery.disableAnimationsOf(context)) return child;
return Hero(tag: ..., child: child);
```

Found during #103's code review: this is harmless today, but a future
change to the reduce-motion-Hero convention (e.g. a different signal, or
extra bookkeeping) risks landing in only one of the two copies.

## Goal

One shared helper implements the "wrap in a Hero unless OS reduce-motion
is on" convention; both `pet_hero.dart` and `fox_question_image.dart`
delegate to it instead of each keeping their own copy.

## Decisions

- Not fixed directly in #103 — it touches `pet_hero.dart`, an already
  shipped, unrelated feature's file, so it's split out here rather than
  widening that issue's diff.

## Acceptance criteria

1. A single widget-kit-level helper (e.g.
   `lib/src/widgets/fox_hero.dart`) takes a `BuildContext`, a Hero tag,
   and a child, and returns the bypassed-or-wrapped widget.
2. `wrapEquippedPetHero` and `_wrapQuestionImageHero` both delegate to it;
   no behavior change on either screen.
3. `flutter analyze`, `dart format`, `flutter test` stay clean.

## Out of scope

- Any change to what triggers reduce-motion, or to either feature's own
  Hero tag/scope.

## Summary

Added `lib/src/widgets/fox_hero.dart` with `wrapInReducedMotionHero(context,
tag, child)`, the shared "Hero unless OS reduce-motion is on" logic. Both
`wrapEquippedPetHero` (#100) and `_wrapQuestionImageHero` (#103) now
delegate to it — no behavior change. Not added to the `widgets.dart`
barrel: it's a bare helper function, not a widget, matching how
`pet_hero.dart` is also imported directly rather than via the barrel.

## Code review

- No new dedicated unit test for `wrapInReducedMotionHero` itself.
  Not fixed: existing behavioral tests at both call sites
  (`fox_question_image_test.dart`, `pet_screens_test.dart`,
  `home_screen_test.dart`) already exercise the reduce-motion on/off
  paths end-to-end, so a regression would still be caught.

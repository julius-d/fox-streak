# Issue 100: Hero animation for the pet between Home and Pet Collection

Status: open | Priority: P3 | Type: enhancement | Refined-at: 2026-11-01

## Context

The equipped pet (`FoxPet`) is shown on the Home dashboard as a tappable
avatar (`homePetButton`, 96px), and tapping it pushes `PetCollectionScreen`,
a grid of owned/locked pets where the same equipped pet also appears as one
of the tiles (72px, highlighted). Today that navigation is a plain push/pop
with no visual connection between the two appearances of the pet — it just
appears at its new size and position.

The pet also appears elsewhere in the app (onboarding slides, the lootbox
reveal, the lesson-result celebration, the Library/Set-detail empty states),
but those were considered and ruled out for this issue: either there's no
real screen transition to animate across (onboarding is a same-route swap),
the pet shown can legitimately be a *different* pet than on the destination
screen (lootbox reveal shows the newly-won pet, not necessarily the equipped
one), or the navigation isn't a single push/pop transaction (Lesson Result
back to Home goes through `popUntil`, unwinding several screens at once).
Home ⇄ Pet Collection is the one place where it's unambiguous: the exact
same pet, a direct push and its matching pop.

In `PetCollectionScreen`, tapping an owned tile equips it in place (the grid
rebuilds and the highlighted border moves to the new tile) — it does not
navigate anywhere. The user then returns to Home via back button/system
back/swipe. Only the currently-equipped tile ever renders a `FoxPet` in the
grid; locked tiles show a lock icon instead.

The app already has a reduce-motion convention: `FoxPet` and other animated
kit widgets (`FoxProgressBar`, the lootbox reveal) check
`MediaQuery.disableAnimationsOf(context)` and skip/shorten their own motion
accordingly, rather than adding a bespoke in-app toggle.

## Goal

When navigating between Home and Pet Collection, the equipped pet should
visually travel from its position/size on one screen to its position/size
on the other, instead of just popping into place — reinforcing that it's
the same companion, for continuity and delight. This works both forward
(tapping the pet on Home) and in reverse (navigating back from Pet
Collection to Home).

## Decisions (from clarifying discussion)

- **Which pet animates on the way back:** whichever pet is equipped at the
  time of back-navigation. Since equipping doesn't auto-navigate, this is
  naturally consistent — there's no case where the user equips pet B but
  pet A flies back to Home.
- **Sizing:** the pet's size animates smoothly as part of the flight
  (standard Hero scaling behavior), from 96px down to 72px (or back), not
  held visually constant.
- **Tag uniqueness:** only the equipped tile shows a `FoxPet` in the grid
  (locked tiles show a lock icon), so there's always exactly one matching
  element per screen to animate between — no ambiguity from multiple tiles.
- **Reduce motion:** when the OS-level reduce-motion accessibility setting
  is on, the transition is instant (no flight animation), matching the
  existing `FoxPet`/`FoxProgressBar` reduce-motion convention rather than
  introducing a new one.

## Acceptance criteria

1. Tapping the pet avatar on Home visually carries it into its tile in the
   Pet Collection grid as the screen transitions in.
2. Navigating back from Pet Collection to Home visually carries the
   currently-equipped pet back into the Home avatar position as the screen
   transitions out — including when the user equipped a different pet while
   on that screen.
3. The pet's size changes smoothly during the flight between the two
   screens' sizes (96px on Home, 72px in the grid).
4. With OS reduce-motion enabled (`MediaQuery.disableAnimationsOf`), the
   transition is instant in both directions — no flight animation.
5. No change to tap targets, equip behavior, grid layout, or any other
   element on either screen.

## Out of scope

- Any other screen pair that also shows the pet (onboarding, lootbox reveal,
  lesson result, empty states) — ruled out above, not pursued in this issue.
- Changing what the pet avatar does when tapped, or the Pet Collection
  screen's layout/behavior otherwise.

# Issue 134: Mastery crowns on Library set cards instead of the item count

Status: done | Priority: P2 | Type: feature | Refined-at: 2026-11-15 | Completed-at: 2026-11-15

PR: https://github.com/julius-d/fox-streak/pull/4

## Goal

At a glance on the Library overview, the user sees how well they already
know each set: five gold crowns that fill up as more of the set's items
are mastered, and a "New" badge on sets they have never practiced.
Progress feels rewarding (smooth fill, crown pops, a gold shimmer at
100%) and never shaming.

## Context

Today each Library set card shows only "N items" under the title — it
says nothing about how much the user has practiced. Lessons pick at most
20 random items, so for bigger sets a single lesson never covers the
whole set; a progress signal based on "perfect lessons" would not work
for them. Each answer is already recorded per item, so a per-item
mastery signal also reflects practice done before this feature.

## Decisions

- **Mastered item**: an item is mastered when its **two most recent
  answers** were both correct **and given without a hint**. A wrong
  answer, a skip, or a correct answer with a hint resets it — it needs
  two clean correct answers in a row again.
- Answers from every kind of lesson count (normal lesson, "practice wrong
  items" retry, …).
- **Answers recorded before this feature** carry no hint information and
  count as given without a hint, so existing users see their progress
  immediately.
- **Mastery share** = mastered items ÷ all items currently in the set.
  Adding items lowers it (new items are not mastered), deleting items
  removes them from the calculation. **Editing** an item's prompt or
  answer keeps its mastered status.
- **Crowns**: five crowns, filled **continuously** from left to right —
  the share × 5, any fraction (e.g. 45% → two full crowns plus a quarter
  of the third; 2% → a sliver of the first). Five full crowns only when
  every item is mastered. Filled parts use the existing XP-gold color,
  unfilled parts an outline legible in light and dark mode.
- **Set card**: the crowns replace the "N items" subtitle; the item count
  is no longer shown on the card.
- **"New" badge**: shown instead of the crowns while no item of the set
  has ever been answered. It goes away as soon as any item was answered
  once (even wrong or skipped) — the crowns then appear, possibly all
  empty. Newly created, duplicated, imported and downloaded sets start
  as New.
- **Empty set** (0 items): the card shows neither crowns nor a badge.
- **Set detail screen**: the header shows the count and mastery, e.g.
  "12 items · 7 mastered", plus one short explanatory line, e.g.
  "Mastered = answered correctly twice in a row without a hint". A set
  without items just shows "No items".
- **Motion** (on the Library set cards):
  - **Fill grows**: when the card appears and its mastery went up since
    it was last shown (e.g. back from a lesson), the crowns fill
    smoothly from the old to the new value (~600ms, light bounce at the
    end).
  - **Crown pop**: each crown that becomes full during that fill pops
    with a small bouncy scale and a light haptic tick (existing
    `FoxFeedback`, respects the in-app haptics toggle).
  - **Gold shimmer**: when the set reaches 100% — every time it gets
    there from below, never on a plain visit — one short gold shimmer
    sweeps across the crowns.
  - **"New" badge morph**: when a set leaves the New state, the badge
    shrinks away and the crowns fade in (then fill, if any are earned).
  - **Going down**: when mastery drops (mistakes, added items), the card
    simply shows the lower value — no animation, no message.
  - **Reduced motion**: with the OS reduce-motion setting on, the card
    shows the final state instantly — no fill, pop, shimmer or morph.
- **Accessibility**: crowns and badge are announced as one element, e.g.
  "45% mastered" or "New, not practiced yet"; the layout survives the
  largest font size without clipping.
- Follows #015 (kit styling, motion language, a11y floor); all new
  strings in DE + EN arb files.

## Acceptance criteria

1. A set card whose set has answered items shows five crowns filled to
   exactly mastered ÷ total × 5 (continuous, left to right) and no item
   count.
2. An item counts as mastered only if its two most recent answers are
   both correct and without a hint; a wrong, skipped or hinted answer
   un-masters it until it gets two clean correct answers again.
3. Answers recorded before this feature count as hint-free; an existing
   user's sets show crowns immediately after the update.
4. Adding items lowers the crowns, deleting items recalculates them, and
   editing an item's prompt/answer keeps its mastered status.
5. A set with items but no answer ever shows a "New" badge instead of
   crowns; after its first answered item the badge is gone and crowns
   (possibly empty) show. New, duplicated, imported and downloaded sets
   start as New.
6. A set with 0 items shows neither crowns nor a badge.
7. The set detail header shows "N items · M mastered" plus the
   explanation line in DE and EN; an empty set shows "No items".
8. After a lesson that raised a set's mastery, its card animates the fill
   from old to new value; each crown that becomes full pops with a light
   haptic tick (only when haptics are enabled).
9. Reaching 100% plays one gold shimmer, every time the set reaches 100%
   from below, and not when a set already at 100% is simply viewed again.
10. Leaving the New state plays the badge-shrink + crown fade-in.
11. A drop in mastery shows the lower value with no animation and no
    message.
12. With OS reduce-motion on, cards show final states without any fill,
    pop, shimmer or morph animation.
13. Screen readers announce each card's mastery as one phrase
    ("45% mastered" / "New, not practiced yet"); with the largest font
    size nothing is clipped, in light and dark mode.
14. Follows #015: no ad-hoc colors (crowns use XP-gold), all strings via
    DE + EN arb files.

## Out of scope

- Showing crowns anywhere else (lesson result screen, home screen, pack
  headers) — possible follow-ups.
- A "needs a refresh" cue for sets not practiced in a while.
- Changing how lessons pick items (20-item cap, preferring unmastered
  items) or sorting/filtering the Library by mastery.
- The question-set exchange format is unchanged — hint information is
  local practice data and not exported, so no `docs/` updates are needed.

## Summary

- Schema v19: `attempts.hint_used` (pre-#134 rows = hint-free) + index
  `attempts_item_recency`; `StatsRepository.watchSetMastery` counts mastered
  items (two latest attempts correct + hint-free) per set in one query.
- Kit: `FoxMasteryCrowns` (custom-painted, XP-gold, continuous fill) +
  `FoxNewBadge`, with goldens. Library cards use `SetMasteryIndicator`; the
  pure `planMasteryMotion` decides fill / pop / shimmer / morph vs. the value
  the card last showed this session (`shownMasteryProvider`). Covered cards
  don't animate until they are on top again.
- The lesson result's "Home" pops to Home, so the motion usually plays when
  the user reopens the Library via "Browse sets".
- Set detail: "N items · M mastered" header + explanation; an empty set keeps
  its existing "No items yet" empty state (no header).
- Screenshots: `issues/done/issue134-*.png`.

## Code review

Mastery query window-scanned the whole `attempts` table on every answer.
Fixed: added the `(item_id, at, id)` index in the v19 migration.
Set detail header mixed counts from two streams (could briefly read e.g. "13 items · 12 mastered").
Fixed: both counts come from the one mastery snapshot.
Empty set shows the existing "No items yet. Add the first one!" state instead of a literal "No items".
Not fixed: it already says "No items" and keeps the add-item CTA; no header for empty sets, as specified.
Mastery changing mid-animation restarts the fill from the previous value (possible extra haptic tick).
Not fixed: needs a stream re-emit within ~1s on a visible card; rare and harmless.
`shownMasteryProvider` is a session-lived mutable map; deleted sets' entries are never evicted.
Not fixed: a few ints per set for one app session; intentional session-only baseline.
Deleting every answered item flips a set back to "New".
Not fixed: matches the spec's "share of items currently in the set"; their attempts are gone too.

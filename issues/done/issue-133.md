# Issue 133: "New set" speed-dial overlaps its lowest option on edge-to-edge Android, and pops in without motion

Status: done | Priority: P2 | Type: bug | Refined-at: 2026-11-15 | Completed-at: 2026-11-15

## Goal

The Library speed-dial's options are always fully visible and tappable
above the main FAB on every device, navigation mode and font size — and
opening/closing it feels like a deliberate, playful FoxStreak moment
instead of a hard cut.

## Context

The Library overview's "New set" FAB (#074) opens a speed-dial: a dimmed
scrim plus three stacked options — "Marketplace", "Import set",
"New set" — above the main FAB, which turns into a close (×) button.

On modern Android devices with edge-to-edge rendering (e.g. Google
Pixel 9, especially with 3-button navigation), the main FAB sits higher
than on other devices because it is lifted above the system navigation
bar, but the option stack doesn't move up with it. The main FAB then
covers the lowest option ("New set"), so it is partly hidden and hard
or impossible to tap. Larger system font sizes make the overlap worse.

Separately, the menu currently appears and disappears instantly: the
scrim, options and the main FAB's "+ New set" → "×" change all jump in a
single frame. That feels abrupt next to the rest of the app's bouncy
micro-moments (#015).

## Decisions

- **Layout**: the option stack always sits directly above the main FAB
  with the usual gap, wherever the main FAB ends up (system nav bar,
  gesture handle, iOS home indicator, large fonts). No option may ever
  be overlapped by the main FAB or by system UI.
- **Short screens** (e.g. phone landscape + largest font): every option
  stays fully visible and reachable — the options may sit closer
  together or the stack may scroll, but none ends up under the main FAB
  or the app bar.
- **Open animation — "bouncy pop"**: each option pops out of the main
  FAB with a small overshoot (grows slightly past full size, then
  settles) while fading in, staggered bottom → top ("New set" first,
  "Marketplace" last). The scrim fades in alongside. ~300ms total: each
  option ~200ms, started ~50ms after the one below it.
- **Close animation**: the reverse — options shrink/fade back into the
  FAB (top → bottom), scrim fades out, ~200ms. Closing via ×, scrim tap
  or the system back gesture all animate the same way.
- **Interrupting**: closing while the open animation is still running
  (or reopening while closing) reverses smoothly from the current
  position — no jump, no restart.
- **Main FAB morph**: the extended "+ New set" button smoothly shrinks
  to the round button while its + rotates into ×; it morphs back on
  close. In the collapsed state it looks and sits exactly as today.
- **Haptics**: one light haptic tick on open (existing `FoxFeedback`,
  respects the in-app haptics toggle); none on close.
- **Picking an option** closes the menu and continues immediately to
  the chosen action (editor, file picker, marketplace) — the close
  animation must not delay or block navigation.
- **Reduced motion**: if the OS asks to reduce/remove animations, the
  menu shows and hides instantly (current behavior), still with correct
  layout.
- **Audit scope**: besides the Library speed-dial, the other FAB screens
  — Set Detail ("Add item" + "Start lesson" stacked FABs) and
  Marketplace Sources ("Add source") — are checked on edge-to-edge
  Android and with large fonts; any overlap found there is fixed as part
  of this issue. They get no new animation.
- Follows #015 (kit styling, motion language, a11y floor).

## Acceptance criteria

1. On an edge-to-edge Android device (3-button nav and gesture nav), the
   expanded Library speed-dial shows all three options fully above the
   main FAB with a visible gap; each one, including the lowest
   "New set", is fully tappable.
2. Same holds with the largest system font size and on iOS (home
   indicator), macOS and Windows.
3. On a short screen (phone landscape + largest font) every option is
   fully visible or reachable by scrolling, never under the main FAB or
   the app bar.
4. An automated test simulates a bottom system inset (nav bar) plus a
   large text scale and fails if any option overlaps the main FAB —
   guarding the fix without needing an Android device.
5. Opening the menu plays the staggered bouncy pop (bottom → top, ~300ms)
   with the scrim fading in and one light haptic tick (when haptics are
   enabled); the main FAB morphs from "+ New set" to a round × with the
   icon rotating.
6. Closing via ×, scrim tap or system back plays the reverse animation
   (~200ms) and returns the main FAB to "+ New set", identical in look
   and position to today's collapsed state.
7. Tapping an option opens its target right away; quickly tapping
   open/close repeatedly reverses smoothly and never leaves the menu
   half-open, stuck, or with options tappable while hidden.
8. With the OS reduce-motion setting on, the menu opens and closes
   without animation, and criteria 1–3 still hold.
9. Set Detail and Marketplace Sources FABs show no overlap with each
   other, list content clearance (#104) or system UI on edge-to-edge
   Android and with large fonts.
10. Screen readers still only reach the options and the close button
    while the menu is open (scrim keeps blocking the list behind it), and
    options are announced only once fully shown.
11. Follows #015: no new ad-hoc colors or button styles; labels come
    from the existing DE + EN strings.

## Out of scope

- Changing which actions the speed-dial offers or their labels/icons
  (#074).
- Adding animations to the Set Detail or Marketplace Sources FABs.
- The list bottom clearance behind FABs (#104), unless the audit finds
  it no longer fits.
- No question/data format or schema changes are involved, so no `docs`
  updates are needed.

## Summary
- Root cause: the options sat at a fixed `bottom: 96` in the body while Scaffold lifts the FAB above the bottom system inset. Now `SpeedDial` (`lib/src/library/speed_dial.dart`) puts options + main FAB together in Scaffold's FAB slot, so they always stack directly above it; on short screens the options scroll (`speedDialOptions`) instead of reaching the app bar.
- One `AnimationController` in `LibraryScreen` drives scrim (`SpeedDialScrim`), staggered `easeOutBack` pops (`speedDialOptionSlice`) and the extended → round FAB morph. forward/reverse keeps interrupts smooth. Options ignore taps while closing and are read by screen readers only once fully shown. Reduced motion sets the value directly. Open plays `FoxFeedback.tick`.
- Audit: Set Detail / Marketplace Sources had no overlap. But long labels at large fonts pushed extended FABs off the left edge, so the new kit `FoxFabLabel` scales them down instead (all extended FABs on these screens).
- Tests: `test/library/library_speed_dial_test.dart` (edge-to-edge inset + 2x text via `test/widgets/edge_to_edge_view.dart`), audit tests in the Set Detail / Marketplace Sources screen tests, `integration_test/issue133_speed_dial_test.dart`.
- Screenshots: `issue-133-1-collapsed-navbar-48dp-text-1.6x.png`, `issue-133-2-opening-mid-pop.png`, `issue-133-3-open-navbar-48dp-text-1.6x.png`, `issue-133-4-open-short-landscape-text-2x.png`.

## Code review
- Option count was a separate constant from the options list (controller duration could drift from the stagger).
  Fixed: duration is set from `options.length`.
- A visible snack bar lifts the FAB slot past the short-screen height cap.
  Fixed: opening the menu hides the current snack bar; test added.
- Options' shadow was clipped on the right by the scroll view.
  Fixed: custom `ClipRect` widened to the right instead of the scroll view's own clip.
- FoxFabLabel and the morphing FAB hard-coded the same M3 chrome values separately.
  Fixed: shared constants on `FoxFabLabel`.
- `bottomClearance` used `padding.bottom` only; Scaffold lifts by the view padding too.
  Fixed: uses the larger of both.
- Main FAB semantics flip to "New set" as soon as closing starts, while it still looks like ×.
  Not fixed: during close a tap reopens the menu, so "New set" matches the action.
- SpeedDial has its own status listener, although the Library also rebuilds on status.
  Not fixed: keeps SpeedDial correct on its own, without relying on the parent.
- The morphed main FAB keeps its zero-width label, so `find.text('New set')` matches twice when open.
  Not fixed: needed for the smooth morph; label is excluded from semantics, tests find by key.

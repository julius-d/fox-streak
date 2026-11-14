# Issue 127: The snowflake is the one icon for a streak freeze

Status: done | Priority: P3 | Type: enhancement | Refined-at: 2026-11-14
Completed-at: 2026-11-14

## Goal

A streak freeze currently looks different depending on where the learner
meets it: Home's streak badge and the coin shop show an ice cube (#108),
while the lucky wheel and the win / purchase / save messages show a
snowflake. The name is mixed too — most copy says "streak freeze", but the
English coin shop says "streak on ice". The learner should recognize the
freeze as one thing everywhere: always a snowflake, always called
"streak freeze".

This intentionally reverses #108's decision to replace the snowflake with
an ice cube.

## Desired behavior

### One icon: the snowflake

- The snowflake is Material's standard snowflake icon (flat, single-color,
  same style as the app's other icons) — it looks the same on every
  platform, not an OS-dependent emoji. It's used as is; no custom or bolder
  variant.
- Everywhere the app shows an icon for a streak freeze, it's this
  snowflake:
  - **Home streak badge** — a day saved by a streak freeze shows an
    icy-blue snowflake in the per-day icon row (instead of the ice cube);
    practiced days keep their flame. Row size, cropping and the badge's
    accessible summary stay as #108 defined them.
  - **Coin shop freeze balance** — the icy-blue snowflake sits next to the
    balance label ("1 streak freeze"), replacing the ice cube. The buy
    button stays icon-less as today.
  - **Streak Details freeze balance** — *new*: the "N streak freezes
    available" line gets the same icy-blue snowflake in front of it, so
    both places that show the freeze balance look alike. Decorative only;
    the text stays the accessible label.
  - **Lucky wheel** — the streak-freeze slice shows the same snowflake
    icon (instead of today's ❄ text character). Because the slice itself
    is filled icy-blue, the snowflake uses the slice's contrasting
    foreground color, like the coin amounts on the other slices.
- The ice-cube icon no longer appears anywhere in the app.
- Sizes, placement and screen-reader labels of the existing spots stay as
  they are today; only the glyph changes.

### Unchanged

- **Streak Details calendar**: frozen days stay icy-blue cells without an
  icon (including the legend swatch), as designed in #087.
- **Messages keep their ❄️ emoji**: "You won a streak freeze! ❄️",
  "Your streak was saved with a streak freeze! ❄️" and the purchase
  success message keep the emoji — it is already a snowflake.
- Android home-screen widget: shows no freeze today; nothing is added.

### One name: "Streak freeze"

- All visible copy calls it "streak freeze" (DE: "Streak-Freeze"). The
  English coin shop texts that still say "streak on ice" switch over:
  - confirm title: "Buy streak freeze?"
  - confirm message: "Spend {price} coins for one streak freeze?"
  - purchase success: "You bought a streak freeze! ❄️"
  - balance label: "No streak freezes yet" / "1 streak freeze" /
    "{count} streak freezes" (proper plural)
- German copy already says "Streak-Freeze" everywhere; no change expected
  beyond a consistency check.

## Acceptance criteria

- [ ] Home streak badge shows an icy-blue snowflake for each streak-freeze
      day and a flame for each practiced day.
- [ ] Coin shop's freeze balance shows the icy-blue snowflake instead of
      the ice cube; the buy button is unchanged.
- [ ] Streak Details' "N streak freezes available" line shows the same
      icy-blue snowflake; screen readers still read only the text.
- [ ] Lucky wheel's streak-freeze slice shows the snowflake icon in the
      slice's contrasting foreground color, legible on the icy slice.
- [ ] No ice-cube icon remains anywhere in the app.
- [ ] Snowflake is visible in light and dark theme on every screen above.
- [ ] Streak Details calendar cells/legend and the ❄️ in messages are
      unchanged.
- [ ] No visible EN or DE copy says "streak on ice" / "on ice"; it's
      "streak freeze" / "Streak-Freeze" throughout, with correct plurals.
- [ ] Widget tests cover the snowflake on Home, coin shop, Streak Details
      and the wheel; golden baselines are updated where the change affects
      them.
- [ ] Follows #015 (kit reuse, semantic colors, a11y labels, DE + EN strings).

## Summary

- New kit widget `FoxStreakFreezeIcon` (`Icons.ac_unit`, defaults to `FoxSemanticColors.ice`) replaces `FoxIceCubeIcon`. Used by the Home streak badge, the coin shop balance and (new) the Streak Details balance line.
- `WheelPainter` labels are now typed (`WheelTextLabel` / `WheelIconLabel`); the freeze slice paints `FoxStreakFreezeIcon.iconData` in `onIce` instead of the ❄ character.
- EN coin shop copy now says "streak freeze" with proper plurals; arb keys kept their old `…StreakOnIce…` names. DE was already consistent.
- No golden covers these widgets, so no baselines changed. Screenshots: `issue-127-*-{light,dark}.png`.

## Code review

- Wheel icon style ignores `textStyle`'s weight/features; glyph size/centering not asserted.
  Not fixed: Material icons have one weight; checked visually via the screenshots.
- Streak Details snowflake is a fixed 20dp (no text scaling) and was vertically centered against wrapped text.
  Fixed: top-aligned. Scaling not changed: kit icons don't scale elsewhere either, and #012 owns the large-font pass.
- arb keys still named `…StreakOnIce…` while copy says "streak freeze".
  Not fixed: internal names only, renaming would churn all call sites.
- Issue file not yet moved to `issues/done/`.
  Fixed: moved as part of completion.

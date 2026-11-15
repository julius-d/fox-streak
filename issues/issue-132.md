# Issue 132: Streak Details polish — freeze days count, German wording, calmer animations

Status: open | Priority: P3 | Type: enhancement | Refined-at: 2026-11-15

## Goal

Follow-up to #128 after using it on a real phone:

- The hero and the "Longest streak" tile disagree about the same streak:
  the hero leaves out days saved by a streak freeze, the tile counts them.
- Some German copy is wrong ("die Streak" instead of "der Streak", plural
  captions next to a count of 1).
- The legend's "Current streak" entry isn't needed.
- The opening animations run all at once and are over before the page has
  even finished sliding in, so they're hard to notice.

## Desired behavior

### A day saved by a streak freeze is a streak day

- A day saved by a streak freeze counts toward the streak length,
  everywhere a streak number is shown: Home's streak badge, the Streak
  Details hero and "Longest streak" tile, the "streak saved" screen after a
  lesson, and the Android home-screen widget. They always show the same
  number for the same streak, and it matches the number of days the
  current-streak band surrounds.
  - Example: practiced Mon–Fri, Saturday saved by a freeze, practiced
    Sunday → a 7-day streak everywhere (today it shows 6 in some places
    and 7 in others).
- Existing streaks that already contain a freeze day are corrected once
  when the app updates, so nobody's streak looks shorter afterwards. Only
  freeze days the app has recorded count; a streak older than the recorded
  daily activity (#084) is left as it is.
- Milestone moments (3, 7, 14, 30, 50, 100 days) still only play when a
  lesson is completed. A milestone reached by a freeze day alone (e.g. the
  freeze makes it day 7) is not celebrated. That's accepted.
- This changes #087's rule that a freeze keeps the number unchanged.

### German wording: "der Streak", everywhere

- German uses the masculine "der Streak" in the whole app, not only on
  Streak Details. Onboarding already says "deinen Streak". At least these
  change:
  - "Aktuelle Streak …" / "Keine aktuelle Streak" → "Aktueller Streak …" /
    "Kein aktueller Streak" (screen-reader label of the hero)
  - "Längste Streak" → "Längster Streak" (tile, tile label for screen
    readers, legend)
  - "Übe heute, damit deine Streak weiterläuft." → "… dein Streak …"
  - "Starte heute eine neue Streak!" → "Starte heute einen neuen Streak!"
  - Home banner "Deine Streak wurde mit einem Streak-Freeze gerettet!" →
    "Dein Streak …"
  - Android widget "Übe heute, um deine Streak zu halten!" → "… deinen
    Streak …" and widget description "Deine Streak, dein Tier …" → "Dein
    Streak, …" (this one lives in the widget's own German resource strings,
    which are shown before the app first runs)
- A final sweep of all German strings makes sure no feminine "Streak" is
  left.

### Singular captions on the stat tiles (DE + EN)

- The tile captions follow their number: 1 → "1 Übungstag" /
  "1 Streak-Freeze" (EN "1 Practice day" / "1 Streak freeze"). Every other
  count, including 0, uses the plural: "0 Übungstage", "2 Streak-Freezes".
- The tiles' screen-reader labels follow the same rule (e.g.
  "1 Übungstag insgesamt").

### Legend

- The "Current streak" entry ("Aktuelle Streak") is removed. The other
  legend entries stay as they are.

### Animations: one after the other, easier to see

- The opening sequence starts only once the screen has fully opened (the
  page transition is finished), then plays one step after the other:
  1. **Count-up** of the hero number, about 1.5 s, slowing down at the
     end. The flame starts flickering with it.
  2. **Streak band draws in** backwards from today to the streak's first
     day, about 2 s, however long the streak.
  3. **Today pulse**: 3 gentle pulses of about 1 s each, only while today
     isn't practiced yet.
- The durations are fixed, whatever the streak length.
- The sequence plays every time the screen opens (as in #128).
- Steps that don't apply are skipped, and the next one follows right away
  (e.g. a 0 streak has no count-up and no band, so the today pulse comes
  first).
- After the sequence:
  - With a live streak, the flame keeps flickering in short bursts (about
    2 s of flicker, then about 3 s of rest) for as long as the screen is
    open.
  - While today isn't practiced yet, the today pulse keeps coming back in
    the same rhythm (3 pulses, then rest).
- The loops pause while the screen isn't visible (app in the background,
  another screen on top) and continue in their normal rhythm when it's
  back. The opening sequence does not replay then.
- Tapping days or scrolling during the sequence doesn't stop or restart
  it.
- Screen readers get the hero's full streak length. The animations stay
  silent (unchanged from #128).
- With "reduce motion" on, everything shows its final state immediately
  and nothing loops (unchanged from #128).

## Acceptance criteria

- [ ] A streak containing a freeze day shows the same length on Home's
      badge, the hero, the "Longest streak" tile, the "streak saved"
      screen and the Android widget, equal to the days in the
      current-streak band.
- [ ] Existing streaks with a freeze day are corrected once on update.
- [ ] A milestone reached by a freeze day alone plays no milestone moment.
- [ ] No German string uses a feminine "Streak" (arb files and the Android
      widget's German resource strings); the listed strings read as above.
- [ ] Stat-tile captions and their screen-reader labels use the singular
      for 1 and the plural otherwise, in DE and EN.
- [ ] The legend no longer has a "Current streak" entry.
- [ ] The opening animations start after the page transition and play in
      order (count-up ~1.5 s → band ~2 s → today pulse 3×), skipping steps
      that don't apply.
- [ ] The flame (live streak) and the today pulse (today not practiced)
      repeat with pauses while the screen is open, pause while it's in the
      background or covered, and none of this runs with reduce motion on.
- [ ] Widget tests cover the freeze-day counting (incl. the one-time
      correction), the German singular captions, the animation order and
      reduce motion. Golden baselines are updated if visuals change.
- [ ] The #128 integration test still passes and checks the freeze-day
      streak length.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
      `tool/check_issues.sh`, `dart fix --dry-run`, and `flutter test` are
      clean per AGENTS.md.

## Out of scope

- A broken streak still shown as alive (#131).
- Celebrating milestones reached by a freeze.
- Other changes to how streaks or freezes are earned or spent.

## Dependencies

- Builds on #128 (Streak Details glow-up), #087 (streak freeze), #011
  (streak counting).

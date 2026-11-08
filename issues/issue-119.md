# Issue 119: Lesson screen — progress bar and menu in one slim top row

Status: open | Priority: P2 | Type: enhancement | Refined-at: 2026-11-08

## Goal

The lesson screen wastes vertical space at the top: an app bar with the
title "Lesson" (DE: "Lektion") sits above the progress bar, with the
three-dots menu at the right of the title. The title carries no information
the learner needs. Remove it and put the progress bar and the three-dots
menu in the same line, so the freed pixels go to the question content
(image, prompt, options).

## Desired behavior

- The "Lesson" / "Lektion" title is gone. Nothing replaces it.
- One compact top row: the progress bar fills the available width and is
  vertically centered; the three-dots menu sits at the right end of the same
  row. The row is no taller than the 48dp menu tap target (plus the system
  status-bar inset).
- Menu contents and behavior are unchanged (Quit; Skip before checking,
  hidden after checking and while busy).
- The row is identical for every question type and in every lesson state
  (answering, feedback) and on the result summary, so the content below
  never shifts between cards. The summary keeps the same slim row (full
  progress bar and menu) instead of today's titled app bar.
- The freed height goes to the question area. Layouts that adapt to
  available space (e.g. the image in #112) may use it; nothing may become
  smaller than today.
- Applies to the lesson screen (including its result summary) only; Home,
  Library and the full-screen completion sequence (loot box, wheel,
  streak, XP) are unchanged.

## Acceptance criteria

- [ ] No title text in the lesson top area, in DE and EN; the unused
      `lessonTitle` string is removed from both arb files (and l10n
      regenerated).
- [ ] Progress bar and three-dots menu are on one row on every question
      type, in answering and feedback states, and on the result summary.
- [ ] Menu tap target stays >= 48dp with a screen-reader label; the
      progress bar keeps its semantics label/value, animation and the
      `lessonProgressBar` / `lessonOverflowMenu` keys.
- [ ] The content area is taller than before; no clipping at large font
      sizes; dark mode unaffected.
- [ ] Quit and Skip still work; Skip still hidden after checking/while busy.
- [ ] Widget tests cover the single-row layout, absence of the title, menu
      actions, and the same row across question types and states; existing
      tests relying on the title or app bar are updated; goldens
      regenerated if affected.
- [ ] Follows #015 (kit, no ad-hoc styling; a11y floor: 48dp targets).
- [ ] No question-format change, so no `docs`/schema update needed.

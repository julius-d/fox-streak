# Issue 106: Free-text hint reveals the full answer

Status: done | Priority: P2 | Type: feature | Refined-at: 2026-11-04 | Completed-at: 2026-11-04

## Context

The free-text exercise's reveal-hint button (eye icon) currently shows only
the first letter of the expected answer (e.g. "Starts with: F"), per #007's
original design. Learners have asked for the hint to just show the whole
answer instead of a single letter.

## Goal

Tapping the reveal-hint button on a free-text question shows the learner the
complete expected answer as text, not just its first letter. The learner
still has to type the answer themselves — revealing the hint does not
auto-fill the text field.

## Decisions

- Scope: free-text exercise only; dial-pad (#008) and date (#009) hints keep
  their current "reveal part of the answer" behavior and are untouched.
- The hint stays a passive label (display only); it does not auto-fill the
  answer field.
- XP penalty is unchanged: using the hint still halves the item's XP reward
  (10 → 5), same as today (#010).
- One-shot behavior is unchanged: the button still disables after first use;
  no multi-tap/progressive reveal is introduced.
- New hint label wording: just "{answer}" (no "Answer:"/"Antwort:" prefix,
  same for EN/DE), replacing "Starts with: {letter}" / "Beginnt mit:
  {letter}".
- Button accessibility tooltip updated to match: "Reveal the answer (costs
  hint bonus)" (EN) / "Antwort anzeigen (kostet Hinweis-Bonus)" (DE),
  replacing the "first letter" wording.

## Acceptance criteria

1. Tapping the reveal-hint button (eye icon) on a free-text question shows
   the full expected answer as a label below the input: just "{answer}",
   instead of today's "Starts with: {letter}" / "Beginnt mit: {letter}".
2. The text field is not auto-filled by the hint; the learner still types
   the answer themselves.
3. Using the hint still sets the item's `hintUsed` outcome and halves its XP
   reward, matching today's behavior.
4. The button still disables itself after one use — no change to the
   one-shot affordance.
5. The button's accessibility tooltip is updated to "Reveal the answer
   (costs hint bonus)" (EN) / "Antwort anzeigen (kostet Hinweis-Bonus)" (DE).
6. Both English and German strings are updated via `lib/l10n` arb params; no
   hardcoded strings.
7. Golden-test baselines (#019) covering the free-text exercise's hint label
   are reviewed and regenerated if the new (longer) label text changes the
   widget's rendered layout.

## Out of scope

- Dial-pad (#008) and date (#009) exercise hints — they keep revealing only
  part of the answer.
- Any change to the XP penalty math (#010) or the one-shot button behavior.
- Auto-filling the answer field with the revealed answer.

## Summary

Hint label now shows the full answer (`exerciseFreeTextHintLabel` arb param
renamed `letter` -> `answer`); `_firstLetterHint()` renamed `_answerHint()`
and the `runes.first` logic dropped. Tooltip strings updated EN/DE.
No golden baselines existed for the free-text exercise widget (criterion 7
N/A — nothing to regenerate). Screenshot: `issues/done/issue-106-free-text-
hint-full-answer.png`.

## Code review

No findings. Removed-behavior audit confirmed dropping `runes.first` is
safe (new code passes the whole trimmed answer through, no indexing left).

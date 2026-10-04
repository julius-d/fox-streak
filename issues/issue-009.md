# Issue 009: Date exercise — calendar picker

Status: open | Priority: P0 | Type: feature

## Goal
"Day of birth" trainer: see person/event, pick date on a nice calendar.

## Acceptance criteria
- [ ] Prompt shows e.g. "Mamas Geburtstag"; calendar month view to pick day/month/year
- [ ] Fast year jump (dropdown/scroll) — birthdays span decades
- [ ] Grading: exact date; feedback shows correct date nicely formatted (de_DE + en)
- [ ] Keyboard-accessible fallback (manual date entry) for a11y

## Tasks
1. `DateExercise` wrapping themed `showDatePicker` / `TableCalendar`-like custom month grid (pick one, don't add heavy dep yet)
2. `formatDate` locale-aware (de: 14.05.2012, en: 05/14/2012)
3. Unit tests: leap years, ISO parse

## Open question
Day-only vs full-date mode (some birthdays remembered without year)? Propose: setting per item `granularity: full|dayMonth`.

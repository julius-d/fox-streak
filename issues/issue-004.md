# Issue 004: Question editors for 3 content types

Status: open | Priority: P0 | Type: feature

## Goal
Editors tailored to: vocab DE<->EN, phone numbers, birth dates.

## Acceptance criteria
- [ ] Vocab editor: fields `prompt`, `answer`, direction toggle DE->EN / EN->DE, optional 3 distractors for multiple-choice
- [ ] Phone editor: name label + digit-only field with pretty live formatting, 3-15 digits
- [ ] Date editor: label + date picker styled as nice calendar (not raw text field), ISO stored
- [ ] Inline errors, no save on invalid

## Tasks
1. Reusable `ItemEditor` switching by `type`
2. Phone input: numeric keyboard, auto-strip spaces/`+49` kept as typed but validated
3. Date input: `showDatePicker` wrapped in themed calendar sheet, year scrollable (birthdays 1920-today)
4. Distractor generator: auto-suggest from same set if user leaves blank

## Notes
Assumption: phone = memorize numbers (own/family/emergency); date = memorize birthdays. Correct in this file if wrong.

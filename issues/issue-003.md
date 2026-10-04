# Issue 003: Set library + CRUD UI (parents/teachers/learners create sets)

Status: open | Priority: P0 | Type: feature

## Goal
Anyone can create a set of question-answer pairs without an account.

## Duolingo reference
Duolingo has course creation tools; ours is simpler: user-generated decks like Quizlet, but with our 3 fixed types.

## Acceptance criteria
- [ ] Home library lists sets: title, item count, type icons, last score
- [ ] Create / rename / duplicate / delete set (delete with confirm)
- [ ] Add / edit / delete items inside a set
- [ ] Validation: empty prompt/answer blocked, phone = digits 3-15 chars, date = valid date
- [ ] Teen-friendly: large tap targets, German + English UI strings from start (i18n setup)

## Tasks
1. Screens: `LibraryScreen`, `SetDetailScreen`, `SetEditorScreen`
2. FAB "New set" -> title + type-mix allowed in one set
3. Empty states + sample CTA ("Try demo set")
4. Widget tests for create/delete flow

## Out of scope
Exercise gameplay itself (see #005-#009).

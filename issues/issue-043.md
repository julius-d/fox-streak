# Issue 043: Home screen's "Continue"/"Browse sets" buttons duplicate each other on a fresh install

Status: open | Priority: P3 | Type: UX

## Goal

Starting the first session needs to be easier. On Home
(`lib/src/home/home_screen.dart:220-236`), the primary button
(`homeContinueButton`) falls back to the exact same label *and* action as
the secondary button (`homeBrowseSetsButton`) — both read "Browse sets" and
both open the Library — whenever no attempts exist yet (fresh install).
Needs a proper design pass; not scoped out yet.

Related: #042 (sticky start button + direct-start from Library list) covers
the same "first lesson is hard to find" problem one layer deeper, in
Library/`SetDetailScreen`.

## Acceptance criteria

- [ ] TBD — needs a decision on what Home should show instead when no
      attempts exist (e.g. hide the secondary button, give the primary
      button a different fallback, or something else).

## Dependencies

- Related to #042.

# Issue 063: Seasonal mascots (snowman + spider) + 2 new ordinary mascots

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-10-18

## Goal

Add 4 new collectible mascots to #059's catalog: 🐖 pig and 🐥 baby chick as
ordinary (always winnable) mascots, plus ☃️ snowman and 🕷️ spider as
*seasonal* mascots only winnable from the daily lootbox during a fixed date
window each year (snowman: Dec 6-26 Christmas season; spider: Oct 25-Nov 1,
an 8-day Halloween window ending one day after Halloween). Outside its
window, a not-yet-owned seasonal mascot is simply excluded from the random
reward pool — same generic locked tile as any other unowned mascot in the
collection grid, no special treatment.

## Context

`assets/noto-emoji/mascot/emoji_u1f416_lottie.json` (pig),
`emoji_u1f425_lottie.json` (chick), `emoji_u2603_lottie.json` (snowman),
and `emoji_u1f577_lottie.json` (spider) are all already staged in the repo
(uncommitted). `MascotCatalog` auto-discovers every `*_lottie.json` file
under that directory (#059/#062), so all 4 already surface as catalog
entries — no asset work needed for any of them. Pig and chick need just
the catalog-count test update below; snowman and spider additionally need
the new seasonal-eligibility logic this issue introduces.

## Decisions

- **Where the restriction lives**: only the lootbox's random-reward pick
  (`MascotService.recordLessonCompletion`'s `unowned` list,
  `lib/src/stats/mascot_service.dart:63-70`) is restricted. Equipping an
  already-owned seasonal mascot is allowed year-round, same as any other
  owned mascot — there is no "can only wear the snowman in December" rule.
- **Date source**: use the already-injected `Clock` (`_clock.now()`),
  never `DateTime.now()` directly, matching #061's convention and keeping
  this testable with `FakeClock`.
- **Window definition**: a fixed, non-year-wrapping `(startMonth, startDay,
  endMonth, endDay)` range checked against the local date's month/day
  (year-independent, so it recurs every year automatically). Both windows
  in scope stay within a single month-or-two and never cross a Dec 31 ->
  Jan 1 boundary, so wraparound handling is explicitly out of scope (see
  below).
- **Lookup shape**: a small const `Map<String, MascotSeasonWindow>` (or
  equivalent) keyed by mascot ID, alongside `MascotCatalog` (e.g. in
  `mascot_catalog.dart` or a new sibling file). A mascot ID with no entry
  in the map is always winnable (today's behavior, unchanged for every
  existing mascot + pig/chick). This keeps the "is this ID seasonal"
  question colocated with the other ID-keyed mascot metadata
  (`kDefaultMascotId`, `decodeMascotEmoji`).
- **Collection grid**: no visual change. A seasonal mascot that's
  unowned and out-of-season renders the existing plain grey lock tile,
  identical to any other unowned mascot — no snowflake/pumpkin hint, no
  "comes back in December" copy. (Explicitly decided against the
  special-hint alternative to keep this issue scoped to the winnability
  mechanic.)

## Acceptance criteria

- [ ] `MascotCatalog.load()` discovers pig (`emoji_u1f416_lottie`), chick
  (`emoji_u1f425_lottie`), snowman (`emoji_u2603_lottie`), and spider
  (`emoji_u1f577_lottie`) as 4 additional catalog entries (11 total with
  the existing 7); the `mascot_catalog_test.dart` "discovers exactly the 7
  collectible mascots" test is updated to the new count.
- [ ] A seasonal-window lookup exists, keyed by mascot ID, checked via the
  injected `Clock` — not `DateTime.now()`.
- [ ] Snowman (`emoji_u2603_lottie`) is winnable from the lootbox only when
  the local date is Dec 6-26 (inclusive); outside that window it's
  excluded from `MascotService.recordLessonCompletion`'s random-pick pool
  even if otherwise unowned.
- [ ] Spider (`emoji_u1f577_lottie`) has the same seasonal-window wiring for
  Oct 25-Nov 1 (inclusive).
- [ ] Pig and chick have no seasonal restriction — winnable any day, same
  as the 7 pre-existing mascots.
- [ ] Boundary dates are covered by tests: Dec 5 and Dec 27 exclude the
  snowman; Dec 6 and Dec 26 include it; Oct 24 and Nov 2 exclude the
  spider; Oct 25 and Nov 1 include it.
- [ ] The collection grid's locked-tile rendering is unchanged (verified
  by not touching `mascot_collection_screen.dart`, or by a test asserting
  the generic lock tile still renders for an out-of-season mascot).
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.

## Tasks

1. `git add` is already done for the pig/chick/snowman/spider asset files
   (currently staged) — no asset work needed for any of them.
2. Add a seasonal-window lookup (e.g. `MascotSeasonWindow` + a const
   `Map<String, MascotSeasonWindow>`) covering `emoji_u2603_lottie`
   (Dec 6-26) and `emoji_u1f577_lottie` (Oct 25-Nov 1).
3. In `MascotService.recordLessonCompletion`, filter `unowned` to exclude
   any seasonal mascot whose window isn't active for `_clock.now()`
   before the random pick.
4. Update `test/mascot/mascot_catalog_test.dart`'s exact-count assertion
   (7 -> 11).
5. Add `MascotService` tests (with `FakeClock` + a fixture catalog
   including the seasonal IDs) covering: in-window winnable, out-of-window
   excluded, and the boundary dates listed in the acceptance criteria.
6. Confirm `attribution.md`'s existing blanket Noto Emoji / CC BY 4.0
   notice already covers the new files (no per-file edit expected).

## Out of scope

- Any other new mascots beyond pig, chick, snowman, spider.
- Visual/copy hints in the collection grid for out-of-season seasonal
  mascots (see Decisions).
- Restricting *equipping* an already-owned seasonal mascot to its season.
- Year-wrapping windows (e.g. a window spanning Dec 30 -> Jan 2) — both
  windows in scope fit within a single calendar month-pair with no
  wraparound; generalizing the lookup for a wrapping window is deferred
  until a mascot actually needs one.

## Dependencies

- Builds on #059 (`MascotCatalog`, `MascotService`, collection screen) and
  #062's `assets/noto-emoji/mascot/` auto-discovery path.
- Follows #061's precedent for fixed-date, `Clock`-driven calendar logic.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

# Issue 125: Startup check for pack updates with an "Update available" banner on Home

Status: done | Priority: P2 | Type: enhancement | Refined-at: 2026-11-08
Completed-at: 2026-11-08

## Goal

Pack updates (#121) are only discovered when the learner opens a pack in the
Marketplace. Learners who downloaded a pack never learn that new or changed
sets are waiting. On app start, FoxStreak should check the downloaded packs
for upstream changes and, if there are any, tell the learner on Home with a
blue banner and offer to update right there.

## Desired behavior

### Check

- On every cold app start, the app checks all downloaded packs against their
  Marketplace source for changes: new sets and changed sets. Resuming the app
  from the background does not trigger a new check.
- The check uses the same update detection as the pack states in #121; no new
  rules for what counts as an update.
- The check runs in the background. Home renders immediately and never waits
  for the network.
- Offline, unreachable source, or any failed check: nothing is shown, no
  error, no retry prompt. The next app start tries again.
- Own packs are never checked. With no downloaded packs, nothing happens.

### Banner

- If at least one downloaded pack has an update, Home shows a blue info
  banner (kit banner, info style, #015) when the check finishes.
- Text names what is waiting, encouraging and neutral, e.g. for one pack
  "New content in <pack title>" and for several packs "Updates available for
  N packs". Long titles wrap.
- Two controls: **Update** (action button) and a close (X) control to
  dismiss. On narrow widths or large fonts the action stacks below the text;
  nothing is clipped.
- Dismissing hides the banner for this app session. It reappears on the next
  app start if updates are still pending.
- Only one pack banner is shown, even when several packs have updates.
- Home shows at most one banner at a time. If the streak-freeze banner (#087)
  is showing, it goes first; the pack banner appears once it is gone.

### Updating from the banner

- **Update** updates all affected packs in place, with visible progress on
  the banner. The learner stays on Home. The dismiss control is hidden while
  an update runs.
- If the learner leaves Home during the update, it keeps running. Back on
  Home, the banner shows the current progress or the final result (a finished
  result is shown once).
- Same rules as the update in #121: all-or-nothing per pack, sets added
  upstream arrive, sets removed upstream stay locally, a failed update leaves
  existing sets intact.
- If the learner edited local sets that the update would overwrite, the same
  single summary dialog as in #121 lists them; the learner confirms the
  overwrite or skips them. With several packs, one combined dialog.
- A pack that is already being updated elsewhere (e.g. from the Marketplace
  pack screen) is not updated twice. A pack deleted before or during the
  update is skipped silently.
- On success the banner becomes a short success confirmation (e.g. "Packs
  updated") and then disappears. The Library shows the new content.
- On failure (e.g. connection lost mid-update) the banner shows an
  encouraging, non-shaming message with a **Retry** action; dismiss works
  again. With several packs, packs that already updated stay updated and
  Retry only covers the failed ones; the message says so.

### Out of scope

- Push notifications and checks while the app is closed.
- Per-pack opt-out of update notices.
- Re-checking on resume from background.

## Acceptance criteria

- [x] On cold app start, downloaded packs are checked in the background for
      new and changed sets using the #121 update detection; Home is never
      blocked by the check; resume does not re-check.
- [x] Offline or failed check shows nothing and does not surface an error.
- [x] A blue info banner appears on Home only when at least one downloaded
      pack has an update; one banner for any number of packs; wording
      differs for one vs. several packs.
- [x] The streak-freeze banner takes precedence; never two banners at once.
- [x] Dismiss (X) hides the banner for the current session; it returns on
      next app start while updates are pending; it is hidden during a
      running update.
- [x] "Update" updates all affected packs from the banner with progress,
      reusing the #121 update rules (all-or-nothing per pack, removed sets
      kept, edited-set overwrite summary with confirm/skip, combined for
      several packs).
- [x] The update continues when the learner leaves Home; returning shows
      progress or the final result once.
- [x] No double update of a pack that is already updating; deleted packs are
      skipped silently.
- [x] Success shows a brief confirmation and the banner disappears; failure
      shows a retry option that only covers failed packs.
- [x] No banner and no check for users without downloaded packs.
- [x] Kit extension: `FoxFeedbackBanner` supports an optional action button
      and a close icon, 48dp targets, screen-reader labels, wrapping/stacking
      under large fonts; golden tests (light + dark) updated per #019 for the
      affected baselines.
- [x] DE + EN strings via arb; dark mode and large font covered; follows
      #015.
- [x] Tests: check result states (none / updates / offline / failure),
      banner visibility, precedence vs. streak-freeze banner and dismiss,
      update flow incl. overwrite dialog, partial failure retry, leaving
      Home mid-update.
- [x] No change to the question-set file format or marketplace API, so no
      `docs`/schema update needed.

## Summary

- `PackUpdateService` (check via #121 `outdatedSetIds`, apply via `updatePack`) + session-wide `PackUpdateController` (non-auto-dispose: one check per cold start, update survives leaving Home) + `PackUpdateBanner` on Home; streak-freeze banner wins.
- `FoxFeedbackBanner` gained optional action + close (stacks under 360dp / text scale > 1.3). New goldens `fox_feedback_banner_action_*` (macOS committed; Linux still to be generated by CI).
- `PackUpdateLocks` stops double updates between Home banner and the Marketplace pack screen; the pack screen also tells the controller when it changed a pack.
- Known limit: while the streak-freeze banner is on screen (rest of the session), the pack banner stays hidden.
- Screenshots: `issue-125-home-banner*.png`.

## Code review

- Overwrite dialog callback could run on an unmounted banner after leaving Home.
  Fixed: `mounted` guard.
- Updating a pack in the Marketplace left a stale banner/update list on Home.
  Fixed: `packChanged` removes it; test added.
- A pack whose lock was taken meanwhile ended as "success".
  Fixed: it counts as failed so Retry covers it.
- Declining all overwrites cleared the banner although updates stayed pending.
  Fixed: banner stays; test added.
- Late startup check could overwrite a running/failed state.
  Fixed: only applied while idle.
- Success timer started in `build`; stale "Packs updated" when finished away from Home.
  Not fixed: showing a finished result once on return is the specified behavior; the timer is idempotent.
- Marketplace screen silently ignores a tap when the banner holds the lock.
  Not fixed: rare, and the update completes anyway.
- Duplicate action/close params and asserts across banner constructors; progress text announced twice.
  Not fixed: minor, kept consistent with existing constructor style.
